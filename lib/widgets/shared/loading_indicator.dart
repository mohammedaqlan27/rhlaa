// lib/widgets/loading_indicator.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
// تم إبقاء الاستيراد كما هو لتجنب أي تعارض
import '../../utils/constants.dart' hide AppColors, AppFonts;

class CustomLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool isFullScreen;
  final String? message;

  const CustomLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    this.color,
    this.isFullScreen = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    // التصميم الأساسي للمؤشر
    Widget indicator = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(
              // تم التعديل هنا: استخدام primary بدلاً من primaryBlue
              color ?? AppColors.primary,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(
              // استخدام المتغير الصحيح للخط من ملف app_colors.dart
              fontFamily: AppFonts.arabic,
              fontSize: 14,
              // تم التعديل هنا: استخدام textPrimary بدلاً من textDark
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );

    // إذا كان المطلوب عرض المؤشر بملء الشاشة
    if (isFullScreen) {
      return Scaffold(
        // استخدام لون خلفية شفاف قليلاً
        backgroundColor: Colors.white.withOpacity(0.8),
        body: Center(
          child: indicator,
        ),
      );
    }

    // العرض العادي (داخل حاوية)
    return Center(child: indicator);
  }

  // دالة مساعدة لإظهار التحميل كـ Dialog (نافذة منبثقة)
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false, // منع إغلاق النافذة بالرجوع للخلف أثناء التحميل
        child: CustomLoadingIndicator(
          isFullScreen: false,
          message: message,
        ),
      ),
    );
  }

  // دالة لإغلاق نافذة التحميل
  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}