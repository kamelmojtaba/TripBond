# Animations Directory

This directory contains Lottie JSON animation files for the TripBond app.

## Recommended Animations

### Onboarding Animations
Place your Lottie JSON files here to replace the static images:

- `onboard1.json` - Travel/exploration animation (replaces onboard1.png)
- `onboard2.json` - Group planning animation (replaces onboard2.png)
- `onboard3.json` - Connection/bonding animation (replaces onboard3.png)

### Loading Animations
- `loading_spinner.json` - Custom loading animation (optional enhancement)

### Success/Error Animations
- `success.json` - Success checkmark animation
- `error.json` - Error animation
- `empty_state.json` - Empty state placeholder

## Where to Find Free Lottie Animations

1. **LottieFiles** (https://lottiefiles.com/)
   - Free high-quality animations
   - Categories: Travel, UI, Loading, etc.
   
2. **IconScout** (https://iconscout.com/lottie-animations)
   - Premium and free animations
   - Travel-specific collections

## Usage Example

Once you download a Lottie JSON file, place it in this directory and use it like this:

```dart
import 'package:lottie/lottie.dart';

// In your widget:
Lottie.asset(
  'assets/animations/onboard1.json',
  width: 200,
  height: 200,
  fit: BoxFit.contain,
)
```

## Animation Style Guide

For consistent branding, choose animations that are:
- **Minimal** - Clean, simple illustrations
- **Smooth** - 60fps, no jerky movements
- **On-brand** - Blue color palette (primary: #4675B8)
- **Professional** - Premium feel, not cartoonish

## File Size Recommendations

- Keep JSON files under 200KB for optimal performance
- Use compressed/optimized versions when available
- Test on low-end devices to ensure smooth playback

## Current Implementation

The app currently uses static PNG images with animated transitions. To upgrade to Lottie:

1. Download suitable animations from LottieFiles
2. Place JSON files in this directory
3. Update `onboarding_screen.dart` to use `Lottie.asset()` instead of `Image.asset()`

Example replacement in onboarding_screen.dart:

```dart
// Replace this:
Image.asset(
  page.image,
  fit: BoxFit.contain,
)

// With this:
Lottie.asset(
  page.lottieAnimation,
  fit: BoxFit.contain,
)
```
