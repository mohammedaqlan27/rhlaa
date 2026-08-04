// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomButton extends StatefulWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? textColor;
  final double borderRadius;
  final double width;
  final double height;
  final bool isLoading;
  final IconData? icon;
  final bool compact;
  final Border? border; // إضافة دعم الإطار (Outline)
  final double? fontSize; // تخصيص حجم الخط
  final String? semanticsLabel; // للوصول الشامل (Accessibility)

  const CustomButton({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.backgroundColor,
    this.gradient,
    this.textColor,
    this.borderRadius = 16.0,
    this.width = double.infinity,
    double? height,
    this.isLoading = false,
    this.icon,
    this.compact = false,
    this.border,
    this.fontSize,
    this.semanticsLabel,
  })  : height = height ?? (compact ? 46.0 : 56.0),
        assert(text != null || child != null, 'Either text or child must be provided');

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.backgroundColor ?? const Color(0xFF1E70B8);
    final Color onPrimaryColor = widget.textColor ?? Colors.white;
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    final Gradient defaultGradient = widget.gradient ??
        LinearGradient(
          colors: [primaryColor, primaryColor.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return Semantics(
      label: widget.semanticsLabel ?? widget.text,
      button: true,
      enabled: !isDisabled,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.border, // تطبيق الإطار إن وجد
              gradient: isDisabled || widget.border != null ? null : defaultGradient,
              color: isDisabled
                  ? primaryColor.withOpacity(0.4)
                  : (widget.border != null ? Colors.transparent : (widget.gradient == null ? primaryColor : null)),
              boxShadow: isDisabled || widget.border != null
                  ? null
                  : [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  // الظل يتغير بناءً على حالة الضغط (عبر الأنيميشن)
                  blurRadius: _controller.isAnimating || _controller.value > 0 ? 4 : 12,
                  offset: _controller.isAnimating || _controller.value > 0
                      ? const Offset(0, 2)
                      : const Offset(0, 6),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? _buildLoadingIndicator(onPrimaryColor)
                  : _buildContent(onPrimaryColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(Color color) {
    return SizedBox(
      width: widget.compact ? 20 : 24,
      height: widget.compact ? 20 : 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildContent(Color color) {
    final Widget label = widget.child ??
        Text(
          widget.text!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: color,
            fontSize: widget.fontSize ?? (widget.compact ? 14 : 16),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        );

    if (widget.icon == null) return label;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: widget.compact ? 20 : 24, color: color),
        const SizedBox(width: 10),
        Flexible(child: label),
      ],
    );
  }
}