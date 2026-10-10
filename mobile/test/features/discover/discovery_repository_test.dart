import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/features/discover/data/discovery_repository.dart';
import 'package:fikir/features/discover/data/swipe_repository.dart';
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
  late DiscoveryRepository discoveryRepo;
  late SwipeRepository swipeRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
    discoveryRepo = DiscoveryRepositoryImpl(dio: dio, db: db);
    swipeRepo = SwipeRepositoryImpl(dio: dio, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DiscoveryRepository Deck Deduplication & Outbox Filtering', () {
    test('Excludes swiped profiles from network deck', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'deck': [
              {
                'user_id': 'user-1',
                'display_name': 'Abebe',
                'age': 25,
                'gender': 'man',
                'distance_km': 2.0,
                'photos': <String>[],
                'interests': <String>[],
              },
              {
                'user_id': 'user-2',
                'display_name': 'Almaz',
                'age': 24,
                'gender': 'woman',
                'distance_km': 3.0,
                'photos': <String>[],
                'interests': <String>[],
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      // Swipe user-1
      await swipeRepo.recordSwipe(
        targetUserId: 'user-1',
        direction: SwipeDirection.like,
      );

      final deck = await discoveryRepo.fetchDeck();
      expect(deck.length, equals(1));
      expect(deck.first.userId, equals('user-2'));
    });

    test('Returns empty list when server returns empty deck (does not fall through to fallback cards)', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'deck': <Map<String, dynamic>>[]}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final deck = await discoveryRepo.fetchDeck();
      expect(deck, isEmpty);
    });

    test('Excludes swiped fallback cards in offline mode', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      // Swipe first mock card
      await swipeRepo.recordSwipe(
        targetUserId: 'mock-1-selamawit',
        direction: SwipeDirection.nope,
      );

      final deck = await discoveryRepo.fetchDeck();
      final userIds = deck.map((c) => c.userId).toSet();
      expect(userIds.contains('mock-1-selamawit'), isFalse);
      expect(deck.length, equals(DiscoveryRepositoryImpl.fallbackCards.length - 1));
    });

    test('Rewinding restores swiped profile to be discoverable again', () async {
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        if (options.path == '/v1/swipes/rewind') {
          return ResponseBody.fromString(
            jsonEncode({'undone': true, 'target_id': 'mock-1-selamawit'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      // Swipe mock-1-selamawit
      await swipeRepo.recordSwipe(
        targetUserId: 'mock-1-selamawit',
        direction: SwipeDirection.like,
      );

      var deck = await discoveryRepo.fetchDeck();
      expect(deck.any((c) => c.userId == 'mock-1-selamawit'), isFalse);

      // Rewind mock-1-selamawit
      await swipeRepo.rewind(targetUserId: 'mock-1-selamawit');

      deck = await discoveryRepo.fetchDeck();
      expect(deck.any((c) => c.userId == 'mock-1-selamawit'), isTrue);
    });
  });
}
