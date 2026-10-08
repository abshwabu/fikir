import 'package:dio/dio.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/errors/app_error.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/network/result.dart';
import 'package:fikir/core/storage/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final db = ref.watch(databaseProvider);
  return AuthRepository(dio, secureStorage, db, ref);
});

class AuthRepository {
  AuthRepository(this._dio, this._secureStorage, this._db, this._ref);

  final Dio _dio;
  final SecureStorageService _secureStorage;
  final AppDatabase _db;
  final Ref _ref;

  Future<Result<bool, AppError>> requestOtp(String phone) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/otp/request',
        data: {'phone': phone},
        options: Options(extra: {'skipAuth': true}),
      );

      return Result.success(response.statusCode == 200 || response.statusCode == 201);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> verifyOtp({
    required String phone,
    required String code,
    String? fcmToken,
    String platform = 'android',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/otp/verify',
        data: {
          'phone': phone,
          'code': code,
          'device': {
            'fcm_token': fcmToken ?? 'dev_token',
            'platform': platform,
          },
        },
        options: Options(extra: {'skipAuth': true}),
      );

      final data = response.data ?? {};
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      final userId = user?['id'] as String?;

      if (accessToken != null && refreshToken != null) {
        await _secureStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
        );

        _ref.read(authStateProvider.notifier).state = true;
      }

      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post<dynamic>(
          '/v1/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Ignore network failures on logout
    } finally {
      await _secureStorage.clearAuth();
      await _db.clearAll();
      _ref.read(authStateProvider.notifier).state = false;
    }
  }

  Future<Result<bool, AppError>> deleteAccount() async {
    try {
      await _dio.delete<dynamic>('/v1/me');
      await _secureStorage.clearAuth();
      await _db.clearAll();
      _ref.read(authStateProvider.notifier).state = false;
      return const Result.success(true);
    } on DioException catch (e) {
      return Result.failure(AppError.fromDioException(e));
    } catch (e) {
      return Result.failure(AppError(code: 'UNKNOWN', message: e.toString()));
    }
  }
}
