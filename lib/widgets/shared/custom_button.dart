import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

enum IconPosition { left, right }

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
  final IconPosition iconPosition;
  final bool compact;
  final Border? border;
  final double? fontSize;
  final String? semanticsLabel;
  final bool isDisabled;
  final String? tooltip;

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
    this.iconPosition = IconPosition.left,
    this.compact = false,
    this.border,
    this.fontSize,
    this.semanticsLabel,
    this.isDisabled = false,
    this.tooltip,
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isDisabled) {
      _controller.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) => _controller.reverse();
  void _handleTapCancel() => _controller.reverse();

  bool get _isDisabled => widget.isDisabled || widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final Color onPrimaryColor = widget.textColor ?? theme.colorScheme.onPrimary;

    final Gradient defaultGradient = widget.gradient ??
        LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final buttonContent = widget.isLoading
        ? _buildLoadingIndicator(onPrimaryColor)
        : _buildContent(onPrimaryColor);

    return Semantics(
      label: widget.semanticsLabel ?? widget.text,
      button: true,
      enabled: !_isDisabled,
      child: Tooltip(
        message: widget.tooltip ?? widget.text ?? '',
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: _isDisabled ? null : widget.onPressed,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: widget.border,
                gradient: _isDisabled || widget.border != null ? null : defaultGradient,
                color: _isDisabled
                    ? (isDark ? AppColors.gray700.withOpacity(0.3) : AppColors.gray300)
                    : (widget.border != null ? Colors.transparent : (widget.gradient == null ? primaryColor : null)),
                boxShadow: _isDisabled || widget.border != null
                    ? null
                    : [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: _controller.isAnimating || _controller.value > 0.0 ? 4 : 12,
                    offset: _controller.isAnimating || _controller.value > 0.0
                        ? const Offset(0, 2)
                        : const Offset(0, 5),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(child: buttonContent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.compact ? 20 : 24,
          height: widget.compact ? 20 : 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
        if (!widget.compact) ...[
          const SizedBox(width: 10),
          Text(
            'جارٍ التحميل...',
            style: TextStyle(fontFamily: AppFonts.arabic, color: color, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(Color color) {
    final Widget label = widget.child ??
        Text(
          widget.text!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.arabic,
            color: color,
            fontSize: widget.fontSize ?? (widget.compact ? 14 : 16),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        );

    if (widget.icon == null) return label;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.iconPosition == IconPosition.left) ...[
          Icon(widget.icon, size: widget.compact ? 18 : 22, color: color),
          const SizedBox(width: 8),
        ],
        Flexible(child: label),
        if (widget.iconPosition == IconPosition.right) ...[
          const SizedBox(width: 8),
          Icon(widget.icon, size: widget.compact ? 18 : 22, color: color),
        ],
      ],
    );
  }
}