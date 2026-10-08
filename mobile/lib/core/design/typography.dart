import 'package:fikir/core/design/colors.dart';
import 'package:flutter/material.dart';

class FikirTypography {
  FikirTypography._();

  static const String fontName = 'NotoSansEthiopic';

  static TextTheme createTextTheme({required bool isDark}) {
    final primary = isDark ? FikirColors.darkTextPrimary : FikirColors.lightTextPrimary;
    final secondary = isDark ? FikirColors.darkTextSecondary : FikirColors.lightTextSecondary;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontName,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: primary,
        height: 1.3,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: fontName,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primary,
        height: 1.3,
        letterSpacing: -0.5,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontName,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.35,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontName,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.35,
      ),
      titleLarge: TextStyle(
        fontFamily: fontName,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontFamily: fontName,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontName,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: primary,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontName,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: secondary,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: fontName,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: secondary,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        fontFamily: fontName,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: primary,
        height: 1.3,
        letterSpacing: 0.2,
      ),
    );
  }
}
