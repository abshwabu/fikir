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

  const host = String.fromEnvironment('HOST_OVERRIDE', defaultValue: 'localhost');
  AppConfig.initialize(
    const AppConfig(
      flavor: AppFlavor.dev,
      appName: 'Fikir Dev',
      apiBaseUrl: 'http://$host:8080',
      wsBaseUrl: 'ws://$host:8080/ws',
      cdnBaseUrl: 'http://$host/media',
      enableLogging: true,
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
