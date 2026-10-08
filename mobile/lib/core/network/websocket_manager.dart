import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WsConnectionState {
  disconnected,
  connecting,
  connected,
}

final webSocketManagerProvider = Provider<WebSocketManager>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  final manager = WebSocketManager(
    dio: dio,
    db: db,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final wsConnectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws.connectionStateStream;
});

final typingIndicatorProvider = StreamProvider.family<bool, String>((ref, matchId) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws.watchTyping(matchId);
});

final userPresenceProvider = StreamProvider.family<bool, String>((ref, userId) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws.watchPresence(userId);
});

class WebSocketManager {
  WebSocketManager({
    required Dio dio,
    required AppDatabase db,
    Connectivity? connectivity,
    String? wsUrlOverride,
    WebSocket Function(dynamic uri)? socketFactory,
  })  : _dio = dio,
        _db = db,
        _connectivity = connectivity ?? Connectivity(),
        _wsUrlOverride = wsUrlOverride,
        _socketFactory = socketFactory {
    _initConnectivityListener();
  }

  final Dio _dio;
  final AppDatabase _db;
  final Connectivity _connectivity;
  final String? _wsUrlOverride;
  final WebSocket Function(dynamic uri)? _socketFactory;

  WebSocket? _socket; // dart:io WebSocket or mock
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  DateTime? _lastReceivedMessageAt;

  final _stateController = StreamController<WsConnectionState>.broadcast();
  WsConnectionState _currentState = WsConnectionState.disconnected;

  final _typingController = StreamController<Map<String, bool>>.broadcast();
  final Map<String, bool> _typingState = {};

  final _presenceController = StreamController<Map<String, bool>>.broadcast();
  final Map<String, bool> _presenceState = {};

  final _incomingMessageController = StreamController<CachedMessage>.broadcast();

  Stream<WsConnectionState> get connectionStateStream => _stateController.stream;
  WsConnectionState get currentState => _currentState;
  Stream<CachedMessage> get incomingMessages => _incomingMessageController.stream;

  Stream<bool> watchTyping(String matchId) {
    return _typingController.stream.map((map) => map[matchId] ?? false);
  }

  Stream<bool> watchPresence(String userId) {
    return _presenceController.stream.map((map) => map[userId] ?? false);
  }

  bool isUserOnline(String userId) => _presenceState[userId] ?? false;

