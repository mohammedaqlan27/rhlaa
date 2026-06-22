// lib/screens/loading_screen.dart
import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  final String message;

  const LoadingScreen({
    super.key,
    this.message = 'جاري مزامنة وتأمين البيانات... يرجى الانتظار',
  });

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _baseBg = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _baseBg, // الحفاظ على خلفية النيومورف الموحدة للتطبيق
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // حاوية نيومورفية دائرية لحماية وتحسين مظهر مؤشر التحميل
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _baseBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFCBD5E1).withOpacity(0.7), blurRadius: 16, offset: const Offset(5, 5)),
                    const BoxShadow(color: Colors.white, blurRadius: 16, offset: Offset(-5, -5)),
                  ],
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_logoBlue),
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 32),

              // نص الرسالة بخط Cairo الرسمي لـ رحلاء
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // نص توضيحي تلطيفي للمستخدم
              const Text(
                'نعمل على ربطك بأفضل مسارات الرحلات في ثوانٍ معدودة...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}