import 'package:flutter/material.dart';

/// Animation timing constants for consistent feel across the app
/// Inspired by Apple's Human Interface Guidelines
class AnimationConstants {
  AnimationConstants._();

  // Durations (in milliseconds)
  static const int ultraFast = 150;
  static const int fast = 250;
  static const int normal = 350;
  static const int medium = 500;
  static const int slow = 800;

  // Curves - Using physics-based easing for natural feel
  static const cubicEaseOut = Curves.easeOutCubic;
  static const cubicEaseIn = Curves.easeInCubic;
  static const smoothEaseOut = Curves.easeOut;
  static const smoothEaseIn = Curves.easeIn;
  static const spring = Curves.elasticOut;

  // Offsets for slide animations
  static const slideUpOffset = Offset(0, 0.1);
  static const slideDownOffset = Offset(0, -0.1);
  static const slideLeftOffset = Offset(-0.1, 0);
  static const slideRightOffset = Offset(0.1, 0);
}
