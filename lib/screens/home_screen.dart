// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/auth_state.dart';
import '../widgets/shared/custom_button.dart';
import '../widgets/shared/app_scaffold.dart';
import '../widgets/shared/app_card.dart';
import 'driver/driver_home_screen.dart';
import 'passenger/passenger_home_screen.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // لوحة الألوان الاحترافية (Design System)
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  // قائمة المحافظات اليمنية والوجهات الخارجية
  static const List<String> yemenGovernorates = [
    'صنعاء', 'عدن', 'تعز', 'حضرموت', 'إب', 'الحديدة', 'ذمار', 'مأرب',
    'شبوة', 'المهرة', 'أبين', 'لحج', 'البيضاء', 'عمران', 'صعدة', 'الجوف',
    'حجة', 'المحويت', 'ريمة', 'الضالع', 'سقطرى'
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        try {
          final User? firebaseUser = authState.firebaseUser;

          // 1. حالة التحميل
          if (authState.isLoading && firebaseUser == null) {
            return _loadingView(context);
          }

          // 2. حالة عدم تسجيل الدخول
          if (firebaseUser == null) {
            return _notAuthenticatedView(context);
          }

          // 3. تحديد الدور
          final role = (authState.userType ?? authState.userRole ?? '')
              .toString().trim().toLowerCase();

          // 4. حالة انتظار تحديد الدور
          if (role.isEmpty) {
            return _rolePendingView(context, authState);
          }

          final bool isDriver = role.contains('driver') || role.contains('سائق');

          // 5. الواجهة الرئيسية المعتمدة
          return AppScaffold(
            title: isDriver ? 'لوحة الكابتن' : 'رحلة للسفريات',
            hideBackButton: true, // حذف سهم الرجوع الزائد (اللمسة 3)
            actions: [
              _buildNotificationBell(context),
              IconButton(
                tooltip: 'القائمة الرئيسية',
                icon: const Icon(Icons.menu_open_rounded, color: _primaryBlue, size: 28),
                onPressed: () => _showGlobalMenu(context, firebaseUser, authState, isDriver),
              ),
            ],
            // اللمسة الثانية: إضافة انتقال ناعم (AnimatedSwitcher) عند التبديل بين السائق والراكب
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: isDriver
                  ? const DriverHomeScreen(key: ValueKey('DriverView'))
                  : const PassengerHomeScreen(key: ValueKey('PassengerView')),
            ),
          );
        } catch (e, st) {
          debugPrint('HomeScreen build error: $e\n$st');
          return _errorView(context, 'عذراً، حدث خطأ غير متوقع أثناء معالجة الجلسة.', () {
            FirebaseAuth.instance.currentUser?.reload();
          });
        }
      },
    );
  }

  // جرس الإشعارات التفاعلي
  Widget _buildNotificationBell(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: _primaryBlue, size: 26),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }

  // القائمة العالمية الشاملة (اللمسة الثالثة: ربط المسارات وإغلاق القائمة)
  void _showGlobalMenu(BuildContext context, User user, AuthState authState, bool isDriver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            _buildMenuHeader(user),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildMenuTile(Icons.person_outline, 'تعديل الملف الشخصي', () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  }),
                  _buildMenuTile(Icons.account_balance_wallet_outlined, 'المحفظة والرصيد', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/payment');
                  }),
                  _buildMenuTile(Icons.history_rounded, isDriver ? 'سجل رحلاتي ككابتن' : 'رحلاتي السابقة', () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/trip-history');
                  }),
                  _buildMenuTile(Icons.language_rounded, 'اللغة (العربية)', () {}),
                  const Divider(height: 32),
                  _buildMenuTile(Icons.headset_mic_outlined, 'الدعم الفني (واتساب)', () {
                    Navigator.pop(ctx);
                    _launchWhatsAppSupport(context);
                  }),
                  _buildMenuTile(Icons.info_outline, 'عن تطبيق رحلة', () {}),
                  const SizedBox(height: 20),
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuHeader(User user) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: _primaryBlue.withValues(alpha: 0.1),
            child: Text(user.displayName?[0] ?? 'U', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryBlue)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.displayName ?? 'مستكشف رحلة', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: _textDark)),
              Text(user.phoneNumber ?? user.email ?? 'لا يوجد بيانات اتصال', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Cairo')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _primaryBlue, size: 24),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  // اللمسة الأولى: تحسين فتح واتساب الدعم مع معالجة الأخطاء
  Future<void> _launchWhatsAppSupport(BuildContext context) async {
    final Uri url = Uri.parse("https://wa.me/967770000000");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تطبيق واتساب غير مثبت على جهازك', style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return CustomButton(
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
        }
      },
      text: 'تسجيل الخروج',
      icon: Icons.logout_rounded,
      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
      textColor: Colors.redAccent,
    );
  }

  Widget _loadingView(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator(color: _accentTeal)));
  }

  Widget _notAuthenticatedView(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_rounded, size: 80, color: _primaryBlue),
                const SizedBox(height: 24),
                const Text('أهلاً بك في رحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: _primaryBlue)),
                const SizedBox(height: 12),
                const Text('خطوتك الأولى لتجربة تنقل ذكية واقتصادية باليمن.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.black54)),
                const SizedBox(height: 40),
                CustomButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
                  text: 'ابدأ الآن / تسجيل الدخول',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rolePendingView(BuildContext context, AuthState authState) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _accentTeal),
            const SizedBox(height: 20),
            const Text('جاري التحقق من هويتك الرقمية...', style: TextStyle(fontFamily: 'Cairo')),
            TextButton(onPressed: () => authState.firebaseUser?.reload(), child: const Text('تحديث البيانات')),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context, String message, VoidCallback onRetry) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontFamily: 'Cairo')),
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}