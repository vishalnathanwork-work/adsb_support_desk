import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool circular;
  final bool withShadow;

  const AppLogo({
    super.key,
    this.size = 80,
    this.circular = false,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.24),
        color: Colors.white,
        boxShadow: withShadow
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.05),
          ),
        ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/logo.jpeg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: const Center(
        child: Text(
          'LOGO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}