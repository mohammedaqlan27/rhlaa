// lib/screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import '../state/auth_state.dart';
import 'auth_screen.dart';
import 'loading_screen.dart';
import 'onboarding_screen.dart';
import 'driver/driver_home_screen.dart';
import 'passenger/passenger_home_screen.dart';
import 'agency/agency_home_screen.dart';
import 'gov_dashboard_screen.dart'; // 👈 واجهة المكتب الحكومي
import 'admin/admin_dashboard_screen.dart'; // 👈 واجهة مدير النظام الرئيسي

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _isFirstTime;
  User? _firebaseUser;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
    _listenAuthChanges();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFirstTime = prefs.getBool('is_first_time') ?? true;
    });
  }

  void _listenAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _firebaseUser = user;
      });

      if (user != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        // جلب بيانات المستخدم من Firestore بناءً على الـ uid حصراً
        userProvider.fetchUserById(user.uid, context: context).then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final userProvider = Provider.of<UserProvider>(context);

    // 1. إذا لم نعرف بعد هل هي المرة الأولى
    if (_isFirstTime == null) {
      return const LoadingScreen();
    }

    // 2. إذا كانت المرة الأولى
    if (_isFirstTime == true) {
      return const OnboardingScreen();
    }

    // 3. فحص حالة تسجيل الدخول
    if (_firebaseUser != null) {
      final appUser = userProvider.currentUser;

      // إذا كانت بيانات المستخدم ما زالت قيد الجلب من الـ Firestore وعرض الـ Loader مفضل
      if (userProvider.isLoading && appUser == null) {
        return const LoadingScreen(message: 'جاري تحميل بيانات الحساب...');
      }

      // استخراج userType حصراً مع الأخذ بعين الاعتبار البريد الإلكتروني للاحتياط
      final String userType = (appUser?.userType ?? authState.userType ?? '').toString().toLowerCase();
      final String userEmail = _firebaseUser?.email ?? '';

      // 🛡️ التحقق من مدير النظام الرئيسي
      if (userEmail == 'admin1@test.local' || userEmail == 'admin@test.local' || userType == 'admin' || userType == 'super_admin') {
        return const AdminDashboardScreen();
      }
      // 🚌 التحقق من وكالة السفريات
      else if (userType == 'agency' || userEmail == 'agency1@test.local') {
        return const AgencyHomeScreen();
      }
      // 🏛️ التحقق من المكتب الحكومي
      else if (userType == 'government' || userType == 'gov' || userEmail == 'gov1@test.local') {
        return const GovernmentDashboardScreen();
      }
      // 🚖 التحقق من السائق
      else if (userType == 'driver' || userEmail == 'driver1@test.local') {
        return const DriverHomeScreen();
      }
      // 👤 التحقق من الراكب أو في حال كان الحقل فارغاً كافتراضي
      else if (userType == 'passenger' || userType.isEmpty) {
        // فحص دقيق لدعم التوجيه السليم في حال تم جلب البيانات ولكن الـ userType مختلف صراحة
        if (appUser != null) {
          if (appUser.userType == 'admin') return const AdminDashboardScreen();
          if (appUser.userType == 'agency') return const AgencyHomeScreen();
          if (appUser.userType == 'government') return const GovernmentDashboardScreen();
          if (appUser.userType == 'driver') return const DriverHomeScreen();
        }

        return const PassengerHomeScreen();
      }
      // ⏳ حالة احتياطية إذا لم يتطابق أي شرط
      else {
        return const LoadingScreen(message: 'جاري تحديد وجهة الحساب...');
      }
    }

    // 4. إذا لم يكن هناك مستخدم مسجل دخول
    return const AuthScreen();
  }
}