import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

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
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: _baseBg, // خلفية موحدة للتطبيق
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر التحميل داخل حاوية نيومورفية
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _baseBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                      blurRadius: 16,
                      offset: const Offset(5, 5),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 16,
                      offset: Offset(-5, -5),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_logoBlue),
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 32),

              // نص الرسالة
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

              // نص توضيحي إضافي
              const Text(
                'نعمل على ربطك بأفضل مسارات الرحلات في ثوانٍ معدودة...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 20),

              // ✅ زر إعادة المحاولة
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _logoBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final firebaseUser = userProvider.currentUser;
                  if (firebaseUser == null) {
                    // إعادة محاولة جلب المستخدم من Firebase
                    final authUser = userProvider.isAuthenticated
                        ? userProvider.currentUser
                        : null;
                    if (authUser != null) {
                      userProvider.fetchUserById(authUser.uid, context: context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يوجد مستخدم مسجل دخول حالياً'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    // إذا كان المستخدم موجود بالفعل، نقوم بتحديث بياناته
                    userProvider.refreshUser();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