  void _initConnectivityListener() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (_isDisposed) return;
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline && _currentState == WsConnectionState.disconnected) {
        // Network recovered, attempt reconnect immediately
        _reconnectAttempts = 0;
        connect();
      }
    });
  }

  void _updateState(WsConnectionState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Initiates connection by fetching a short-lived ticket and opening WebSocket.
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_currentState == WsConnectionState.connecting || _currentState == WsConnectionState.connected) {
      return;
    }

    _updateState(WsConnectionState.connecting);

    try {
      // 1. Obtain ticket
      String? ticket;
      try {
        final ticketRes = await _dio.post<Map<String, dynamic>>('/v1/ws-ticket');
        if (ticketRes.statusCode == 200 && ticketRes.data != null) {
          ticket = ticketRes.data!['ticket'] as String?;
        }
      } catch (e) {
        debugPrint('[WS] Failed to fetch WS ticket: $e');
      }

      // 2. Build WebSocket URI
      final baseUrl = _wsUrlOverride ??
          (AppConfig.instance.wsBaseUrl.isNotEmpty
              ? AppConfig.instance.wsBaseUrl
              : 'ws://10.0.2.2:8080/ws');

      final baseUri = Uri.parse(baseUrl);
      final queryParams = Map<String, String>.from(baseUri.queryParameters);
      if (ticket != null) {
        queryParams['ticket'] = ticket;
      }
      final fullUri = baseUri.replace(queryParameters: queryParams);

      // 3. Connect socket
      if (_socketFactory != null) {
        _socket = _socketFactory(fullUri);
      } else {
        _socket = await WebSocket.connect(fullUri.toString()).timeout(
          const Duration(seconds: 10),
        );
      }

      _reconnectAttempts = 0;
      _updateState(WsConnectionState.connected);
      _lastReceivedMessageAt = DateTime.now();

      _listenToSocket();
      _startHeartbeat();
      debugPrint('[WS] Connected successfully to $fullUri');
    } catch (e) {
      debugPrint('[WS] Connection failed: $e');
      _cleanupSocket();
      _updateState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _listenToSocket() {
    final socket = _socket;
    if (socket == null) return;

    _socketSub = socket.listen(
      (data) {
        _lastReceivedMessageAt = DateTime.now();
        _handleRawFrame(data);
      },
      onError: (dynamic error) {
        debugPrint('[WS] Socket error: $error');
        _handleDisconnect();
      },
      onDone: () {
        debugPrint('[WS] Socket closed by server');
        _handleDisconnect();
      },
      cancelOnError: true,
    );
  }

  void _handleRawFrame(dynamic raw) {
    try {
      final jsonStr = raw is String ? raw : utf8.decode(raw as List<int>);
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        _handleIncomingFrame(decoded);
      }
    } catch (e) {
      debugPrint('[WS] Failed to parse incoming frame: $e');
    }
  }

  Future<void> _handleIncomingFrame(Map<String, dynamic> frame) async {
    final type = frame['type'] as String?;
    switch (type) {
      case 'pong':
        // Heartbeat response acknowledged
        return;

      case 'message.new':
        final matchId = frame['match_id'] as String? ?? '';
        final senderId = frame['sender_id'] as String? ?? '';
        final body = (frame['body'] as String?) ?? (frame['content'] as String?) ?? '';
        final msgType = frame['msg_type'] as String? ?? frame['type_field'] as String? ?? 'text';
        final mediaUrl = frame['media_url'] as String?;
        final mediaDuration = (frame['media_duration'] as num?)?.toInt();
        final clientMsgId = frame['client_msg_id'] as String?;
        final messageIdStr = frame['message_id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
        final id = clientMsgId ?? messageIdStr;
        final createdAt = frame['created_at'] != null
            ? DateTime.tryParse(frame['created_at'] as String) ?? DateTime.now()
            : DateTime.now();

        final cachedMsg = CachedMessage(
          id: id,
          matchId: matchId,
          senderId: senderId,
          type: msgType,
          content: body,
          mediaUrl: mediaUrl,
          mediaDuration: mediaDuration,
          status: 'delivered',
          createdAt: createdAt,
          cachedAt: DateTime.now(),
        );

        await _db.upsertMessage(cachedMsg);
        await _db.updateMatchLastMessage(
          matchId,
          body.isNotEmpty ? body : (msgType == 'image' ? '📷 Photo' : '🎤 Voice note'),
          createdAt,
          incrementUnread: true,
        );

        if (!_incomingMessageController.isClosed) {
          _incomingMessageController.add(cachedMsg);
        }

      case 'message.ack':
        final clientMsgId = frame['client_msg_id'] as String?;
        final status = (frame['status'] as String?) ?? 'sent';
        if (clientMsgId != null) {
          await _db.updateMessageStatus(clientMsgId, status);
        }

      case 'read':
        final matchId = frame['match_id'] as String?;
        if (matchId != null) {
          await _db.markMatchRead(matchId);
        }

      case 'typing':
        final matchId = frame['match_id'] as String?;
        final isTyping = frame['is_typing'] as bool? ?? false;
        if (matchId != null) {
          _typingState[matchId] = isTyping;
          if (!_typingController.isClosed) {
            _typingController.add(Map.unmodifiable(_typingState));
          }
        }

      case 'presence':
        final userId = frame['user_id'] as String?;
        final status = frame['status'] as String?;
        if (userId != null) {
          final isOnline = status == 'online';
          _presenceState[userId] = isOnline;
          if (!_presenceController.isClosed) {
            _presenceController.add(Map.unmodifiable(_presenceState));
          }
        }

      case 'match.new':
        // Match event handled via match refresh
        return;

      default:
        return;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentState == WsConnectionState.connected) {
        // Send ping
        sendFrame({'type': 'ping'});

        // Check if connection has gone stale (> 60s since last frame)
        if (_lastReceivedMessageAt != null &&
            DateTime.now().difference(_lastReceivedMessageAt!) > const Duration(seconds: 60)) {
          debugPrint('[WS] Heartbeat timeout, reconnecting...');
          _handleDisconnect();
        }
      }
    });
  }

  void _handleDisconnect() {
    _cleanupSocket();
    _updateState(WsConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _cleanupSocket() {
    _heartbeatTimer?.cancel();
    _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    // Exponential backoff with jitter (1s, 2s, 4s, 8s, up to 30s + 0-500ms jitter)
    final backoffSec = min(pow(2, _reconnectAttempts).toInt(), 30);
    final jitterMs = Random().nextInt(500);
    final delay = Duration(seconds: backoffSec, milliseconds: jitterMs);

    _reconnectAttempts++;
    debugPrint('[WS] Scheduling reconnect attempt #$_reconnectAttempts in ${delay.inMilliseconds}ms');

    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed && _currentState == WsConnectionState.disconnected) {
        connect();
      }
    });
  }

  /// Sends a raw JSON frame over the socket.
  bool sendFrame(Map<String, dynamic> frame) {
    final socket = _socket;
    if (_currentState != WsConnectionState.connected || socket == null) {
      return false;
    }
    try {
      final jsonStr = jsonEncode(frame);
      socket.add(jsonStr);
      return true;
    } catch (e) {
      debugPrint('[WS] Error sending frame: $e');
      return false;
    }
  }

  /// Sends a chat message. Returns true if sent over WS, false if queued/failed.
  bool sendMessageFrame({
    required String matchId,
    required String clientMsgId,
    required String content,
    String type = 'text',
    String? mediaUrl,
    int? mediaDuration,
  }) {
    return sendFrame({
      'type': 'message.send',
      'match_id': matchId,
      'client_msg_id': clientMsgId,
      'body': content,
      'msg_type': type,
      'media_url': mediaUrl,
      'media_duration': mediaDuration,
    });
  }

  /// Broadcasts typing indicator for a match.
  void sendTyping(String matchId, {required bool isTyping}) {
    sendFrame({
      'type': 'typing',
      'match_id': matchId,
      'is_typing': isTyping,
    });
  }

  /// Sends read receipt up to a given message ID.
  void sendReadReceipt(String matchId, int upToId) {
    sendFrame({
      'type': 'read',
      'match_id': matchId,
      'up_to_id': upToId,
    });
  }

  /// Replays missed messages from server after reconnect using `GET /v1/matches/{id}/messages?after_id=`.
  Future<void> replayMissedMessages(String matchId, {int? afterId}) async {
    try {
      final queryParams = <String, dynamic>{'limit': 50};
      if (afterId != null && afterId > 0) {
        queryParams['after_id'] = afterId;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/matches/$matchId/messages',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final list = (response.data!['messages'] as List<dynamic>?) ?? [];
        for (final item in list) {
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
              status: (item['status'] as String?) ?? 'delivered',
              createdAt: item['created_at'] != null
                  ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
                  : DateTime.now(),
              cachedAt: DateTime.now(),
            );
            await _db.upsertMessage(msg);
          }
        }
      }
    } catch (e) {
      debugPrint('[WS] Replay error: $e');
    }
  }

  void disconnect() {
    _cleanupSocket();
    _reconnectTimer?.cancel();
    _updateState(WsConnectionState.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _connectivitySub?.cancel();
    _stateController.close();
    _typingController.close();
    _presenceController.close();
    _incomingMessageController.close();
  }
}
