// lib/screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import 'home_screen.dart';
import 'auth_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState?>(context);

    // إذا لم تُحمّل حالة المصادقة بعد، نعرض مؤشر تحميل
    if (authState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final firebaseUser = authState.firebaseUser;

    // إذا لم يتم تسجيل الدخول بعد، نعرض شاشة المصادقة
    if (firebaseUser == null) {
      return const AuthScreen();
    }

    // إذا كان دور المستخدم لم يُحدد بعد، نعرض مؤشر تحميل صغير
    final userRole = authState.userType;
    if (userRole == null || userRole.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // توجيه المستخدم حسب دوره
    return const HomeScreen();
  }
}
