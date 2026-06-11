// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/auth_state.dart';
import '../widgets/custom_button.dart';
import '../widgets/app_scaffold.dart';
import 'driver_home_screen.dart';
import 'passenger_home_screen.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';

/// شاشة رئيسية ذكية تختار الواجهة المناسبة بناءً على حالة المصادقة ودور المستخدم.
/// تستخدم AppScaffold الموحد وتعرض ورقة إعدادات (Bottom Sheet) تحتوي على
/// اسم المستخدم، البريد، رقم الهاتف، وروابط سريعة لتعديل الملف وتسجيل الخروج.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _loadingView(BuildContext context, {String? message}) {
    return AppScaffold(
      title: 'Rhlaa',
      isLoading: true,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.shrink(), // AppScaffold يعرض LoadingIndicator عند isLoading=true
            const SizedBox(height: 12),
            Text(message ?? 'جاري التحميل...', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _notAuthenticatedView(BuildContext context) {
    return AppScaffold(
      title: 'مرحباً',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('أهلاً بك في Rhlaa', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'الرجاء تسجيل الدخول أو إنشاء حساب للمتابعة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              CustomButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
                text: 'تسجيل الدخول / إنشاء حساب',
                icon: Icons.login,
              ),
            ],
          ),
        ),
      ),
      showSettingsButton: false,
    );
  }

  Widget _rolePendingView(BuildContext context, AuthState authState) {
    return AppScaffold(
      title: 'جارٍ التحميل',
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('جاري تحميل بيانات الحساب...'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await authState.reloadProfile();
                if (!authState.isLoading && (authState.userType ?? authState.userRole ?? '').toString().trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لم يتم العثور على دور المستخدم بعد. حاول تسجيل الخروج ثم الدخول مجدداً.')),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context, String message, VoidCallback? onRetry) {
    return AppScaffold(
      title: 'حدث خطأ',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              if (onRetry != null)
                CustomButton(
                  onPressed: onRetry,
                  text: 'حاول مرة أخرى',
                  icon: Icons.refresh,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettingsSheet(BuildContext context, User? firebaseUser, AuthState authState) async {
    // احصل على القيم كسلاسل نصية مع حماية من null وأنواع غير متوقعة
    final String name = (firebaseUser?.displayName ?? authState.displayName)?.toString() ?? 'مستخدم';
    final String email = (firebaseUser?.email ?? authState.email)?.toString() ?? 'غير متوفر';
    final String phone = (firebaseUser?.phoneNumber ?? authState.mobileNumber)?.toString() ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    name.isNotEmpty ? name[0] : 'U',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                title: Text(name, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(email),
              ),
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, size: 18),
                      const SizedBox(width: 8),
                      Text(phone),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    CustomButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(ctx, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                      },
                      text: 'تعديل الملف الشخصي',
                      icon: Icons.edit,
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      onPressed: () async {
                        // تأكيد الخروج
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: const Text('تأكيد تسجيل الخروج'),
                            content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('إلغاء')),
                              TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('تسجيل الخروج')),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          Navigator.pop(ctx); // أغلق الـ sheet
                          // حاول استخدام AuthState لتسجيل الخروج أولاً، وإلا استخدم FirebaseAuth مباشرة
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

                          // بعد الخروج، أعد التوجيه إلى شاشة المصادقة وأزل التاريخ
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                                  (route) => false,
                            );
                          }
                        }
                      },
                      text: 'تسجيل الخروج',
                      icon: Icons.logout,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      textColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
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
          // حالة التحميل العامة
          if (authState.isLoading && authState.firebaseUser == null) {
            return _loadingView(context);
          }

          // إذا لم يكن هناك مستخدم مسجل، نعرض واجهة المصادقة
          final User? firebaseUser = authState.firebaseUser;
          if (firebaseUser == null) {
            return _notAuthenticatedView(context);
          }

          // استخرج الدور/النوع من AuthState مع حماية من القيم الفارغة
          final rawRole = (authState.userType ?? authState.userRole ?? '').toString().trim();

          if (rawRole.isEmpty) {
            // دور غير متوفر بعد
            return _rolePendingView(context, authState);
          }

          final role = rawRole.toLowerCase();

          // AppScaffold مع زر إعدادات مخصص (يعرض ورقة الإعدادات التي أنشأناها)
          final actions = <Widget>[
            IconButton(
              tooltip: 'الإعدادات',
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsSheet(context, firebaseUser, authState),
            ),
          ];

          // توجيه حسب الدور (دعم كلمات عربية وإنجليزية)
          if (role.contains('driver') || role.contains('سائق')) {
            return AppScaffold(
              title: 'Rhlaa',
              actions: actions,
              body: const DriverHomeScreen(),
            );
          } else {
            return AppScaffold(
              title: 'Rhlaa',
              actions: actions,
              body: const PassengerHomeScreen(),
            );
          }
        } catch (e, st) {
          debugPrint('HomeScreen build error: $e\n$st');
          return _errorView(context, 'حدث خطأ غير متوقع. الرجاء المحاولة لاحقاً.', () {
            authState.reloadProfile();
          });
        }
      },
    );
  }
}
