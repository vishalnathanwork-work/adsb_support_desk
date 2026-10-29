import 'package:flutter/material.dart';

/// Wraps any widget with the app-wide background image.
/// Use this as a Scaffold body wrapper, OR rely on AppTheme's
/// global background (see _AppBackgroundWrapper below).
class AppBackground extends StatelessWidget {
  final Widget child;
  final double overlayOpacity;   // 0.0 = no dim, 1.0 = fully dark

  const AppBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. The image itself
        Image.asset(
          'assets/images/new_background.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0x6788B8FF),
          ),
        ),

        // 2. Optional overlay for readability
        if (overlayOpacity > 0)
          Container(
            color: Colors.white.withOpacity(overlayOpacity),
          ),

        // 3. Your actual screen content
        child,
      ],
    );
  }
}