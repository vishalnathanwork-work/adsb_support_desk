import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Wraps any screen with the brand background image.
/// Adds a color scrim so text on top stays readable.
class BrandBackground extends StatelessWidget {
  final Widget child;
  final double overlayOpacity;

  const BrandBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.asset(
          'assets/images/background.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // Color overlay
        Container(
          color: Colors.black.withOpacity(overlayOpacity),
        ),
        // Content
        child,
      ],
    );
  }
}