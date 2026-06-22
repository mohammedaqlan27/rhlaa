// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final double width;
  final double height;
  final bool isLoading;
  final IconData? icon;
  final bool compact;

  const CustomButton({
    Key? key,
    this.text,
    this.child,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 16.0, // حواف أكثر انسيابية وعصرية
    this.width = double.infinity,
    double? height,
    this.isLoading = false,
    this.icon,
    this.compact = false,
  })  : height = height ?? (compact ? 44.0 : 54.0),
        assert(text != null || child != null, 'Either text or child must be provided'),
        super(key: key);

  static const Color _logoBlue = Color(0xFF1E70B8);

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? _logoBlue;
    final Color fg = textColor ?? Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: onPressed == null || isLoading
              ? null
              : [
            BoxShadow(
              color: bg.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            elevation: 0, // الاعتماد على الـ BoxShadow المخصص بالأعلى لمظهر نيومورفي متناسق
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
          ),
          child: isLoading
              ? SizedBox(
            width: compact ? 18 : 22,
            height: compact ? 18 : 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
              : _buildContent(fg),
        ),
      ),
    );
  }

  Widget _buildContent(Color fg) {
    final content = child ??
        Text(
          text!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: fg,
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.bold,
          ),
        );

    if (icon == null) return content;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 18 : 22, color: fg),
        const SizedBox(width: 8),
        Flexible(child: content),
      ],
    );
  }
}