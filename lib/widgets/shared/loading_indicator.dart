import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color ?? AppColors.primary,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              fontFamily: AppFonts.arabic,
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );

    if (isFullScreen) {
      return Scaffold(
        backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
        body: Center(
          child: indicator,
        ),
      );
    }

    return Center(child: indicator);
  }

  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: CustomLoadingIndicator(
          isFullScreen: false,
          message: message,
        ),
      ),
    );
  }

  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}