import 'package:flutter/material.dart';

/// App-wide color constants for consistent theming
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary Colors
  static const Color primary = Color(0xFF4675B8);
  static const Color primaryLight = Color(0xFF5A8FD8);
  static const Color primaryDark = Color(0xFF3A5E96);

  // Background Colors
  static const Color background = Colors.white;
  static const Color backgroundDark = Color(0xFFF5F5F5);

  // Text Colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textTertiary = Colors.black38;
  static const Color textLight = Colors.white;
  static const Color textHint = Colors.grey;

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF4675B8);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);

  // Accent Colors
  static const Color accent = Color(0xFF4675B8);
  static const Color accentLight = Color(0xFFE3F2FD);

  // Transparent/Overlay Colors
  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);
  static Color blackWithOpacity(double opacity) =>
      Colors.black.withValues(alpha: opacity);
  static Color whiteWithOpacity(double opacity) =>
      Colors.white.withValues(alpha: opacity);

  // Surface Colors
  static const Color surface = Colors.white;
  static Color surfaceVariant = Colors.grey.shade200;

  // Social Media Colors
  static const Color facebook = Color(0xFF1877F2);
  static const Color google = Color(0xFFDB4437);
  static const Color apple = Colors.black;
}
