// lib/widgets/app_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للتحكم في الاهتزاز اللمسي

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
    this.borderRadius = 20.0, // زوايا أكثر عصرية
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
    // إعداد أنيميشن الضغط (ينكمش الكرت بنسبة 2%)
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
      HapticFeedback.lightImpact(); // اهتزاز لمسي خفيف
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
              // استخدام لون الثيم أو اللون الممرر
              color: widget.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.showBorder
                  ? Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              )
                  : null,
              boxShadow: widget.showShadow
                  ? [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10), // ظل سفلي ناعم وعميق
                  spreadRadius: -5,
                ),
              ]
                  : null,
            ),
            // استخدام ClipRRect لضمان عدم خروج المحتوى عن الزوايا المنحنية
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