import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/features/discover/domain/swipe_action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

abstract class SwipeRepository {
  Future<SwipeResult> recordSwipe({
    required String targetUserId,
    required SwipeDirection direction,
    DiscoveryProfileCard? candidate,
  });
  Future<bool> rewind();
  Future<int> syncPendingSwipes();
  Stream<SwipeResult> get matchStream;
}

class SwipeRepositoryImpl implements SwipeRepository {
  SwipeRepositoryImpl({
    required Dio dio,
    required AppDatabase db,
  })  : _dio = dio,
        _db = db {
    _initConnectivityListener();
  }

  final Dio _dio;
  final AppDatabase _db;
  final _uuid = const Uuid();
  final _matchController = StreamController<SwipeResult>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  Stream<SwipeResult> get matchStream => _matchController.stream;

  void _initConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline) {
        syncPendingSwipes();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _matchController.close();
  }

  @override
  Future<SwipeResult> recordSwipe({
    required String targetUserId,
    required SwipeDirection direction,
    DiscoveryProfileCard? candidate,
  }) async {
    final swipeId = _uuid.v4();
    final now = DateTime.now();

    // 1. Immediately persist to Drift offline outbox queue
    await _db.insertSwipeOutbox(
      SwipeOutboxEntry(
        id: swipeId,
        targetUserId: targetUserId,
        direction: direction.apiValue,
        createdAt: now,
        status: 'pending',
        retryCount: 0,
      ),
    );

    // 2. Dispatch network request optimistically in background
    unawaited(_sendSwipe(swipeId, targetUserId, direction, candidate));

    // Return immediate optimistic result (if candidate matched via local simulation or will notify via stream)
    return const SwipeResult(matched: false);
  }

  bool _isValidUuid(String str) {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str);
  }

  Future<void> _sendSwipe(
    String swipeId,
    String targetUserId,
    SwipeDirection direction,
    DiscoveryProfileCard? candidate,
  ) async {
    if (!_isValidUuid(targetUserId)) {
      await _db.markSwipeSynced(swipeId);
      return;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/swipes',
        data: {
          'target_id': targetUserId,
          'direction': direction.apiValue,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        await _db.markSwipeSynced(swipeId);
        final data = response.data!;
        final isMatched = data['matched'] as bool? ?? false;
        if (isMatched) {
          final result = SwipeResult.fromJson(data, matchedProfile: candidate);
          _matchController.add(result);
        }
      } else {
        await _db.markSwipeFailed(swipeId, 'Status ${response.statusCode}');
      }
    } catch (e) {
      await _db.markSwipeFailed(swipeId, e.toString());
    }
  }

  @override
  Future<bool> rewind() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/v1/swipes/rewind');
      if (response.statusCode == 200 && response.data != null) {
        return (response.data!['undone'] as bool?) ?? true;
      }
      return false;
    } catch (_) {
      // Local optimistic rewind fallback
      return true;
    }
  }

  @override
  Future<int> syncPendingSwipes() async {
    final pending = await _db.getPendingSwipes();
    var syncedCount = 0;

    for (final item in pending) {
      if (!_isValidUuid(item.targetUserId)) {
        await _db.markSwipeSynced(item.id);
        continue;
      }

      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/swipes',
          data: {
            'target_id': item.targetUserId,
            'direction': item.direction,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          await _db.markSwipeSynced(item.id);
          syncedCount++;

          final isMatched = response.data!['matched'] as bool? ?? false;
          if (isMatched) {
            final result = SwipeResult.fromJson(response.data!);
            _matchController.add(result);
          }
        } else {
          await _db.markSwipeFailed(item.id, 'Status ${response.statusCode}');
        }
      } catch (e) {
        await _db.markSwipeFailed(item.id, e.toString());
      }
    }

    return syncedCount;
  }
}

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  final repo = SwipeRepositoryImpl(dio: dio, db: db);
  ref.onDispose(repo.dispose);
  return repo;
});
