// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import 'edit_profile_screen.dart';
import 'my_bookings_screen.dart';
import 'driver_trips_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // لوحة الألوان الاحترافية
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  Future<AppUser?> _fetchUserData(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromDocument(doc);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return _buildNotLoggedInView(context);
    }

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        title: const Text('الملف الشخصي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<AppUser?>(
        future: _fetchUserData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryBlue));
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorView(context);
          }

          final user = snapshot.data!;
          final createdAt = user.createdAt != null
              ? DateFormat('yyyy-MM-dd').format(user.createdAt!.toDate())
              : 'غير متوفر';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(context, user),
                const SizedBox(height: 20),
                _buildStatsRow(user),
                const SizedBox(height: 20),
                _buildMenuSection(context, user, createdAt),
                const SizedBox(height: 30),
                _buildLogoutButton(context),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // الرأس (الصورة والاسم) بتصميم حديث
  Widget _buildHeader(BuildContext context, AppUser user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 40, top: 10),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                      ? NetworkImage(user.profilePictureUrl!)
                      : null,
                  child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                      ? const Icon(Icons.person, size: 60, color: _primaryBlue)
                      : null,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: _accentTeal, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.nickname ?? 'مستخدم رحلاء',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            user.userType == 'Driver' ? 'كابتن معتمد' : 'مسافر هلا',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  // شريط الإحصائيات
  Widget _buildStatsRow(AppUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatItem('التقييم', user.averageRating?.toStringAsFixed(1) ?? '0.0', Icons.star, Colors.amber),
          const SizedBox(width: 12),
          _buildStatItem('الرحلات', '12', Icons.directions_car, _primaryBlue), // رقم افتراضي أو من الداتابيز
          const SizedBox(width: 12),
          _buildStatItem('المحفظة', '0', Icons.account_balance_wallet, _accentTeal),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // قائمة الخيارات والمعلومات
  Widget _buildMenuSection(BuildContext context, AppUser user, String createdAt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المعلومات الشخصية',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark)),
          const SizedBox(height: 10),
          _buildMenuCard([
            _buildMenuTile(Icons.email_outlined, 'البريد الإلكتروني', user.email ?? 'غير مسجل'),
            _buildMenuTile(Icons.phone_android_outlined, 'رقم الهاتف', user.mobileNumber ?? 'غير مسجل'),
            _buildMenuTile(Icons.calendar_month_outlined, 'تاريخ الانضمام', createdAt),
          ]),
          const SizedBox(height: 20),
          const Text('إدارة الحساب',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark)),
          const SizedBox(height: 10),
          _buildMenuCard([
            _buildMenuTile(
              user.userType == 'Driver' ? Icons.local_taxi : Icons.local_mall,
              user.userType == 'Driver' ? 'رحلاتي ككابتن' : 'حجوزاتي السابقة',
              'عرض السجل',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => user.userType == 'Driver' ? const DriverTripsScreen() : const MyBookingsScreen()
              )),
            ),
            _buildMenuTile(Icons.settings_outlined, 'إعدادات التطبيق', 'اللغة والتنبيهات'),
          ]),
        ],
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: _primaryBlue, size: 22),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey) : null,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل أنت متأكد أنك تريد مغادرة التطبيق؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('خروج', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // واجهات الحالات الخاصة
  Widget _buildNotLoggedInView(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle_outlined, size: 80, color: _primaryBlue),
            const SizedBox(height: 20),
            const Text('سجل دخولك لعرض ملفك الشخصي', style: TextStyle(fontFamily: 'Cairo', fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
              child: const Text('العودة للرئيسية', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return const Center(child: Text('حدث خطأ في تحميل البيانات', style: TextStyle(fontFamily: 'Cairo')));
  }
}