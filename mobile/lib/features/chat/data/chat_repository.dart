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
            final serverId = item['id']?.toString();
            final clientMsgId = item['client_msg_id'] as String?;
            final id = serverId ?? clientMsgId;
            if (id == null) continue;

            // Reconcile/delete optimistic client message if server ID is present
            if (clientMsgId != null && serverId != null && clientMsgId != serverId) {
              await _db.deleteMessage(clientMsgId);
            }

            final mediaUrl = item['media_url'] as String?;
            final normalizedMediaUrl = mediaUrl != null
                ? (mediaUrl.startsWith('http://localhost')
                    ? mediaUrl.replaceFirst('http://localhost', 'http://127.0.0.1')
                    : mediaUrl)
                : null;

            final msg = CachedMessage(
              id: id,
              matchId: matchId,
              senderId: (item['sender_id'] as String?) ?? '',
              type: (item['type'] as String?) ?? 'text',
              content: (item['content'] as String?) ?? (item['body'] as String?) ?? '',
              mediaUrl: normalizedMediaUrl,
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
        final serverId = response.data?['id']?.toString();
        if (serverId != null && serverId != clientMsgId) {
          await _db.reconcileMessageId(
            clientMsgId: clientMsgId,
            serverId: serverId,
            status: 'sent',
          );
        } else {
          await _db.updateMessageStatus(clientMsgId, 'sent');
        }
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

  /// Uploads media file to MinIO via backend presigned URL and returns the public CDN URL.
  Future<String?> uploadChatMedia({
    required String matchId,
    required File file,
    required String mediaType, // 'image' or 'voice'
    required String contentType,
  }) async {
    try {
      final sizeBytes = await file.length();
      final urlRes = await _dio.post<Map<String, dynamic>>(
        '/v1/matches/$matchId/media/upload-url',
        data: {
          'media_type': mediaType,
          'content_type': contentType,
          'size_bytes': sizeBytes,
        },
      );

      final data = urlRes.data;
      if (data == null) return null;

      var uploadUrl = data['upload_url'] as String?;
      var mediaUrl = data['media_url'] as String?;
      if (uploadUrl == null || mediaUrl == null) return null;

      final uri = Uri.parse(uploadUrl);
      if (uri.host == 'localhost') {
        uploadUrl = uri.replace(host: '127.0.0.1').toString();
      }
      if (mediaUrl.startsWith('http://localhost')) {
        mediaUrl = mediaUrl.replaceFirst('http://localhost', 'http://127.0.0.1');
      }

      final fileBytes = await file.readAsBytes();
      final uploadDio = Dio();
      await uploadDio.put<dynamic>(
        uploadUrl,
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': sizeBytes,
          },
        ),
      );

      return mediaUrl;
    } catch (e) {
      debugPrint('[Chat] Media upload failed: $e');
      return null;
    }
  }

  /// Compresses on-device image, uploads to MinIO, and dispatches image message.
  Future<void> sendImageMessage({
    required String matchId,
    required String senderId,
    required String filePath,
  }) async {
    var uploadFile = File(filePath);
    var contentType = 'image/jpeg';
    try {
      final compressed = await ImageCompressor.compressForUpload(uploadFile);
      uploadFile = compressed.file;
      contentType = compressed.mimeType;
    } catch (_) {
      if (filePath.endsWith('.png')) {
        contentType = 'image/png';
      } else if (filePath.endsWith('.webp')) {
        contentType = 'image/webp';
      }
    }

    final uploadedUrl = await uploadChatMedia(
      matchId: matchId,
      file: uploadFile,
      mediaType: 'image',
      contentType: contentType,
    );

    await sendMessage(
      matchId: matchId,
      senderId: senderId,
      content: '📷 Photo',
      type: 'image',
      mediaUrl: uploadedUrl ?? uploadFile.path,
    );
  }

  /// Uploads voice note to MinIO and dispatches voice message.
  Future<void> sendVoiceMessage({
    required String matchId,
    required String senderId,
    required String filePath,
    required int durationSec,
  }) async {
    var voiceFile = File(filePath);
    var contentType = 'audio/wav';

    if (!voiceFile.existsSync()) {
      voiceFile = await _createStubAudioFile('voice_${DateTime.now().millisecondsSinceEpoch}', durationSec);
    } else {
      if (filePath.endsWith('.m4a') || filePath.endsWith('.mp4') || filePath.endsWith('.aac')) {
        contentType = 'audio/m4a';
      } else if (filePath.endsWith('.mp3')) {
        contentType = 'audio/mp3';
      } else if (filePath.endsWith('.ogg') || filePath.endsWith('.opus')) {
        contentType = 'audio/ogg';
      }
    }

    final uploadedUrl = await uploadChatMedia(
      matchId: matchId,
      file: voiceFile,
      mediaType: 'voice',
      contentType: contentType,
    );

    await sendMessage(
      matchId: matchId,
      senderId: senderId,
      content: '🎤 Voice note',
      type: 'voice',
      mediaUrl: uploadedUrl ?? voiceFile.path,
      mediaDuration: durationSec,
    );
  }

  static Future<File> _createStubAudioFile(String name, int durationSec) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$name.wav');

    const sampleRate = 8000;
    const numChannels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const blockAlign = numChannels * (bitsPerSample ~/ 8);
    final numSamples = sampleRate * durationSec;
    final dataSize = numSamples * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;

    final bytes = ByteData(44);
    bytes.setUint8(0, 0x52); bytes.setUint8(1, 0x49); bytes.setUint8(2, 0x46); bytes.setUint8(3, 0x46); // RIFF
    bytes.setUint32(4, fileSize, Endian.little);
    bytes.setUint8(8, 0x57); bytes.setUint8(9, 0x41); bytes.setUint8(10, 0x56); bytes.setUint8(11, 0x45); // WAVE
    bytes.setUint8(12, 0x66); bytes.setUint8(13, 0x6D); bytes.setUint8(14, 0x74); bytes.setUint8(15, 0x20); // fmt
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, numChannels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, blockAlign, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    bytes.setUint8(36, 0x64); bytes.setUint8(37, 0x61); bytes.setUint8(38, 0x74); bytes.setUint8(39, 0x61); // data
    bytes.setUint32(40, dataSize, Endian.little);

    final pcmData = Uint8List(44 + dataSize);
    pcmData.setRange(0, 44, bytes.buffer.asUint8List());
    await file.writeAsBytes(pcmData);
    return file;
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
