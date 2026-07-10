# TripBond App - Animation Architecture

## Overview

This document outlines the professional animation system implemented in the TripBond travel app, following modern design principles similar to Airbnb, Notion, and Apple.

## Architecture

### 1. Core Animation System (`lib/core/animations/`)

#### `animation_constants.dart`
- Centralized timing and curve definitions
- Consistent animation durations across the app
- Physics-based easing curves for natural motion

**Key Constants:**
- `ultraFast`: 150ms - Micro-interactions
- `fast`: 250ms - Quick feedback
- `normal`: 350ms - Standard transitions
- `medium`: 500ms - Modal presentations
- `slow`: 800ms - Complex animations

#### `page_transitions.dart`
- Custom page route builders
- Reusable transition patterns
- Navigation mixin for easy implementation

**Available Transitions:**
- `FadePageRoute` - Subtle cross-fade
- `SlideUpPageRoute` - Bottom sheet style
- `SharedAxisPageRoute` - Material Design motion
- `ScaleFadePageRoute` - Elegant scale + fade

#### `animated_widgets.dart`
- Pre-built animated widget wrappers
- Staggered animations for lists
- Reusable animation patterns

## Implementation Guide

### Using Custom Page Transitions

```dart
// 1. Import the transitions
import 'package:tripbond_app/core/animations/page_transitions.dart';

// 2. Use in navigation
Navigator.push(
  context,
  SharedAxisPageRoute(page: NextScreen()),
);

// 3. Or use the mixin
class MyWidget extends StatelessWidget with AnimatedNavigationMixin {
  void navigateToNext(BuildContext context) {
    navigateWithSharedAxis(context, NextScreen());
  }
}
```

###Adding Animations to Widgets

```dart
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tripbond_app/core/animations/animation_constants.dart';

// Simple fade and slide
Widget build(BuildContext context) {
  return Text('Hello')
    .animate()
    .fadeIn(
      duration: const Duration(milliseconds: AnimationConstants.normal),
      curve: AnimationConstants.cubicEaseOut,
    )
    .slideY(begin: 0.1, end: 0);
}
```

### Staggered List Animations

```dart
// Automatically staggers children with delays
StaggeredListAnimation(
  delay: Duration(milliseconds: 200),
  itemDelay: Duration(milliseconds: 100),
  children: [
    ListTile(title: Text('Item 1')),
    ListTile(title: Text('Item 2')),
    ListTile(title: Text('Item 3')),
  ],
)
```

## Animation Principles

### 1. **Subtle Over Flashy**
- Animations should enhance, not distract
- Use small movements (0.05 - 0.1 offset values)
- Scales between 0.95 - 1.0 for subtle effects

### 2. **Consistent Timing**
- Always use `AnimationConstants` for durations
- Group related animations with same timing
- Stagger sequential items by 80-120ms

### 3. **Natural Easing**
- Use `cubicEaseOut` for most motion
- Avoid linear animations (looks robotic)
- Match easing to user expectations

### 4. **Performance First**
- Animate transform properties (translate, scale, opacity)
- Avoid animating expensive properties
- Test on low-end devices

## Screen-by-Screen Implementation

### Onboarding Screen
- **Illustration**: Scale + fade (800ms)
- **Title**: Slide up + fade (350ms, 200ms delay)
- **Subtitle**: Slide up + fade (350ms, 400ms delay)
- **Navigation**: SharedAxisPageRoute to login

### Login Screen
- **Header**: Scale + fade (500ms)
- **Title/Subtitle**: Staggered slide up (200-300ms delays)
- **Form fields**: Sequential fade-ins
- **Button**: Loading state with custom spinner

### Home Screen
- **Hero section**: Slide down + fade
- **Search bar**: Scale + fade (with delay)
- **Destination cards**: Staggered horizontal slides
- **Trip cards**: Slide from left with fade

### Navigation Transitions
- **Forward navigation**: SharedAxisPageRoute (350ms)
- **Modal presentation**: SlideUpPageRoute (500ms)
- **Back navigation**: FadePageRoute (250ms)

## Dependencies

```yaml
dependencies:
  lottie: ^3.1.0              # JSON animations
  flutter_animate: ^4.5.0     # Widget animations
  animations: ^2.0.11         # Material motion
```

## Future Enhancements

### Phase 1: Lottie Integration
- Replace static icons with Lottie animations
- Add loading state animations
- Success/error feedback animations

### Phase 2: Advanced Interactions
- Pull-to-refresh with custom animation
- Swipe gestures with haptic feedback
- Hero animations for image galleries

### Phase 3: Micro-interactions
- Button press states
- Card lift on hover/press
- Smooth scroll effects

## Best Practices

### DO:
✅ Use animation constants for consistency
✅ Test on multiple devices
✅ Provide escape hatches (prefer-reduced-motion)
✅ Animate on app start after content loads
✅ Chain related animations logically

### DON'T:
❌ Animate everything (causes fatigue)
❌ Use long durations (>800ms feels slow)
❌ Ignore performance implications
❌ Animate during loading states
❌ Use different eases for similar actions

## Performance Monitoring

```dart
// Enable performance overlay in debug mode
MaterialApp(
  showPerformanceOverlay: true, // Shows FPS
  debugShowCheckedModeBanner: false,
  // ...
)
```

## Accessibility

Always respect user preferences:

```dart
bool shouldAnimate = MediaQuery.of(context).disableAnimations == false;

if (shouldAnimate) {
  // Perform animation
} else {
  // Show final state immediately
}
```

## Resources

- [Material Motion](https://material.io/design/motion)
- [Apple HIG - Animation](https://developer.apple.com/design/human-interface-guidelines/motion)
- [LottieFiles](https://lottiefiles.com/)
- [flutter_animate docs](https://pub.dev/packages/flutter_animate)

---

**Last Updated**: February 2026
**Maintained by**: TripBond Development Team
