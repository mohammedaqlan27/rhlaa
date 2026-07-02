// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/auth_state.dart';
import '../widgets/custom_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import 'driver_home_screen.dart';
import 'passenger_home_screen.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _baseBg = Color(0xFFF1F5F9);

  Widget _loadingView(BuildContext context, {String? message}) {
    return AppScaffold(
      title: 'رحلاء',
      isLoading: true,
      body: Center(
        child: Text(message ?? 'جاري تهيئة رحلتك...', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
      ),
    );
  }

  Widget _notAuthenticatedView(BuildContext context) {
    return AppScaffold(
      title: 'مرحباً بك',
      body: Center(
        child: SingleChildScrollView(
          child: AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_rounded, size: 64, color: _logoBlue),
                const SizedBox(height: 16),
                const Text('أهلاً بك في تطبيق رحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: _logoBlue)),
                const SizedBox(height: 8),
                const Text(
                  'خطوتك الأولى لتجربة تنقل ذكية واقتصادية باليمن. الرجاء تسجيل الدخول أو إنشاء حساب جديد للبدء.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
                  text: 'ابدأ الآن / تسجيل الدخول',
                  icon: Icons.login_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
      showSettingsButton: false,
    );
  }

  Widget _rolePendingView(BuildContext context, AuthState authState) {
    return AppScaffold(
      title: 'التحقق من الحساب',
      body: Center(
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoTeal)),
              const SizedBox(height: 16),
              const Text('جاري قراءة صلاحيات وهويتك الرقمية...', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await authState.reloadProfile();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _logoBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, color: _logoBlue, size: 18),
                label: const Text('تحديث البيانات', style: TextStyle(fontFamily: 'Cairo', color: _logoBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context, String message, VoidCallback? onRetry) {
    return AppScaffold(
      title: 'تنبيه خطأ',
      body: Center(
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              const SizedBox(height: 20),
              if (onRetry != null)
                CustomButton(onPressed: onRetry, text: 'إعادة المحاولة السريعة', icon: Icons.refresh_rounded, backgroundColor: _logoTeal),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettingsSheet(BuildContext context, User? firebaseUser, AuthState authState) async {
    final String name = (firebaseUser?.displayName ?? authState.displayName)?.toString() ?? 'مستكشف رحلة';
    final String email = (firebaseUser?.email ?? authState.email)?.toString() ?? 'لا يوجد بريد مرتبط';
    final String phone = (firebaseUser?.phoneNumber ?? authState.mobileNumber)?.toString() ?? '';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _baseBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),

              // كارت الحساب الشخصي الغائر بنعومة داخل الـ Sheet
              AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _logoBlue.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0] : 'R',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _logoBlue),
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(email, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                ),
              ),

              if (phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_iphone_rounded, size: 16, color: _logoTeal),
                      const SizedBox(width: 8),
                      Text(phone, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              CustomButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                },
                text: 'إعدادات الحساب والملف الشخصي',
                icon: Icons.manage_accounts_rounded,
                backgroundColor: _logoBlue,
              ),
              const SizedBox(height: 12),

              CustomButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (dctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                      content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من نظام رحلة حالياً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                        TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('خروج', style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    Navigator.pop(ctx);
                    try {
                      final dynamic maybeSignOut = authState.signOut;
                      if (maybeSignOut is Function) {
                        await maybeSignOut();
                      } else {
                        await FirebaseAuth.instance.signOut();
                      }
                    } catch (_) {
                      try {
                        await FirebaseAuth.instance.signOut();
                      } catch (_) {}
                    }

                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                            (route) => false,
                      );
                    }
                  }
                },
                text: 'تسجيل خروج من الحساب',
                icon: Icons.logout_rounded,
                backgroundColor: Colors.redAccent.withOpacity(0.9),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        try {
          if (authState.isLoading && authState.firebaseUser == null) {
            return _loadingView(context);
          }

          final User? firebaseUser = authState.firebaseUser;
          if (firebaseUser == null) {
            return _notAuthenticatedView(context);
          }

          final role = (authState.userType ?? authState.userRole ?? '').toString().trim().toLowerCase();

          if (role.isEmpty) {
            return _rolePendingView(context, authState);
          }

          final actions = <Widget>[
            IconButton(
              tooltip: 'الإعدادات الحسابية',
              icon: const Icon(Icons.account_circle_rounded, color: _logoBlue, size: 26),
              onPressed: () => _showSettingsSheet(context, firebaseUser, authState),
            ),
          ];

          if (role.contains('driver') || role.contains('سائق')) {
            return AppScaffold(
              title: 'كابتن الرحلة',
              actions: actions,
              body: const DriverHomeScreen(),
            );
          } else {
            return AppScaffold(
              title: 'رحلة تنقل للركاب',
              actions: actions,
              body: const PassengerHomeScreen(),
            );
          }
        } catch (e, st) {
          debugPrint('HomeScreen build error: $e\n$st');
          return _errorView(context, 'عذراً، حدث خطأ غير متوقع أثناء معالجة الجلسة.', () {
            authState.reloadProfile();
          });
        }
      },
    );
  }
}