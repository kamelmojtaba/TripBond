import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'animation_constants.dart';

/// Reusable animated widgets for consistent effects across the app

/// Staggered list animation - items appear one by one
class StaggeredListAnimation extends StatelessWidget {
  final List<Widget> children;
  final Duration delay;
  final Duration itemDelay;

  const StaggeredListAnimation({
    super.key,
    required this.children,
    this.delay = Duration.zero,
    this.itemDelay = const Duration(milliseconds: 100),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        children.length,
        (index) => children[index]
            .animate(delay: delay + (itemDelay * index))
            .fadeIn(
              duration: const Duration(milliseconds: AnimationConstants.normal),
              curve: AnimationConstants.cubicEaseOut,
            )
            .slideY(
              begin: 0.1,
              end: 0,
              duration: const Duration(milliseconds: AnimationConstants.normal),
              curve: AnimationConstants.cubicEaseOut,
            ),
      ),
    );
  }
}

/// Fade in slide animation wrapper
class FadeInSlideAnimation extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset slideOffset;

  const FadeInSlideAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: AnimationConstants.normal),
    this.slideOffset = const Offset(0, 0.1),
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: AnimationConstants.cubicEaseOut)
        .slideX(
          begin: slideOffset.dx,
          end: 0,
          duration: duration,
          curve: AnimationConstants.cubicEaseOut,
        )
        .slideY(
          begin: slideOffset.dy,
          end: 0,
          duration: duration,
          curve: AnimationConstants.cubicEaseOut,
        );
  }
}

/// Scale fade animation for cards and containers
class ScaleFadeAnimation extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const ScaleFadeAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: AnimationConstants.normal),
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: AnimationConstants.cubicEaseOut)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: duration,
          curve: AnimationConstants.cubicEaseOut,
        );
  }
}

/// Shimmer effect for loading states
class ShimmerAnimation extends StatelessWidget {
  final Widget child;

  const ShimmerAnimation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child.animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: const Duration(milliseconds: 1500),
          color: Colors.white.withValues(alpha: 0.3),
        );
  }
}

/// Pulse animation for attention-grabbing elements
class PulseAnimation extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    return child.animate(onPlay: (controller) => controller.repeat()).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.05, 1.05),
          duration: duration,
          curve: Curves.easeInOut,
        );
  }
}
