import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/network/websocket_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late AppDatabase db;
  late Dio dio;
  late WebSocketManager wsManager;

  setUp(() async {
    AppConfig.initialize(
      const AppConfig(
        flavor: AppFlavor.dev,
        appName: 'Fikir Test',
        apiBaseUrl: 'http://localhost:8080',
        wsBaseUrl: 'ws://localhost:8080/ws',
        cdnBaseUrl: 'http://localhost:9000/public',
        enableLogging: false,
      ),
    );

    db = AppDatabase(NativeDatabase.memory());
    dio = Dio();
    server = await HttpServer.bind('localhost', 0);
  });

  tearDown(() async {
    wsManager.dispose();
    await server.close(force: true);
    await db.close();
  });

  group('WebSocketManager Integration Tests with Fake WebSocket Server', () {
    test('Connects, sends message frame, receives incoming frame, and persists to Drift', () async {
      final receivedServerFrames = <Map<String, dynamic>>[];
      final serverSocketCompleter = Completer<WebSocket>();

      // Fake server listener
      server.listen((HttpRequest request) async {
        if (request.uri.path == '/v1/ws-ticket') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'ticket': 'test-ticket-xyz', 'expires_in_seconds': 60}));
          await request.response.close();
          return;
        }

        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          serverSocketCompleter.complete(socket);

          socket.listen((message) {
            if (message is String) {
              final decoded = jsonDecode(message) as Map<String, dynamic>;
              receivedServerFrames.add(decoded);

              if (decoded['type'] == 'message.send') {
                // Server sends ack back to client
                socket.add(
                  jsonEncode({
                    'type': 'message.ack',
                    'client_msg_id': decoded['client_msg_id'],
                    'status': 'sent',
                  }),
                );
              }
            }
          });
        }
      });

      final wsUrl = 'ws://localhost:${server.port}/ws';

      wsManager = WebSocketManager(
        dio: dio,
        db: db,
        wsUrlOverride: wsUrl,
      );

      // Connect
      await wsManager.connect();
      expect(wsManager.currentState, equals(WsConnectionState.connected));

      final serverSocket = await serverSocketCompleter.future;

      // 1. Send frame from client
      final sent = wsManager.sendMessageFrame(
        matchId: 'match-integration-1',
        clientMsgId: 'client-msg-123',
        content: 'Buna tetu!',
      );
      expect(sent, isTrue);

      // Wait for server to receive frame
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(receivedServerFrames.length, equals(1));
      expect(receivedServerFrames.first['type'], equals('message.send'));
      expect(receivedServerFrames.first['body'], equals('Buna tetu!'));

      // 2. Server pushes incoming message to client
      serverSocket.add(
        jsonEncode({
          'type': 'message.new',
          'match_id': 'match-integration-1',
          'sender_id': 'recipient-betty',
          'content': 'Ishi enhedalen!',
          'msg_type': 'text',
          'created_at': DateTime.now().toIso8601String(),
        }),
      );

      // Wait for client to process and persist into SQLite Drift
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final messages = await db.getMessagesForMatch('match-integration-1');
      expect(messages.length, equals(1));
      expect(messages.first.content, equals('Ishi enhedalen!'));
      expect(messages.first.senderId, equals('recipient-betty'));
      expect(messages.first.status, equals('delivered'));
    });

    test('Handles server disconnect cleanly and transitions to disconnected state', () async {
      final serverSocketCompleter = Completer<WebSocket>();

      server.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          serverSocketCompleter.complete(socket);
        }
      });

      final wsUrl = 'ws://localhost:${server.port}/ws';

      wsManager = WebSocketManager(
        dio: dio,
        db: db,
        wsUrlOverride: wsUrl,
      );

      await wsManager.connect();
      expect(wsManager.currentState, equals(WsConnectionState.connected));

      final serverSocket = await serverSocketCompleter.future;

      // Server closes socket
      await serverSocket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(wsManager.currentState, equals(WsConnectionState.disconnected));
    });
  });
}
