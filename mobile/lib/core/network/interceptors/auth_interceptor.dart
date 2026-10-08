import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/storage/secure_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.secureStorage,
    this.onUnauthorized,
  });

  final SecureStorageService secureStorage;
  final void Function()? onUnauthorized;

  Completer<bool>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;
    if (skipAuth) {
      return handler.next(options);
    }

    final token = await secureStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final isAuthEndpoint = err.requestOptions.path.contains('/v1/auth/');
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (!is401 || isAuthEndpoint || alreadyRetried) {
      return handler.next(err);
    }

    // Mark as retried so we never loop
    err.requestOptions.extra['retried'] = true;

    if (_refreshCompleter != null) {
      // Refresh is already in progress, wait for it
      final success = await _refreshCompleter!.future;
      if (success) {
        return _retryRequest(err.requestOptions, handler);
      } else {
        return handler.next(err);
      }
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter?.complete(false);
        _refreshCompleter = null;
        await secureStorage.clearAuth();
        onUnauthorized?.call();
        return handler.next(err);
      }

      // Use a clean Dio instance to avoid interceptor recursion
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.instance.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await secureStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          _refreshCompleter?.complete(true);
          _refreshCompleter = null;

          return _retryRequest(err.requestOptions, handler);
        }
      }

      _refreshCompleter?.complete(false);
      _refreshCompleter = null;
      await secureStorage.clearAuth();
      onUnauthorized?.call();
      return handler.next(err);
    } catch (_) {
      _refreshCompleter?.complete(false);
      _refreshCompleter = null;
      await secureStorage.clearAuth();
      onUnauthorized?.call();
      return handler.next(err);
    }
  }

  Future<void> _retryRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
  ) async {
    final newAccessToken = await secureStorage.getAccessToken();
    if (newAccessToken != null) {
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
    }

    try {
      final retryDio = Dio();
      final response = await retryDio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    } catch (e) {
      handler.next(
        DioException(
          requestOptions: requestOptions,
          error: e,
        ),
      );
    }
  }
}
