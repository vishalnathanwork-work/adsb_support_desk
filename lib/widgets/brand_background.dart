import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Wraps any screen with your brand background image.
/// Falls back to a soft gradient if the image is missing.
class BrandBackground extends StatelessWidget {
  final Widget child;
  final bool darken;

  const BrandBackground({
    super.key,
    required this.child,
    this.darken = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
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
        ),
        if (darken)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}