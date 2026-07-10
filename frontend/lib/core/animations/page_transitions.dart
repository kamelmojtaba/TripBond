import 'package:flutter/material.dart';
import 'animation_constants.dart';

/// Smooth fade transition similar to iOS and premium apps
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: AnimationConstants.normal),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: AnimationConstants.smoothEaseOut,
              ),
              child: child,
            );
          },
        );
}

/// Smooth slide up transition (like bottom sheet)
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideUpPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: AnimationConstants.medium),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AnimationConstants.cubicEaseOut,
            );

            return SlideTransition(
              position: tween.animate(curvedAnimation),
              child: child,
            );
          },
        );
}

/// Shared axis transition - modern Material Design style
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SharedAxisPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: AnimationConstants.normal),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: AnimationConstants.cubicEaseOut,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Scale fade transition - subtle and elegant
class ScaleFadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  ScaleFadePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: AnimationConstants.normal),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: AnimationConstants.cubicEaseOut,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Helper mixin for easy navigation with transitions
mixin AnimatedNavigationMixin {
  void navigateWithFade(BuildContext context, Widget page) {
    Navigator.of(context).push(FadePageRoute(page: page));
  }

  void navigateWithSlideUp(BuildContext context, Widget page) {
    Navigator.of(context).push(SlideUpPageRoute(page: page));
  }

  void navigateWithSharedAxis(BuildContext context, Widget page) {
    Navigator.of(context).push(SharedAxisPageRoute(page: page));
  }

  void navigateWithScaleFade(BuildContext context, Widget page) {
    Navigator.of(context).push(ScaleFadePageRoute(page: page));
  }

  void replaceWithFade(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(FadePageRoute(page: page));
  }

  void replaceWithSharedAxis(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(SharedAxisPageRoute(page: page));
  }
}
