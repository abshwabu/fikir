import 'package:flutter/material.dart';

class FikirColors {
  FikirColors._();

  // Brand Gradient: Warm Coral to Magenta
  static const Color primaryCoral = Color(0xFFFF5864);
  static const Color primaryMagenta = Color(0xFFFD297B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCoral, primaryMagenta],
  );

  static const LinearGradient verticalGradient = LinearGradient(
    colors: [primaryCoral, primaryMagenta],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Card photo overlay gradient (for high contrast text readability)
  static const LinearGradient photoOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Colors.black87],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.55, 1.0],
  );

  // Action Accents
  static const Color dislike = Color(0xFFFF4458);
  static const Color superLike = Color(0xFF00C4FF);
  static const Color like = Color(0xFF20D994);
  static const Color boost = Color(0xFFA044FF);
  static const Color gold = Color(0xFFF5B800);

  // Light Theme
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F8FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1E222B);
  static const Color lightTextSecondary = Color(0xFF757D8A);
  static const Color lightBorder = Color(0xFFE5E7EB);

  // Dark Theme
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF242424);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkBorder = Color(0xFF2E3138);
}
