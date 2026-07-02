import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/trip.dart';

// استيراد الشاشات
import 'auth_screen.dart';
import 'home_screen.dart';
import 'passenger_home_screen.dart' hide Trip;
import 'driver_home_screen.dart';
import 'loading_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // مراقبة حالة تسجيل الدخول من Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. إذا كان التطبيق يتصل بـ Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // 2. إذا كان المستخدم مسجل الدخول
        if (snapshot.hasData && snapshot.data != null) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);

          // جلب بيانات المستخدم من Firestore فوراً إذا لم تكن موجودة
          if (userProvider.currentUser == null) {
            userProvider.fetchUserById(snapshot.data!.uid);
          }

          // توجيه المستخدم للشاشة الرئيسية العامة (التي تفرز بين السائق والراكب)
          return const HomeScreen();

          // ملاحظة: إذا أردت العودة لشاشة الاختبار، استبدل السطر أعلاه بـ:
          // return const TestAllScreens();
        }

        // 3. إذا لم يكن مسجلاً، اذهب لشاشة الدخول
        return const AuthScreen();
      },
    );
  }
}

// شاشة الاختبار (اختيارية، يمكنك الوصول إليها من القائمة الجانبية لاحقاً)
class TestAllScreens extends StatelessWidget {
  const TestAllScreens({super.key});

  @override
  Widget build(BuildContext context) {
    // ... (كود شاشة الاختبار الذي أرسلته يبقى كما هو هنا) ...
    return Scaffold(
      appBar: AppBar(title: const Text("قائمة الاختبار")),
      body: const Center(child: Text("شاشة الاختبار جاهزة")),
    );
  }
}