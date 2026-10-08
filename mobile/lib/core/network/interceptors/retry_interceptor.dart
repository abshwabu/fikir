import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 4),
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final Random _random = Random();

  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  bool _isIdempotent(RequestOptions options) {
    if (options.extra['idempotent'] == true) return true;
    if (options.extra['idempotent'] == false) return false;
    return _idempotentMethods.contains(options.method.toUpperCase());
  }

  bool _shouldRetry(DioException error) {
    // Only retry idempotent calls
    if (!_isIdempotent(error.requestOptions)) return false;

    // Retry on network errors and timeouts
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        // 502 Bad Gateway, 503 Service Unavailable, 504 Gateway Timeout, 429 Too Many Requests
        return status == 502 || status == 503 || status == 504 || status == 429;
      default:
        return false;
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;

    if (retryCount >= maxRetries || !_shouldRetry(err)) {
      return handler.next(err);
    }

    final nextRetry = retryCount + 1;
    err.requestOptions.extra['retryCount'] = nextRetry;

    // Exponential backoff with jitter
    final backoffMs = (initialDelay.inMilliseconds * pow(2, retryCount)).toInt();
    final jitterMs = _random.nextInt(200);
    final delayMs = min(backoffMs + jitterMs, maxDelay.inMilliseconds);

    await Future<void>.delayed(Duration(milliseconds: delayMs));

    try {
      final dio = Dio();
      final response = await dio.fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    } catch (e) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: e,
        ),
      );
    }
  }
}
