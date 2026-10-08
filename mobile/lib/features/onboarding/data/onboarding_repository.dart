import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fikir/core/errors/app_error.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/network/result.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/core/utils/image_compressor.dart';
import 'package:fikir/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingRepository(dio, prefs);
});

final onboardingStateNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final repo = ref.watch(onboardingRepositoryProvider);
  return OnboardingNotifier(repo);
});

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._repo) : super(_repo.loadDraft()) {
    // State loaded from disk immediately upon creation
  }

  final OnboardingRepository _repo;

  void updateState(OnboardingState Function(OnboardingState current) updater) {
    state = updater(state);
    _repo.saveDraft(state);
  }

  void nextStep() {
    if (state.currentStep < OnboardingState.totalSteps - 1) {
      updateState((s) => s.copyWith(currentStep: s.currentStep + 1));
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      updateState((s) => s.copyWith(currentStep: s.currentStep - 1));
    }
  }

  void reset() {
    state = const OnboardingState();
    _repo.saveDraft(state);
  }
}

class OnboardingRepository {
  OnboardingRepository(this._dio, this._prefs);

  final Dio _dio;
  final SharedPreferences _prefs;

  static const _draftKey = 'fikir_onboarding_draft';
  static const _completedKey = 'fikir_onboarding_completed';

  OnboardingState loadDraft() {
    final raw = _prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) {
      return const OnboardingState();
    }
    return OnboardingState.decode(raw);
  }

  Future<void> saveDraft(OnboardingState state) async {
    await _prefs.setString(_draftKey, state.encode());
  }

  bool isOnboardingComplete() {
    return _prefs.getBool(_completedKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool complete) async {
    await _prefs.setBool(_completedKey, complete);
    if (complete) {
      await _prefs.remove(_draftKey);
    }
  }

  /// Submits the completed onboarding profile and uploads compressed photos.
  Future<Result<bool, AppError>> submitOnboarding(OnboardingState state) async {
    try {
      // 1. Update Core Profile
      final birthdateStr = state.birthdate != null
          ? '${state.birthdate!.year}-${state.birthdate!.month.toString().padLeft(2, '0')}-${state.birthdate!.day.toString().padLeft(2, '0')}'
          : null;

      final profilePayload = <String, dynamic>{
        'display_name': state.name,
        'gender': state.gender,
        'interested_in': state.interestedIn,
        'city': state.city,
        if (birthdateStr != null) 'birthdate': birthdateStr,
        if (state.bio.isNotEmpty) 'bio': state.bio,
        if (state.jobTitle.isNotEmpty) 'job_title': state.jobTitle,
        if (state.religion != null) 'religion': state.religion,
        if (state.languages.isNotEmpty) 'languages': state.languages,
      };

      await _dio.patch<dynamic>('/v1/me/profile', data: profilePayload);

      // 2. Update Interests
      if (state.interests.isNotEmpty) {
        await _dio.put<dynamic>(
          '/v1/me/interests',
          data: {'interests': state.interests},
        );
      }

      // 3. Update Location
      final lat = state.latitude ?? 9.010;
      final lng = state.longitude ?? 38.761;
      await _dio.put<dynamic>(
        '/v1/me/location',
        data: {
          'latitude': lat,
          'longitude': lng,
          'city': state.city,
        },
      );

      // 4. Upload compressed photos
      for (final photoPath in state.photoPaths) {
        final file = File(photoPath);
        if (file.existsSync()) {
          await _uploadPhoto(file);
        }
      }

      await setOnboardingComplete(true);
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  Future<void> _uploadPhoto(File rawFile) async {
    // Compress on-device before upload: long edge 1440, WebP, EXIF stripped, < 400 KB
    final compressed = await ImageCompressor.compressForUpload(rawFile);

    // Step A: Request presigned upload URL
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

    if (uploadUrl == null || photoId == null) return;

    // Step B: Upload binary via PUT directly to storage URL
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

    // Step C: Complete upload to enqueue asynchronous processing
    await _dio.post<dynamic>('/v1/me/photos/$photoId/complete');
  }
}
