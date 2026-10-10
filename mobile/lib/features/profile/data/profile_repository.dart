import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/errors/app_error.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/network/result.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/core/utils/image_compressor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfilePhoto {
  const UserProfilePhoto({
    required this.id,
    required this.url,
    this.position = 0,
    this.blurhash,
  });

  factory UserProfilePhoto.fromMap(Map<String, dynamic> map) {
    return UserProfilePhoto(
      id: (map['id'] ?? '').toString(),
      url: (map['url'] ?? '').toString(),
      position: (map['position'] as num?)?.toInt() ?? 0,
      blurhash: map['blurhash'] as String?,
    );
  }

  final String id;
  final String url;
  final int position;
  final String? blurhash;

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'position': position,
    if (blurhash != null) 'blurhash': blurhash,
  };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.birthdate,
    required this.gender,
    this.bio,
    this.city,
    this.jobTitle,
    this.education,
    this.heightCm,
    this.religion,
    this.languages = const [],
    this.interests = const [],
    this.photos = const [],
    this.completenessScore = 0,
    this.isVerified = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final photoList = <UserProfilePhoto>[];
    if (json['photos'] is List) {
      for (final p in json['photos'] as List) {
        if (p is Map<String, dynamic>) {
          photoList.add(UserProfilePhoto.fromMap(p));
        } else if (p is Map) {
          photoList.add(UserProfilePhoto.fromMap(Map<String, dynamic>.from(p)));
        } else if (p is String && p.isNotEmpty) {
          photoList.add(UserProfilePhoto(id: '', url: p));
        }
      }
    }

    final interestList = <String>[];
    if (json['interests'] is List) {
      for (final e in json['interests'] as List) {
        interestList.add(e.toString());
      }
    }

    final langList = <String>[];
    if (json['languages'] is List) {
      for (final e in json['languages'] as List) {
        langList.add(e.toString());
      }
    }

    var parsedBirthdate = DateTime(1998);
    if (json['birthdate'] != null) {
      final bStr = json['birthdate'].toString();
      final parsed = DateTime.tryParse(bStr);
      if (parsed != null) parsedBirthdate = parsed;
    }

    return UserProfile(
      id: (json['user_id'] ?? json['id'] ?? 'me').toString(),
      name: (json['display_name'] ?? json['name'] ?? 'User').toString(),
      bio: json['bio'] as String?,
      birthdate: parsedBirthdate,
      gender: (json['gender'] ?? 'other').toString(),
      city: json['city'] as String?,
      jobTitle: json['job_title'] as String?,
      education: json['education'] as String?,
      heightCm: (json['height_cm'] as num?)?.toInt(),
      religion: json['religion'] as String?,
      languages: langList,
      interests: interestList,
      photos: photoList,
      completenessScore: (json['completeness_score'] as num?)?.toInt() ?? 0,
      isVerified: (json['verified'] ?? json['is_verified'] ?? false) as bool,
    );
  }

  factory UserProfile.fromCachedProfile(CachedProfile cached) {
    final photoList = <UserProfilePhoto>[];
    try {
      final list = jsonDecode(cached.photosJson) as List<dynamic>;
      for (final p in list) {
        if (p is Map<String, dynamic>) {
          photoList.add(UserProfilePhoto.fromMap(p));
        } else if (p is Map) {
          photoList.add(UserProfilePhoto.fromMap(Map<String, dynamic>.from(p)));
        } else if (p is String && p.isNotEmpty) {
          photoList.add(UserProfilePhoto(id: '', url: p));
        }
      }
    } catch (_) {}

    var interestList = <String>[];
    try {
      final list = jsonDecode(cached.interestsJson) as List<dynamic>;
      interestList = list.map((e) => e.toString()).toList();
    } catch (_) {}

    return UserProfile(
      id: cached.id,
      name: cached.name,
      bio: cached.bio,
      birthdate: cached.birthdate,
      gender: cached.gender,
      city: cached.city,
      photos: photoList,
      interests: interestList,
      completenessScore: cached.completenessScore,
      isVerified: cached.isVerified,
    );
  }

  final String id;
  final String name;
  final String? bio;
  final DateTime birthdate;
  final String gender;
  final String? city;
  final String? jobTitle;
  final String? education;
  final int? heightCm;
  final String? religion;
  final List<String> languages;
  final List<String> interests;
  final List<UserProfilePhoto> photos;
  final int completenessScore;
  final bool isVerified;

  String? get avatarUrl {
    final valid = photos.where((p) => p.url.isNotEmpty);
    if (valid.isNotEmpty) return valid.first.url;
    return null;
  }

  Map<String, dynamic> toJson() => {
    'user_id': id,
    'display_name': name,
    'bio': bio,
    'birthdate': '${birthdate.year}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}',
    'gender': gender,
    'city': city,
    'job_title': jobTitle,
    'education': education,
    'height_cm': heightCm,
    'religion': religion,
    'languages': languages,
    'interests': interests,
    'photos': photos.map((p) => p.toMap()).toList(),
    'completeness_score': completenessScore,
    'verified': isVerified,
  };
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return ProfileRepository(dio, db, prefs);
});

final myUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchProfile();
});

final myProfileStreamProvider = StreamProvider<CachedProfile?>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchMyProfile('me');
});

final myProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final profile = await repo.getMyProfile();
  return profile?.toJson();
});

class ProfileRepository {
  ProfileRepository(this._dio, this._db, this._prefs);

  final Dio _dio;
  final AppDatabase _db;
  final SharedPreferences _prefs;

  final _profileController = StreamController<UserProfile?>.broadcast();

  static const _cacheKeyFullProfile = 'cached_me_full_profile';

  Stream<UserProfile?> watchProfile() async* {
    final cached = getCachedProfile();
    if (cached != null) {
      yield cached;
    }
    unawaited(refreshProfile());
    yield* _profileController.stream;
  }

  UserProfile? getCachedProfile() {
    final raw = _prefs.getString(_cacheKeyFullProfile);
    if (raw != null) {
      try {
        return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  Stream<CachedProfile?> watchMyProfile(String userId) {
    unawaited(refreshProfile());
    return _db.watchProfile('me');
  }

  Future<UserProfile?> getMyProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/me/profile');
      if (response.statusCode == 200 && response.data != null) {
        final profile = UserProfile.fromJson(response.data!);
        await _saveProfileLocally(profile, response.data!);
        _profileController.add(profile);
        return profile;
      }
    } catch (e) {
      debugPrint('[ProfileRepository] getMyProfile network error: $e');
    }

    final cached = getCachedProfile();
    if (cached != null) {
      _profileController.add(cached);
      return cached;
    }

    // Fallback to SQLite cached profile
    final dbProfile = await _db.getProfile('me');
    if (dbProfile != null) {
      final profile = UserProfile.fromCachedProfile(dbProfile);
      _profileController.add(profile);
      return profile;
    }

    return null;
  }

  Future<void> refreshProfile() async {
    await getMyProfile();
  }

  Future<Result<UserProfile, AppError>> updateProfile({
    String? displayName,
    String? bio,
    DateTime? birthdate,
    String? gender,
    String? city,
    String? jobTitle,
    String? education,
    int? heightCm,
    String? religion,
    List<String>? languages,
    List<String>? interests,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (displayName != null) payload['display_name'] = displayName;
      if (bio != null) payload['bio'] = bio;
      if (birthdate != null) {
        payload['birthdate'] =
            '${birthdate.year}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}';
      }
      if (gender != null) payload['gender'] = gender;
      if (city != null) payload['city'] = city;
      if (jobTitle != null) payload['job_title'] = jobTitle;
      if (education != null) payload['education'] = education;
      if (heightCm != null) payload['height_cm'] = heightCm;
      if (religion != null) payload['religion'] = religion;
      if (languages != null) payload['languages'] = languages;

      final response = await _dio.patch<Map<String, dynamic>>(
        '/v1/me/profile',
        data: payload,
      );

      // Update interests if provided
      if (interests != null) {
        try {
          await _dio.put<dynamic>(
            '/v1/me/interests',
            data: {'interests': interests},
          );
        } catch (e) {
          debugPrint('[ProfileRepository] update interests error: $e');
        }
      }

      // Re-fetch fresh profile from backend to ensure all fields and photos are synchronized
      final refreshed = await getMyProfile();
      if (refreshed != null) {
        return Result.success(refreshed);
      }

      final data = response.data ?? {};
      if (interests != null) data['interests'] = interests;
      final profile = UserProfile.fromJson(data);
      await _saveProfileLocally(profile, data);
      _profileController.add(profile);

      return Result.success(profile);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  Future<Result<bool, AppError>> uploadPhoto(File rawFile) async {
    try {
      final compressed = await ImageCompressor.compressForUpload(rawFile);
      final urlRes = await _dio.post<Map<String, dynamic>>(
        '/v1/me/photos/upload-url',
        data: {
          'content_type': compressed.mimeType,
          'file_size': compressed.sizeInBytes,
        },
      );

      final data = urlRes.data ?? {};
      final uploadUrl = data['upload_url'] as String?;
      final photoId = data['photo_id'] as String?;

      if (uploadUrl == null || photoId == null) {
        return const Result.failure(AppError(code: 'UPLOAD_FAILED', message: 'Failed to obtain upload URL'));
      }

      final fileBytes = await compressed.file.readAsBytes();
      final uploadDio = Dio();
      await uploadDio.put<dynamic>(
        uploadUrl,
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {
            'Content-Type': compressed.mimeType,
            'Content-Length': compressed.sizeInBytes,
          },
        ),
      );

      await _dio.post<dynamic>('/v1/me/photos/$photoId/complete');
      await refreshProfile();
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  Future<Result<bool, AppError>> deletePhoto(String photoId) async {
    try {
      await _dio.delete<dynamic>('/v1/me/photos/$photoId');
      await refreshProfile();
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  Future<void> _saveProfileLocally(UserProfile profile, Map<String, dynamic> raw) async {
    try {
      await _prefs.setString(_cacheKeyFullProfile, jsonEncode(raw));
    } catch (_) {}
    await _saveProfileToCache(raw);
  }

  Future<void> _saveProfileToCache(Map<String, dynamic> data, {String? fallbackId}) async {
    final id = (data['user_id'] as String?) ?? (data['id'] as String?) ?? fallbackId ?? 'me';

    final birthdateStr = data['birthdate'] as String?;
    final birthdate = birthdateStr != null
        ? DateTime.tryParse(birthdateStr) ?? DateTime.now()
        : DateTime.now();

    final name = (data['display_name'] as String?) ?? (data['name'] as String?) ?? 'User';
    final isVerified = (data['verified'] as bool?) ?? (data['is_verified'] as bool?) ?? false;

    final profile = CachedProfile(
      id: 'me',
      name: name,
      bio: data['bio'] as String?,
      birthdate: birthdate,
      gender: (data['gender'] as String?) ?? 'other',
      city: data['city'] as String?,
      photosJson: jsonEncode(data['photos'] ?? []),
      interestsJson: jsonEncode(data['interests'] ?? []),
      completenessScore: (data['completeness_score'] as num?)?.toInt() ?? 0,
      isVerified: isVerified,
      lastActiveAt: data['last_active_at'] != null
          ? DateTime.tryParse(data['last_active_at'] as String)
          : null,
      cachedAt: DateTime.now(),
    );

    await _db.upsertProfile(profile);
    if (id != 'me') {
      await _db.upsertProfile(profile.copyWith(id: id));
    }
  }
}
