import 'package:flutter/material.dart';

/// شاشة تحميل بسيطة تستخدم عند انتظار البيانات أو التحقق من الحالة.
class LoadingScreen extends StatelessWidget {
  final String message;
  
  // الرسالة الافتراضية إذا لم يتم تمرير أي رسالة
  const LoadingScreen({
    super.key, 
    this.message = 'جاري التحميل... يرجى الانتظار', 
  });

  @override
  Widget build(BuildContext context) {
    // نستخدم Scaffold لضمان وجود شاشة كاملة التنسيق
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر التقدم الدائري بلون جذاب
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                strokeWidth: 4,
              ),
              const SizedBox(height: 24),
              // رسالة واضحة للمستخدم
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3913A1),
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 10),
              // نص إضافي لتأكيد العملية
              const Text(
                'قد تستغرق هذه العملية بضع ثوانٍ...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
