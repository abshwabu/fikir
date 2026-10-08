import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/design/theme.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/features/auth/presentation/otp_screen.dart';
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

  testWidgets('renders 6 PIN boxes, phone number, and resend countdown',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: FikirTheme.lightTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FallbackMaterialLocalizationsDelegate(),
            FallbackCupertinoLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OtpScreen(phoneNumber: '+251911223344'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify phone number displayed
    expect(find.textContaining('+251911223344'), findsOneWidget);

    // Verify 6 digit input boxes
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(6));

    // Verify resend code timer is present
    expect(find.textContaining('('), findsOneWidget);

    // Enter digits into boxes
    await tester.enterText(textFields.at(0), '1');
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.enterText(textFields.at(1), '2');
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });
}
