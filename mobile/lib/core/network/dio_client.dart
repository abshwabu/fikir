import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/network/interceptors/auth_interceptor.dart';
import 'package:fikir/core/network/interceptors/connectivity_interceptor.dart';
import 'package:fikir/core/network/interceptors/retry_interceptor.dart';
import 'package:fikir/core/storage/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StateProvider<bool>((ref) {
  return false;
});

final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final connectivity = Connectivity();

  final options = BaseOptions(
    baseUrl: AppConfig.instance.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Encoding': 'gzip',
      'X-App-Flavor': AppConfig.instance.flavor.name,
    },
  );

  final dio = Dio(options);

  dio.interceptors.addAll([
    ConnectivityInterceptor(connectivity),
    AuthInterceptor(
      secureStorage: secureStorage,
      onUnauthorized: () {
        ref.read(authStateProvider.notifier).state = false;
      },
    ),
    RetryInterceptor(),
    if (AppConfig.instance.enableLogging)
      LogInterceptor(
        requestBody: true,
        responseHeader: false,
        responseBody: true,
      ),
  ]);

  return dio;
});
