import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/design/theme.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/features/auth/presentation/phone_screen.dart';
import 'package:fikir/features/auth/presentation/welcome_screen.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/features/onboarding/presentation/onboarding_flow_screen.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:fikir/l10n/fallback_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  Widget buildAmharicTestApp(Widget child, SharedPreferences prefs) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: FikirTheme.lightTheme,
        locale: const Locale('am'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FallbackMaterialLocalizationsDelegate(),
          FallbackCupertinoLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets('WelcomeScreen renders in Amharic without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildAmharicTestApp(const WelcomeScreen(), prefs));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ፍቅር'), findsOneWidget);
  });

  testWidgets('PhoneScreen renders in Amharic without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildAmharicTestApp(const PhoneScreen(), prefs));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('የስልክ ቁጥሬ'), findsOneWidget);
  });

  testWidgets('OnboardingFlowScreen renders all steps in Amharic without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    for (var step = 0; step < 7; step++) {
      container
          .read(onboardingStateNotifierProvider.notifier)
          .updateState((s) => s.copyWith(currentStep: step));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: FikirTheme.lightTheme,
            locale: const Locale('am'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FallbackMaterialLocalizationsDelegate(),
              FallbackCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OnboardingFlowScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
