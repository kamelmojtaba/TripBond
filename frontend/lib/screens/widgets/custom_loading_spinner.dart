import 'package:flutter/material.dart';

class CustomLoadingSpinner extends StatefulWidget {
  final double fontSize;
  final double dotSize;
  final Color textColor;
  final List<Color> dotColors;

  const CustomLoadingSpinner({
    super.key,
    this.fontSize = 20,
    this.dotSize = 12,
    this.textColor = const Color(0xFF4675B8),
    this.dotColors = const [
      Color(0xFF4675B8), // Darker blue
      Color(0xFF7BA3D1), // Medium blue
      Color(0xFFB8D4EA), // Lighter blue
    ],
  });

  @override
  State<CustomLoadingSpinner> createState() => _CustomLoadingSpinnerState();
}

class _CustomLoadingSpinnerState extends State<CustomLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Loading',
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
            color: widget.textColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                // Calculate animation delay for each dot
                final delay = index * 0.2;
                final value = (_controller.value - delay) % 1.0;

                // Scale animation: starts small, grows, then shrinks
                double scale;
                if (value < 0.5) {
                  scale = 0.6 + (value * 0.8); // Scale from 0.6 to 1.0
                } else {
                  scale = 1.0 - ((value - 0.5) * 0.8); // Scale from 1.0 to 0.6
                }

                // Opacity animation for smooth effect
                double opacity;
                if (value < 0.5) {
                  opacity = 0.4 + (value * 1.2); // Fade from 0.4 to 1.0
                } else {
                  opacity = 1.0 - ((value - 0.5) * 1.2); // Fade from 1.0 to 0.4
                }
                opacity = opacity.clamp(0.4, 1.0);

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.dotSize * 0.25,
                  ),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: widget.dotSize,
                        height: widget.dotSize,
                        decoration: BoxDecoration(
                          color: widget.dotColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
