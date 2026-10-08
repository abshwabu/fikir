import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/network/websocket_manager.dart';
import 'package:fikir/features/chat/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  MockHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Dio dio;
  late WebSocketManager wsManager;

  setUp(() {
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
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));

    wsManager = WebSocketManager(
      dio: dio,
      db: db,
    );
  });

  tearDown(() async {
    wsManager.dispose();
    await db.close();
  });

  group('Chat State Machine & Replay Unit Tests', () {
    test('Optimistic send transitions status to sent on REST fallback', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        if (options.path.contains('/messages')) {
          return ResponseBody.fromString(
            jsonEncode({'status': 'sent'}),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 200);
      });

      final repo = ChatRepository(dio, db, wsManager);

      final clientMsgId = await repo.sendMessage(
        matchId: 'match-1',
        senderId: 'me',
        content: 'Selam! How are you?',
      );

      final messages = await db.getMessagesForMatch('match-1');
      expect(messages.length, equals(1));
      expect(messages.first.id, equals(clientMsgId));
      expect(messages.first.content, equals('Selam! How are you?'));
      expect(messages.first.status, equals('sent'));
    });

    test('Marks status failed on network failure, then retry succeeds', () async {
      var shouldFail = true;

      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        if (shouldFail) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'No connection',
          );
        }
        return ResponseBody.fromString(
          jsonEncode({'status': 'sent'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = ChatRepository(dio, db, wsManager);

      final clientMsgId = await repo.sendMessage(
        matchId: 'match-2',
        senderId: 'me',
        content: 'Are you free for coffee?',
      );

      var messages = await db.getMessagesForMatch('match-2');
      expect(messages.first.status, equals('failed'));

      // Retry when connection is restored
      shouldFail = false;
      await repo.retryMessage(messages.first);

      messages = await db.getMessagesForMatch('match-2');
      expect(messages.first.id, equals(clientMsgId));
      expect(messages.first.status, equals('sent'));
    });

    test('Deduplicates messages by client_msg_id on upsert', () async {
      const msgId = 'client_uuid_abc_123';
      final msg1 = CachedMessage(
        id: msgId,
        matchId: 'match-3',
        senderId: 'me',
        type: 'text',
        content: 'Initial optimistic text',
        status: 'pending',
        createdAt: DateTime.now(),
        cachedAt: DateTime.now(),
      );
      await db.upsertMessage(msg1);

      // Server acknowledges or updates existing record
      final msg2 = CachedMessage(
        id: msgId,
        matchId: 'match-3',
        senderId: 'me',
        type: 'text',
        content: 'Initial optimistic text',
        status: 'sent',
        createdAt: msg1.createdAt,
        cachedAt: DateTime.now(),
      );
      await db.upsertMessage(msg2);

      final messages = await db.getMessagesForMatch('match-3');
      expect(messages.length, equals(1));
      expect(messages.first.status, equals('sent'));
    });

    test('Replays missed messages from server and updates local database', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        expect(options.queryParameters['after_id'], equals(10));
        return ResponseBody.fromString(
          jsonEncode({
            'messages': [
              {
                'id': '11',
                'sender_id': 'user_betty',
                'content': 'I would love to meet up!',
                'type': 'text',
                'status': 'sent',
                'created_at': DateTime.now().toIso8601String(),
              },
              {
                'id': '12',
                'sender_id': 'user_betty',
                'content': 'How about Bole Tomoca?',
                'type': 'text',
                'status': 'sent',
                'created_at': DateTime.now().toIso8601String(),
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = ChatRepository(dio, db, wsManager);
      await repo.replayMissed('match-replay', afterId: 10);

      final messages = await db.getMessagesForMatch('match-replay');
      expect(messages.length, equals(2));
      expect(
        messages.map((m) => m.content),
        containsAll([
          'I would love to meet up!',
          'How about Bole Tomoca?',
        ]),
      );
    });
  });
}
