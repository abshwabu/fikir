import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/network/websocket_manager.dart';
import 'package:fikir/core/utils/image_compressor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  final ws = ref.watch(webSocketManagerProvider);
  return ChatRepository(dio, db, ws);
});

class ChatRepository {
  ChatRepository(this._dio, this._db, this._ws);

  final Dio _dio;
  final AppDatabase _db;
  final WebSocketManager _ws;

  /// Stale-while-revalidate: stream cached messages for a match and refresh from server.
  Stream<List<CachedMessage>> watchMessages(String matchId) {
    unawaited(_refreshMessages(matchId));
    return _db.watchMessagesForMatch(matchId);
  }

  Future<void> _refreshMessages(String matchId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/matches/$matchId/messages');
      if (response.statusCode == 200 && response.data != null) {
        final messagesList = (response.data!['messages'] as List<dynamic>?) ?? [];
        for (final item in messagesList) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? item['client_msg_id'] as String?;
            if (id == null) continue;

            final msg = CachedMessage(
              id: id,
              matchId: matchId,
              senderId: (item['sender_id'] as String?) ?? '',
              type: (item['type'] as String?) ?? 'text',
              content: (item['content'] as String?) ?? (item['body'] as String?) ?? '',
              mediaUrl: item['media_url'] as String?,
              mediaDuration: (item['media_duration'] as num?)?.toInt(),
              status: (item['status'] as String?) ?? 'sent',
              createdAt: item['created_at'] != null
                  ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
                  : DateTime.now(),
              cachedAt: DateTime.now(),
            );
            await _db.upsertMessage(msg);
          }
        }
      }
    } catch (_) {
      // Offline / network failure - cached messages remain visible
    }
  }

  /// Optimistically writes message to SQLite and dispatches via WebSocket or REST fallback.
  Future<String> sendMessage({
    required String matchId,
    required String senderId,
    required String content,
    String type = 'text',
    String? mediaUrl,
    int? mediaDuration,
  }) async {
    final clientMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';

    // 1. Optimistic write to SQLite
    final optimisticMessage = CachedMessage(
      id: clientMsgId,
      matchId: matchId,
      senderId: senderId,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
      status: 'pending',
      createdAt: DateTime.now(),
      cachedAt: DateTime.now(),
    );
    await _db.upsertMessage(optimisticMessage);
    await _db.updateMatchLastMessage(
      matchId,
      content.isNotEmpty ? content : (type == 'image' ? '📷 Photo' : '🎤 Voice note'),
      DateTime.now(),
    );

    // 2. Try WebSocket delivery
    final wsSent = _ws.sendMessageFrame(
      matchId: matchId,
      clientMsgId: clientMsgId,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
    );

    if (wsSent) {
      await _db.updateMessageStatus(clientMsgId, 'sent');
      return clientMsgId;
    }

    // 3. Fallback to REST delivery
    await _deliverViaRest(
      clientMsgId: clientMsgId,
      matchId: matchId,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
    );

    return clientMsgId;
  }

  Future<void> _deliverViaRest({
    required String clientMsgId,
    required String matchId,
    required String content,
    required String type,
    String? mediaUrl,
    int? mediaDuration,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/matches/$matchId/messages',
        data: {
          'client_msg_id': clientMsgId,
          'type': type,
          'content': content,
          'body': content,
          if (mediaUrl != null) 'media_url': mediaUrl,
          if (mediaDuration != null) 'media_duration': mediaDuration,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _db.updateMessageStatus(clientMsgId, 'sent');
      } else {
        await _db.updateMessageStatus(clientMsgId, 'failed');
      }
    } catch (_) {
      await _db.updateMessageStatus(clientMsgId, 'failed');
    }
  }

  /// Retries a previously failed message.
  Future<void> retryMessage(CachedMessage message) async {
    await _db.updateMessageStatus(message.id, 'pending');

    final wsSent = _ws.sendMessageFrame(
      matchId: message.matchId,
      clientMsgId: message.id,
      content: message.content,
      type: message.type,
      mediaUrl: message.mediaUrl,
      mediaDuration: message.mediaDuration,
    );

    if (wsSent) {
      await _db.updateMessageStatus(message.id, 'sent');
      return;
    }

    await _deliverViaRest(
      clientMsgId: message.id,
      matchId: message.matchId,
      content: message.content,
      type: message.type,
      mediaUrl: message.mediaUrl,
      mediaDuration: message.mediaDuration,
    );
  }

  /// Compresses on-device image and dispatches image message.
  Future<void> sendImageMessage({
    required String matchId,
    required String senderId,
    required String filePath,
  }) async {
    String? compressedPath;
    try {
      final compressed = await ImageCompressor.compressForUpload(File(filePath));
      compressedPath = compressed.file.path;
    } catch (e) {
      compressedPath = filePath;
    }

    await sendMessage(
      matchId: matchId,
      senderId: senderId,
      content: '📷 Photo',
      type: 'image',
      mediaUrl: compressedPath,
    );
  }

  /// Dispatches voice note message.
  Future<void> sendVoiceMessage({
    required String matchId,
    required String senderId,
    required String filePath,
    required int durationSec,
  }) async {
    await sendMessage(
      matchId: matchId,
      senderId: senderId,
      content: '🎤 Voice note',
      type: 'voice',
      mediaUrl: filePath,
      mediaDuration: durationSec,
    );
  }

  /// Marks a conversation as read up to a message ID and resets badge.
  Future<void> markAsRead(String matchId, {int? upToId}) async {
    await _db.markMatchRead(matchId);
    if (upToId != null) {
      _ws.sendReadReceipt(matchId, upToId);
      try {
        await _dio.post<dynamic>(
          '/v1/matches/$matchId/read',
          data: {'up_to_id': upToId},
        );
      } catch (e) {
        debugPrint('[Chat] Failed to sync read receipt: $e');
      }
    }
  }

  /// Sends typing state.
  void sendTyping(String matchId, {required bool isTyping}) {
    _ws.sendTyping(matchId, isTyping: isTyping);
  }

  /// Replays missed messages.
  Future<void> replayMissed(String matchId, {int? afterId}) async {
    await _ws.replayMissedMessages(matchId, afterId: afterId);
  }
}
