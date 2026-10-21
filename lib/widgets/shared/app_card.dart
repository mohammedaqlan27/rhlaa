import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final bool showShadow;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20.0,
    this.onTap,
    this.color,
    this.showShadow = true,
    this.showBorder = true,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      HapticFeedback.lightImpact();
      _controller.forward().then((_) => _controller.reverse());
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => widget.onTap != null ? _controller.forward() : null,
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap != null ? _handleTap : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: widget.color ?? (isDark ? AppColors.webCardBackground : Colors.white),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.showBorder
                  ? Border.all(
                color: isDark ? AppColors.webBorder : Colors.black.withValues(alpha: 0.05),
                width: 1,
              )
                  : null,
              boxShadow: widget.showShadow
                  ? [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}