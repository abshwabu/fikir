import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FikirTheme {
  FikirTheme._();

  static const double cardRadius = 16;

  static ThemeData get lightTheme {
    final textTheme = FikirTypography.createTextTheme(isDark: false);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: FikirTypography.fontName,
      primaryColor: FikirColors.primaryCoral,
      scaffoldBackgroundColor: FikirColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: FikirColors.primaryCoral,
        secondary: FikirColors.primaryMagenta,
        surface: FikirColors.lightSurface,
        error: FikirColors.dislike,
        onSecondary: Colors.white,
        onSurface: FikirColors.lightTextPrimary,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: FikirColors.lightCard,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FikirColors.lightBackground,
        foregroundColor: FikirColors.lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: FikirColors.primaryMagenta,
        unselectedItemColor: FikirColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      dividerTheme: const DividerThemeData(
        color: FikirColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FikirColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FikirColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FikirColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FikirColors.primaryCoral, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = FikirTypography.createTextTheme(isDark: true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: FikirTypography.fontName,
      primaryColor: FikirColors.primaryCoral,
      scaffoldBackgroundColor: FikirColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: FikirColors.primaryCoral,
        secondary: FikirColors.primaryMagenta,
        surface: FikirColors.darkSurface,
        error: FikirColors.dislike,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: FikirColors.darkTextPrimary,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: FikirColors.darkCard,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FikirColors.darkBackground,
        foregroundColor: FikirColors.darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FikirColors.darkSurface,
        selectedItemColor: FikirColors.primaryMagenta,
        unselectedItemColor: FikirColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      dividerTheme: const DividerThemeData(
        color: FikirColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FikirColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FikirColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FikirColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FikirColors.primaryCoral, width: 2),
        ),
      ),
    );
  }
}
