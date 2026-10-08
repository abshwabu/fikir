import 'package:fikir/app.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.initialize(
    const AppConfig(
      flavor: AppFlavor.prod,
      appName: 'Fikir',
      apiBaseUrl: 'https://api.fikir.et',
      wsBaseUrl: 'wss://api.fikir.et/ws',
      cdnBaseUrl: 'https://cdn.fikir.et',
      enableLogging: false,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  final token = await secureStorage.read(key: 'fikir_access_token');
  final initialLoggedIn = token != null && token.isNotEmpty;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => initialLoggedIn),
      ],
      child: const FikirApp(),
    ),
  );
}
