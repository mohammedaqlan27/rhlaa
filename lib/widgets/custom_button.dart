// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';

/// زر مخصص موحّد للاستخدام في التطبيق.
/// يدعم نصًا أو ويدجت مخصصة كـ child، أيقونة، حالة تحميل، وألوان قابلة للتخصيص.
class CustomButton extends StatelessWidget {
  /// نص الزر (يُستخدم إذا لم يُمرر child).
  final String? text;

  /// ويدجت مخصصة داخل الزر (تأخذ الأولوية على النص).
  final Widget? child;

  /// دالة الاستدعاء عند الضغط.
  final VoidCallback? onPressed;

  /// لون الخلفية للزر.
  final Color? backgroundColor;

  /// لون النص/الأيقونات داخل الزر.
  final Color? textColor;

  /// نصف قطر الحواف.
  final double borderRadius;

  /// عرض الزر. افتراضيًا يأخذ العرض الكامل.
  final double width;

  /// ارتفاع الزر.
  final double height;

  /// حالة تحميل: عند true يعرض مؤشر تحميل ويعطل الزر.
  final bool isLoading;

  /// أيقونة اختيارية تظهر قبل النص/المحتوى.
  final IconData? icon;

  /// وضع مدمج (compact) يجعل الزر أصغر للاستخدام داخل بطاقات أو صفوف.
  final bool compact;

  const CustomButton({
    Key? key,
    this.text,
    this.child,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 12.0,
    this.width = double.infinity,
    double? height,
    this.isLoading = false,
    this.icon,
    this.compact = false,
  })  : height = height ?? (compact ? 42.0 : 55.0),
        assert(text != null || child != null, 'Either text or child must be provided'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg = backgroundColor ?? theme.colorScheme.primary;
    final Color fg = textColor ?? theme.colorScheme.onPrimary;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 2,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        ),
        child: isLoading
            ? SizedBox(
          width: compact ? 18 : 24,
          height: compact ? 18 : 24,
          child: CircularProgressIndicator(
            strokeWidth: compact ? 2.0 : 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(fg),
          ),
        )
            : _buildContent(fg),
      ),
    );
  }

  Widget _buildContent(Color fg) {
    final content = child ??
        Text(
          text!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        );

    if (icon == null) return content;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 16 : 20, color: fg),
        SizedBox(width: compact ? 8 : 10),
        Flexible(child: content),
      ],
    );
  }
}
