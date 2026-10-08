import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/errors/app_error.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/network/result.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(preferencesServiceProvider);
  return MatchRepository(dio, db, prefs);
});

class MatchRepository {
  MatchRepository(this._dio, this._db, this._prefs);

  final Dio _dio;
  final AppDatabase _db;
  final PreferencesService _prefs;

  /// Stale-while-revalidate: watches cached matches and refreshes from network in background.
  Stream<List<CachedMatch>> watchMatches() {
    unawaited(refreshMatches());
    return _db.watchMatches();
  }

  Future<void> refreshMatches() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/matches');
      if (response.statusCode == 200 && response.data != null) {
        final matchesList = (response.data!['matches'] as List<dynamic>?) ?? [];
        for (final item in matchesList) {
          if (item is Map<String, dynamic>) {
            final id = (item['id'] ?? '').toString();
            if (id.isEmpty) continue;

            final matchedUser = (item['other_user'] as Map<String, dynamic>?) ??
                (item['matched_user'] as Map<String, dynamic>?) ??
                {};

            String? photoUrl;
            String? blurhash;
            final photos = matchedUser['photos'];
            if (photos is List && photos.isNotEmpty) {
              final first = photos.first;
              if (first is Map) {
                photoUrl = first['url'] as String?;
                blurhash = first['blurhash'] as String?;
              } else if (first is String) {
                photoUrl = first;
              }
            }
            photoUrl ??= matchedUser['photo_url'] as String?;
            blurhash ??= matchedUser['blurhash'] as String?;

            String? lastMsgText;
            DateTime? lastMsgAt;
            final lastMsg = item['last_message'];
            if (lastMsg is Map) {
              lastMsgText = (lastMsg['body'] ?? lastMsg['content']) as String?;
              if (lastMsg['created_at'] != null) {
                lastMsgAt = DateTime.tryParse(lastMsg['created_at'].toString());
              }
            } else if (lastMsg is String) {
              lastMsgText = lastMsg;
            }

            if (item['last_message_at'] != null) {
              lastMsgAt ??= DateTime.tryParse(item['last_message_at'].toString());
            }

            final match = CachedMatch(
              id: id,
              matchedUserId: (matchedUser['user_id'] ?? matchedUser['id'] ?? '').toString(),
              matchedUserName: (matchedUser['display_name'] ?? matchedUser['name'] ?? 'User').toString(),
              matchedUserPhotoUrl: photoUrl,
              matchedUserBlurhash: blurhash,
              lastMessageText: lastMsgText,
              lastMessageAt: lastMsgAt,
              unreadCount: (item['unread_count'] as num?)?.toInt() ?? 0,
              createdAt: item['created_at'] != null
                  ? DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now()
                  : DateTime.now(),
              cachedAt: DateTime.now(),
            );
            await _db.upsertMatch(match);
          }
        }
      }
    } catch (_) {
      // Offline / network failure - cached matches remain visible
    }
  }

  /// Unmatches a user, purging conversation locally and calling the backend endpoint.
  Future<Result<bool, AppError>> unmatch(String matchId) async {
    try {
      await _db.deleteMatch(matchId);
      final response = await _dio.delete<dynamic>('/v1/matches/$matchId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const Result.success(true);
      }
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  /// Reports a user for inappropriate behavior, harassment, spam, etc.
  Future<Result<bool, AppError>> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/v1/reports',
        data: {
          'reported_user_id': reportedUserId,
          'reason': reason,
          if (details != null && details.isNotEmpty) 'details': details,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return const Result.success(true);
      }
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  /// Blocks a user, storing in preferences and removing the match locally.
  Future<Result<bool, AppError>> blockUser(String userId, {String? matchId}) async {
    try {
      await _prefs.addBlockedUser(userId);
      if (matchId != null) {
        await _db.deleteMatch(matchId);
      }

      final response = await _dio.post<dynamic>('/v1/blocks/$userId');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return const Result.success(true);
      }
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  /// Unblocks a previously blocked user.
  Future<void> unblockUser(String userId) async {
    await _prefs.removeBlockedUser(userId);
    try {
      await _dio.delete<dynamic>('/v1/blocks/$userId');
    } catch (_) {}
  }
}
