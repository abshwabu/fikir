import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/errors/app_error.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/network/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  return ProfileRepository(dio, db);
});

class ProfileRepository {
  ProfileRepository(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  /// Stale-while-revalidate: watches cached profile from SQLite and refreshes in background.
  Stream<CachedProfile?> watchMyProfile(String userId) {
    unawaited(_refreshProfile(userId));
    return _db.watchProfile(userId);
  }

  Future<void> _refreshProfile(String userId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/me/profile');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        await _saveProfileToCache(data, fallbackId: userId);
      }
    } catch (_) {
      // Offline or network error - cache is preserved
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> updateProfile({
    String? name,
    String? bio,
    DateTime? birthdate,
    String? gender,
    String? city,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (bio != null) payload['bio'] = bio;
      if (birthdate != null) payload['birthdate'] = birthdate.toIso8601String();
      if (gender != null) payload['gender'] = gender;
      if (city != null) payload['city'] = city;

      final response = await _dio.patch<Map<String, dynamic>>(
        '/v1/me/profile',
        data: payload,
      );

      final data = response.data ?? {};
      await _saveProfileToCache(data);

      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  Future<void> _saveProfileToCache(Map<String, dynamic> data, {String? fallbackId}) async {
    final id = (data['id'] as String?) ?? fallbackId;
    if (id == null) return;

    final birthdateStr = data['birthdate'] as String?;
    final birthdate = birthdateStr != null ? DateTime.parse(birthdateStr) : DateTime.now();

    final profile = CachedProfile(
      id: id,
      name: (data['name'] as String?) ?? 'User',
      bio: data['bio'] as String?,
      birthdate: birthdate,
      gender: (data['gender'] as String?) ?? 'other',
      city: data['city'] as String?,
      photosJson: jsonEncode(data['photos'] ?? []),
      interestsJson: jsonEncode(data['interests'] ?? []),
      completenessScore: (data['completeness_score'] as num?)?.toInt() ?? 0,
      isVerified: (data['is_verified'] as bool?) ?? false,
      lastActiveAt: data['last_active_at'] != null
          ? DateTime.tryParse(data['last_active_at'] as String)
          : null,
      cachedAt: DateTime.now(),
    );

    await _db.upsertProfile(profile);
  }
}
