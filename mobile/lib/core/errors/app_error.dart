import 'package:dio/dio.dart';

class AppError implements Exception {
  const AppError({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;

  @override
  String toString() => 'AppError(code: $code, message: $message, status: $statusCode)';

  static AppError fromDioException(DioException error) {
    if (error.response?.data is Map<String, dynamic>) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('error') && data['error'] is Map<String, dynamic>) {
        final errMap = data['error'] as Map<String, dynamic>;
        return AppError(
          code: errMap['code']?.toString() ?? 'API_ERROR',
          message: errMap['message']?.toString() ?? 'An error occurred',
          statusCode: error.response?.statusCode,
          details: errMap['details'],
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          code: 'TIMEOUT',
          message: 'Connection timed out. Please check your internet.',
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.connectionError:
        return const AppError(
          code: 'NO_INTERNET',
          message: 'No internet connection. Showing offline content.',
        );
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) {
          return const AppError(
            code: 'UNAUTHORIZED',
            message: 'Session expired. Please log in again.',
            statusCode: 401,
          );
        }
        if (status == 403) {
          return const AppError(
            code: 'FORBIDDEN',
            message: 'Access forbidden.',
            statusCode: 403,
          );
        }
        if (status == 404) {
          return const AppError(
            code: 'NOT_FOUND',
            message: 'Resource not found.',
            statusCode: 404,
          );
        }
        if (status != null && status >= 500) {
          return const AppError(
            code: 'SERVER_ERROR',
            message: 'Server error. Please try again shortly.',
            statusCode: 500,
          );
        }
        return AppError(
          code: 'BAD_RESPONSE',
          message: 'Unexpected server response.',
          statusCode: status,
        );
      case DioExceptionType.cancel:
        return const AppError(
          code: 'CANCELLED',
          message: 'Request was cancelled.',
        );
      default:
        return AppError(
          code: 'UNKNOWN',
          message: error.message ?? 'An unexpected error occurred.',
        );
    }
  }

  static const offline = AppError(
    code: 'OFFLINE',
    message: 'Device is offline.',
  );
}
