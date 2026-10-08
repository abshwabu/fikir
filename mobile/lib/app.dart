import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/design/theme.dart';
import 'package:fikir/core/router/app_router.dart';
import 'package:fikir/features/profile/presentation/profile_screen.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:fikir/l10n/fallback_localizations_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FikirApp extends ConsumerWidget {
  const FikirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(currentLocaleProvider);
    final themeMode = ref.watch(currentThemeModeProvider);

    return MaterialApp.router(
      title: AppConfig.instance.appName,
      debugShowCheckedModeBanner: AppConfig.instance.isDev,
      theme: FikirTheme.lightTheme,
      darkTheme: FikirTheme.darkTheme,
      themeMode: themeMode,
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
      routerConfig: router,
    );
  }
}
