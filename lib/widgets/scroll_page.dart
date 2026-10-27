import 'package:flutter/material.dart';

/// A scrollable page that adapts to keyboard, small screens, and
/// tall content. Wrap your screen body content in this to prevent
/// "Bottom overflowed" errors.
class ScrollPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final bool centerContent;

  const ScrollPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: backgroundColor,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: padding,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                    constraints.maxHeight - padding.vertical,
                  ),
                  child: centerContent
                      ? IntrinsicHeight(child: Center(child: child))
                      : child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}