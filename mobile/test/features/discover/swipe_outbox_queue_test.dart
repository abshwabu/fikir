import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/features/discover/data/swipe_repository.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/features/discover/domain/swipe_action.dart';
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
  });

  tearDown(() async {
    await db.close();
  });

  group('Swipe Outbox & Offline Queue Tests', () {
    test('Optimistically inserts pending record into Drift database', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'matched': false}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = SwipeRepositoryImpl(dio: dio, db: db);
      addTearDown(repo.dispose);

      const candidate = DiscoveryProfileCard(
        userId: 'target-123',
        displayName: 'Selam',
        age: 24,
        gender: 'woman',
        distanceKm: 4,
      );

      final result = await repo.recordSwipe(
        targetUserId: candidate.userId,
        direction: SwipeDirection.like,
        candidate: candidate,
      );

      expect(result.matched, isFalse);

      // Give unawaited background task a brief tick to persist and update status
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Verify the record is in Drift
      final allSwipes = await db.select(db.swipeOutbox).get();
      expect(allSwipes.length, equals(1));
      expect(allSwipes.first.targetUserId, equals('target-123'));
      expect(allSwipes.first.direction, equals('like'));
      expect(allSwipes.first.status, equals('synced'));
    });

    test('Marks record failed when offline and retains in pending queue', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'No internet',
        );
      });

      final repo = SwipeRepositoryImpl(dio: dio, db: db);
      addTearDown(repo.dispose);

      await repo.recordSwipe(
        targetUserId: 'target-offline',
        direction: SwipeDirection.nope,
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Record is in outbox with failed status and retryCount 1
      final pending = await db.getPendingSwipes();
      expect(pending.length, equals(1));
      expect(pending.first.targetUserId, equals('target-offline'));
      expect(pending.first.status, equals('failed'));
      expect(pending.first.retryCount, equals(1));
    });

    test('syncPendingSwipes successfully syncs offline swipes on reconnection and fires match',
        () async {
      var isOnline = false;

      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        if (!isOnline) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return ResponseBody.fromString(
          jsonEncode({
            'matched': true,
            'match': {'id': 'match-xyz-789'},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = SwipeRepositoryImpl(dio: dio, db: db);
      addTearDown(repo.dispose);

      // Record swipe while offline
      await repo.recordSwipe(
        targetUserId: 'target-matched-user',
        direction: SwipeDirection.superLike,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final pendingBefore = await db.getPendingSwipes();
      expect(pendingBefore.length, equals(1));
      expect(pendingBefore.first.status, equals('failed'));

      // Listen for match events
      final matchesEmitted = <SwipeResult>[];
      final sub = repo.matchStream.listen(matchesEmitted.add);
      addTearDown(sub.cancel);

      // Simulate connection restoration
      isOnline = true;
      final syncedCount = await repo.syncPendingSwipes();
      expect(syncedCount, equals(1));

      // Outbox item is now marked synced
      final pendingAfter = await db.getPendingSwipes();
      expect(pendingAfter, isEmpty);

      // Match event emitted through matchStream
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(matchesEmitted.length, equals(1));
      expect(matchesEmitted.first.matched, isTrue);
      expect(matchesEmitted.first.matchId, equals('match-xyz-789'));
    });

    test('rewind sends API request and returns undone status', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        expect(options.path, equals('/v1/swipes/rewind'));
        return ResponseBody.fromString(
          jsonEncode({'undone': true, 'target_id': 'target-123'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = SwipeRepositoryImpl(dio: dio, db: db);
      addTearDown(repo.dispose);

      final undone = await repo.rewind();
      expect(undone, isTrue);
    });
  });
}
