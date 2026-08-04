// lib/screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'loading_screen.dart';
import 'onboarding_screen.dart'; // سننشئ هذا الملف

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_first_time') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFirstTime(),
      builder: (context, firstTimeSnapshot) {
        if (firstTimeSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // 1. إذا كانت المرة الأولى، اعرض شاشات الترحيب
        if (firstTimeSnapshot.data == true) {
          return const OnboardingScreen();
        }

        // 2. فحص حالة تسجيل الدخول
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (authSnapshot.hasData && authSnapshot.data != null) {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              if (userProvider.currentUser == null) {
                userProvider.fetchUserById(authSnapshot.data!.uid);
              }
              return const HomeScreen();
            }

            return const AuthScreen();
          },
        );
      },
    );
  }
}