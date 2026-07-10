# Quick Reference: TripBond Animations 🎬

## Common Animation Patterns

### 1. Fade In + Slide Up
```dart
Widget
  .animate()
  .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
  .slideY(begin: 0.1, end: 0);
```

### 2. Scale + Fade (Cards)
```dart
Container(...)
  .animate()
  .scale(begin: Offset(0.95, 0.95), duration: 350.ms)
  .fadeIn(duration: 350.ms);
```

### 3. Staggered List
```dart
Column(
  children: items.map((item, index) =>
    item
      .animate(delay: (100 * index).ms)
      .fadeIn()
      .slideX(begin: 0.1)
  ).toList(),
)
```

## Navigation Shortcuts

### Standard Navigation
```dart
Navigator.push(context, SharedAxisPageRoute(page: NextScreen()));
```

### Fade Navigation
```dart
Navigator.pushReplacement(context, FadePageRoute(page: HomeScreen()));
```

### Modal Presentation
```dart
Navigator.push(context, SlideUpPageRoute(page: ModalScreen()));
```

## Timing Reference

| Constant | Duration | Use For |
|----------|----------|---------|
| `AnimationConstants.ultraFast` | 150ms | Button feedback |
| `AnimationConstants.fast` | 250ms | Tooltips |
| `AnimationConstants.normal` | 350ms | **Default choice** |
| `AnimationConstants.medium` | 500ms | Modals |
| `AnimationConstants.slow` | 800ms | Complex scenes |

## Easing Curves

```dart
// Recommended (natural feel)
AnimationConstants.cubicEaseOut  // Most common
AnimationConstants.smoothEaseOut // Gentler

// Special cases
Curves.easeInOut                 // Symmetrical
Curves.elasticOut                // Bounce effect (use sparingly)
```

## Loading States

```dart
// In button
child: _isLoading
  ? CustomLoadingSpinner(
      fontSize: 14,
      dotSize: 8,
      textColor: Colors.white,
      dotColors: [Colors.white, Colors.white70, Colors.white54],
    )
  : Text('Submit')
```

## Best Practices

### DO ✅
- Use `AnimationConstants` for timing
- Start with `normal` (350ms) duration
- Use `cubicEaseOut` for most animations
- Test on real devices
- Animate transform properties only

### DON'T ❌
- Don't use durations > 800ms
- Don't animate everything
- Don't use linear easing
- Don't animate expensive rebuilds
- Don't forget accessibility

## Common Offsets

```dart
// Subtle movements (recommended)
begin: 0.05  // Very subtle
begin: 0.1   // Standard
begin: 0.2   // Pronounced

// Scales (subtle is premium)
begin: Offset(0.95, 0.95)  // Recommended
begin: Offset(0.9, 0.9)    // More obvious
```

## Debug Tips

```dart
// Show FPS overlay
MaterialApp(showPerformanceOverlay: true)

// Slow animations for testing
timeDilation = 2.0; // In main.dart

// Check device performance
flutter run --profile
```

## File Locations

- **Constants**: `lib/core/animations/animation_constants.dart`
- **Transitions**: `lib/core/animations/page_transitions.dart`
- **Widgets**: `lib/core/animations/animated_widgets.dart`
- **Lottie Setup**: `assets/animations/README.md`

---

**Pro Tip**: When in doubt, use:
```dart
.animate()
.fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
.slideY(begin: 0.1, end: 0)
```

This works for 80% of cases! 🎯
