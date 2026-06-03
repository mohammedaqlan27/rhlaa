import 'package:flutter/material.dart';
import '../utils/constants.dart';// استيراد الثوابت لاستخدام الألوان

class CustomLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool isFullScreen;
  final String? message;

  const CustomLoadingIndicator({
    Key? key,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    this.color,
    this.isFullScreen = false,
    this.message,
  }) : super(key: key);

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
              color ?? AppColors.primaryPurple, // استخدام اللون البنفسجي من الثوابت
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(
              fontFamily: AppFonts.arabicFont,
              fontSize: 14,
              color: AppColors.darkPurple,
            ),
          ),
        ],
      ],
    );

    // إذا كان المطلوب عرض المؤشر بملء الشاشة
    if (isFullScreen) {
      return Scaffold(
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
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // منع إغلاق النافذة بالرجوع
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