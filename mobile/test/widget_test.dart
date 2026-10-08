import 'package:fikir/core/design/theme.dart';
import 'package:fikir/core/design/typography.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:fikir/l10n/fallback_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Typography & Amharic Rendering Tests', () {
    testWidgets('renders Amharic text with NotoSansEthiopic font and adequate line height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
          home: const Scaffold(
            body: Center(
              child: Text(
                'ፍቅር - የኢትዮጵያውያን የፍቅር ጓደኛ መፈለጊያ',
                style: TextStyle(
                  fontFamily: FikirTypography.fontName,
                  fontSize: 18,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFinder = find.text('ፍቅር - የኢትዮጵያውያን የፍቅር ጓደኛ መፈለጊያ');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.fontFamily, equals('NotoSansEthiopic'));
      expect(textWidget.style?.height, greaterThanOrEqualTo(1.3));
    });

    testWidgets('loads all 4 supported locales correctly (en, am, om, ti)', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FallbackMaterialLocalizationsDelegate(),
              FallbackCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context)!;
                return Text(l10n.appName);
              },
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(l10n.appName, isNotEmpty);
        expect(l10n.navDiscover, isNotEmpty);
        expect(l10n.navMatches, isNotEmpty);
      }
    });
  });
}
