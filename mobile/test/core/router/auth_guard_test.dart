import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/core/router/app_router.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/features/auth/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AppConfig.initialize(
      const AppConfig(
        flavor: AppFlavor.dev,
        appName: 'Fikir Test',
        apiBaseUrl: 'http://localhost:8080',
        wsBaseUrl: 'ws://localhost:8080/ws',
        cdnBaseUrl: 'http://localhost:9000/public',
        enableLogging: false,
      ),
    );
  });

  testWidgets('redirects to /auth when unauthenticated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => false),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify WelcomeScreen is shown
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
