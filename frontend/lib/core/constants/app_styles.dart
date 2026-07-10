import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

/// Common button styles for consistent UI across the app
class AppButtonStyles {
  AppButtonStyles._(); // Private constructor to prevent instantiation

  // Primary Button Style
  static ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textLight,
    shape: RoundedRectangleBorder(
      borderRadius: AppDimensions.borderRadiusMedium,
    ),
    elevation: AppDimensions.elevationNone,
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightMedium),
  );

  // Primary Button with Disabled State
  static ButtonStyle primaryWithDisabled = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textLight,
    disabledBackgroundColor: AppColors.primaryWithOpacity(0.6),
    shape: RoundedRectangleBorder(
      borderRadius: AppDimensions.borderRadiusMedium,
    ),
    elevation: AppDimensions.elevationNone,
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightMedium),
  );

  // Large Primary Button
  static ButtonStyle primaryLarge = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textLight,
    shape: RoundedRectangleBorder(
      borderRadius: AppDimensions.borderRadiusMedium,
    ),
    elevation: AppDimensions.elevationNone,
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLarge),
  );

  // Circular Button Style (for FAB-like buttons)
  static ButtonStyle circular = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textLight,
    shape: const CircleBorder(),
    elevation: AppDimensions.elevationLow,
    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
  );

  // Outline Button Style
  static ButtonStyle outline = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: AppDimensions.borderRadiusMedium,
    ),
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightMedium),
  );

  // Text Button Style
  static ButtonStyle text = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    padding: AppDimensions.paddingH16V8,
  );

  // Rounded Button Style (pill-shaped)
  static ButtonStyle rounded = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25),
    ),
    elevation: AppDimensions.elevationNone,
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightMedium),
  );
}

/// Common input field decorations
class AppInputDecorations {
  AppInputDecorations._(); // Private constructor to prevent instantiation

  // Default Input Decoration
  static InputDecoration defaultDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: AppDimensions.borderRadiusMedium,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppDimensions.borderRadiusMedium,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppDimensions.borderRadiusMedium,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppDimensions.borderRadiusMedium,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: AppDimensions.paddingH16V12,
    );
  }
}

/// Common box decorations
class AppBoxDecorations {
  AppBoxDecorations._(); // Private constructor to prevent instantiation

  // Card Decoration
  static BoxDecoration card = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppDimensions.borderRadiusLarge,
    boxShadow: [
      BoxShadow(
        color: AppColors.blackWithOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Rounded Container
  static BoxDecoration roundedContainer = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppDimensions.borderRadiusMedium,
  );

  // Container with Border
  static BoxDecoration containerWithBorder = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppDimensions.borderRadiusMedium,
    border: Border.all(color: AppColors.border),
  );

  // Container with Primary Border
  static BoxDecoration containerWithPrimaryBorder = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppDimensions.borderRadiusMedium,
    border: Border.all(color: AppColors.primary, width: 2),
  );

  // Gradient Container
  static BoxDecoration gradientContainer = BoxDecoration(
    borderRadius: AppDimensions.borderRadiusMedium,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.primary,
        AppColors.primaryDark,
      ],
    ),
  );
}
