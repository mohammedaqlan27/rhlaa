// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '/widgets/shared/stat_card.dart';
import '/widgets/admin/admin_header.dart';
import '/widgets/shared/agencies_table.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestore = FirebaseFirestore.instance;
  int _selectedPageIndex = 0;

  void _showSnackBar(String message, {Color color = AppColors.success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: AppFonts.arabic)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // دوال معالجة قبول أو رفض الوكالات
  Future<void> _handleAcceptAgency(String docId, String agencyName) async {
    try {
      await _firestore.collection('agencies').doc(docId).update({'isActive': true});
      _showSnackBar('تم قبول وتفعيل مكتب "$agencyName" بنجاح');
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء قبول المكتب: $e', color: AppColors.error);
    }
  }

  Future<void> _handleRejectAgency(String docId, String agencyName) async {
    try {
      await _firestore.collection('agencies').doc(docId).delete();
      _showSnackBar('تم رفض وحذف طلب مكتب "$agencyName"', color: AppColors.error);
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء رفض المكتب: $e', color: AppColors.error);
    }
  }

  // دالة الإيقاف الطارئ للرحلة بواسطة الأدمن العام
  Future<void> _handleEmergencyStopTrip(String tripId, String origin, String destination) async {
    // إظهار نافذة تأكيد أولاً
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ تنبيه: إيقاف طارئ للرحلة', style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, color: AppColors.error)),
          content: Text('هل أنت متأكد من رغبتك في إيقاف وإلغاء الرحلة من ($origin) إلى ($destination) طارئاً؟ سيتم إشعار الوكالة والمسافرين فوراً.', style: const TextStyle(fontFamily: AppFonts.arabic)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع', style: TextStyle(fontFamily: AppFonts.arabic, color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد الإيقاف', style: TextStyle(fontFamily: AppFonts.arabic, color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('trips').doc(tripId).update({
          'status': 'cancelled',
          'isEmergencyStopped': true,
          'stoppedByAdminAt': FieldValue.serverTimestamp(),
        });
        _showSnackBar('تم إيقاف الرحلة بنجاح وإرسال تنبيهات الطوارئ', color: AppColors.error);
      } catch (e) {
        _showSnackBar('حدث خطأ أثناء تنفيذ الإيقاف الطارئ: $e', color: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: Row(
          children: [
            // 1. القائمة الجانبية (Sidebar)
            _buildSidebar(context, isDark),

            // 2. المحتوى الرئيسي
            Expanded(
              child: Column(
                children: [
                  // شريط العنوان العلوي
                  AdminHeader(
                    title: _getPageTitle(),
                    unreadNotificationsCount: 3,
                    onNotificationTap: () => _showSnackBar('لا توجد إشعارات جديدة حالياً'),
                    onProfileTap: () => _showSnackBar('إعدادات حساب المدير'),
                  ),

                  // محتوى الصفحة الحالية
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildPageContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedPageIndex) {
      case 1: return 'إدارة كافة الوكالات';
      case 2: return 'طلبات الانضمام المعلقة';
      case 3: return 'مراقبة الرحلات النشطة';
      case 0:
      default:
        return 'نظرة عامة وإحصائيات المنظومة';
    }
  }

  Widget _buildPageContent() {
    switch (_selectedPageIndex) {
      case 1:
        return AgenciesTable(
          isPendingOnly: false,
          onAccept: _handleAcceptAgency,
          onReject: _handleRejectAgency,
        );
      case 2:
        return AgenciesTable(
          isPendingOnly: true,
          onAccept: _handleAcceptAgency,
          onReject: _handleRejectAgency,
        );
      case 3:
        return _buildActiveTripsMonitoringView();
      case 0:
      default:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صف البطاقات الإحصائية باستخدام StatCard المشترك المتقدم
              Row(
                children: [
                  const Expanded(
                    child: StatCard(
                      title: 'إجمالي الوكالات المسجلة',
                      value: '12 مكتب',
                      icon: Icons.business_center_rounded,
                      percentageChange: '+12%',
                      trend: TrendDirection.up,
                      subtitle: 'مقارنة بالشهر الماضي',
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: StatCard(
                      title: 'الرحلات الجارية حالياً',
                      value: '28 رحلة',
                      icon: Icons.route_rounded,
                      percentageChange: '-4%',
                      trend: TrendDirection.down,
                      subtitle: 'تحديث مباشر',
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: StatCard(
                      title: 'الطلبات المعلقة',
                      value: '3 طلبات',
                      icon: Icons.pending_actions_rounded,
                      trend: TrendDirection.neutral,
                      subtitle: 'بانتظار المراجعة',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // قسم أحدث طلبات الانضمام
              Text(
                'أحدث طلبات انضمام الوكالات والمكاتب',
                style: TextStyle(
                  fontFamily: AppFonts.arabic,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode(context) ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 350,
                child: AgenciesTable(
                  isPendingOnly: true,
                  onAccept: _handleAcceptAgency,
                  onReject: _handleRejectAgency,
                ),
              ),
            ],
          ),
        );
    }
  }

  bool isDarkMode(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  // --- شاشة مراقبة الرحلات النشطة الشاملة للأدمن العام مع الإيقاف الطارئ ---
  Widget _buildActiveTripsMonitoringView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'مراقبة خطوط السير والرحلات الجارية لحظياً',
              style: TextStyle(
                fontFamily: AppFonts.arabic,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() {}), // إعادة تحديث البيانات
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('تحديث مباشر', style: TextStyle(fontFamily: AppFonts.arabic)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('trips').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.route_outlined, size: 60, color: AppColors.gray400),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد رحلات نشطة مسجلة في النظام حالياً',
                        style: TextStyle(fontFamily: AppFonts.arabic, color: AppColors.gray500, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              final tripsDocs = snapshot.data!.docs;

              return ListView.separated(
                itemCount: tripsDocs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final tripData = tripsDocs[index].data() as Map<String, dynamic>;
                  final tripId = tripsDocs[index].id;
                  return _buildActiveTripCard(tripId, tripData, isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // بطاقة تفاصيل الرحلة النشطة للأدمن مع خيار الإيقاف الطارئ
  Widget _buildActiveTripCard(String tripId, Map<String, dynamic> data, bool isDark) {
    final origin = data['origin'] ?? 'غير محدد';
    final destination = data['destination'] ?? 'غير محدد';
    final agencyName = data['agencyName'] ?? data['agencyId'] ?? 'مكتب سفريات';
    final price = data['price']?.toString() ?? '0';
    final availableSeats = data['availableSeats']?.toString() ?? '-';
    final status = data['status'] ?? 'active';
    final isStopped = status == 'cancelled' || data['isEmergencyStopped'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStopped ? AppColors.error.withValues(alpha: 0.5) : (isDark ? AppColors.gray100 : AppColors.gray200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isStopped ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isStopped ? Icons.warning_rounded : Icons.directions_bus_rounded,
              color: isStopped ? AppColors.error : AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$origin  ←  $destination',
                      style: TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isStopped ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isStopped ? 'متوقفة طارئاً' : 'نشطة الآن',
                        style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isStopped ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'الوكالة المشغلة: $agencyName',
                  style: TextStyle(
                    fontFamily: AppFonts.arabic,
                    fontSize: 13,
                    color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_seat_rounded, size: 14, color: AppColors.gray500),
                    const SizedBox(width: 4),
                    Text(
                      'المقاعد المتاحة: $availableSeats',
                      style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 12, color: AppColors.gray500),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.attach_money_rounded, size: 14, color: AppColors.gray500),
                    Text(
                      'السعر: $price ر.ي',
                      style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 12, color: AppColors.gray500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // زر الإيقاف الطارئ
          if (!isStopped)
            IconButton(
              icon: const Icon(Icons.stop_circle_rounded, color: AppColors.error),
              tooltip: 'إيقاف طارئ للرحلة',
              onPressed: () => _handleEmergencyStopTrip(tripId, origin, destination),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.visibility_rounded, color: AppColors.primary),
            tooltip: 'معاينة تفاصيل الرحلة',
            onPressed: () {
              _showSnackBar('جاري فتح تفاصيل الرحلة رقم: ${tripId.substring(0, 6)}');
            },
          ),
        ],
      ),
    );
  }

  // القائمة الجانبية للأدمن
  Widget _buildSidebar(BuildContext context, bool isDark) {
    return Container(
      width: 270,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppColors.gray100 : AppColors.gray200)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 42),
                const SizedBox(height: 8),
                Text(
                  'رحلاء - لوحة الإدارة',
                  style: TextStyle(
                    fontFamily: AppFonts.arabic,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _buildSidebarItem(Icons.dashboard_outlined, 'الإحصائيات العامة', 0, isDark),
          _buildSidebarItem(Icons.business_outlined, 'إدارة الوكالات', 1, isDark),
          _buildSidebarItem(Icons.pending_actions_outlined, 'الطلبات المعلقة', 2, isDark),
          _buildSidebarItem(Icons.route_outlined, 'مراقبة الرحلات', 3, isDark),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(fontFamily: AppFonts.arabic, color: AppColors.error, fontSize: 14),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, int index, bool isDark) {
    final isSelected = _selectedPageIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : (isDark ? AppColors.gray400 : AppColors.textSecondary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppFonts.arabic,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : (isDark ? Colors.white : AppColors.textPrimary),
        ),
      ),
      tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
      onTap: () => setState(() => _selectedPageIndex = index),
    );
  }
}