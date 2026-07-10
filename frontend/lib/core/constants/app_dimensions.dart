import 'package:flutter/material.dart';

/// App-wide dimension constants for consistent spacing and sizing
class AppDimensions {
  AppDimensions._(); // Private constructor to prevent instantiation

  // Padding/Margin Sizes
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  static const double paddingXXLarge = 40.0;

  // Border Radius
  static const double radiusXSmall = 4.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusXXLarge = 24.0;
  static const double radiusRound = 30.0;

  // Common Border Radius
  static BorderRadius borderRadiusXSmall = BorderRadius.circular(radiusXSmall);
  static BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static BorderRadius borderRadiusXLarge = BorderRadius.circular(radiusXLarge);
  static BorderRadius borderRadiusXXLarge =
      BorderRadius.circular(radiusXXLarge);
  static BorderRadius borderRadiusRound = BorderRadius.circular(radiusRound);

  // Common Edge Insets
  static const EdgeInsets paddingAll8 = EdgeInsets.all(paddingSmall);
  static const EdgeInsets paddingAll16 = EdgeInsets.all(paddingMedium);
  static const EdgeInsets paddingAll24 = EdgeInsets.all(paddingLarge);
  static const EdgeInsets paddingAll32 = EdgeInsets.all(paddingXLarge);

  static const EdgeInsets paddingH16 =
      EdgeInsets.symmetric(horizontal: paddingMedium);
  static const EdgeInsets paddingH24 =
      EdgeInsets.symmetric(horizontal: paddingLarge);
  static const EdgeInsets paddingH32 =
      EdgeInsets.symmetric(horizontal: paddingXLarge);

  static const EdgeInsets paddingV8 =
      EdgeInsets.symmetric(vertical: paddingSmall);
  static const EdgeInsets paddingV16 =
      EdgeInsets.symmetric(vertical: paddingMedium);
  static const EdgeInsets paddingV24 =
      EdgeInsets.symmetric(vertical: paddingLarge);

  static const EdgeInsets paddingH16V8 = EdgeInsets.symmetric(
    horizontal: paddingMedium,
    vertical: paddingSmall,
  );
  static const EdgeInsets paddingH16V12 = EdgeInsets.symmetric(
    horizontal: paddingMedium,
    vertical: 12.0,
  );
  static const EdgeInsets paddingH20V10 = EdgeInsets.symmetric(
    horizontal: 20.0,
    vertical: 10.0,
  );
  static const EdgeInsets paddingH32V40 = EdgeInsets.symmetric(
    horizontal: paddingXLarge,
    vertical: paddingXXLarge,
  );

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;
  static const double iconXXLarge = 64.0;

  // Button Sizes
  static const double buttonHeightSmall = 40.0;
  static const double buttonHeightMedium = 48.0;
  static const double buttonHeightLarge = 52.0;
  static const double buttonWidthSmall = 120.0;
  static const double buttonWidthMedium = 200.0;

  // Floating Action Button
  static const double fabSize = 56.0;
  static const double fabIconSize = 24.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Spacing
  static const double spaceXSmall = 4.0;
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 16.0;
  static const double spaceLarge = 24.0;
  static const double spaceXLarge = 32.0;
  static const double spaceXXLarge = 48.0;

  // Common SizedBox
  static const SizedBox sizedBoxH4 = SizedBox(height: spaceXSmall);
  static const SizedBox sizedBoxH8 = SizedBox(height: spaceSmall);
  static const SizedBox sizedBoxH12 = SizedBox(height: 12.0);
  static const SizedBox sizedBoxH16 = SizedBox(height: spaceMedium);
  static const SizedBox sizedBoxH24 = SizedBox(height: spaceLarge);
  static const SizedBox sizedBoxH32 = SizedBox(height: spaceXLarge);
  static const SizedBox sizedBoxH48 = SizedBox(height: spaceXXLarge);
  static const SizedBox sizedBoxH60 = SizedBox(height: 60.0);
  static const SizedBox sizedBoxH80 = SizedBox(height: 80.0);

  static const SizedBox sizedBoxW4 = SizedBox(width: spaceXSmall);
  static const SizedBox sizedBoxW8 = SizedBox(width: spaceSmall);
  static const SizedBox sizedBoxW16 = SizedBox(width: spaceMedium);
  static const SizedBox sizedBoxW24 = SizedBox(width: spaceLarge);

  // Input Field
  static const double inputFieldHeight = 56.0;
  static const double inputFieldBorderWidth = 1.0;
}
