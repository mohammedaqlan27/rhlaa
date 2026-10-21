// lib/screens/agency_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 1️⃣ استيراد النماذج والمكونات
import '/models/agency_transaction.dart';
import '/widgets/agency/web/web_stat_card.dart';
import '/widgets/agency/web/web_performance_chart.dart'; // مخطط الأداء الأسبوعي
import '/widgets/agency/web/agency_booking_card.dart';
import '/widgets/agency/web/agency_support_widget.dart';
import '/widgets/agency/web/agency_wallet_card.dart';
import '/widgets/agency/web/web_bookings_table.dart';
import '/widgets/agency/web/web_transactions_table.dart';
import '/widgets/agency/web/web_top_header.dart';
import '/widgets/agency/web/web_sidebar.dart';
import '/widgets/agency/web/web_trips_table.dart';

// 2️⃣ استيراد الشاشات المُراد ربطها
import 'package:rhlaa/screens/edit_trip_screen.dart'; // شاشة تعديل الرحلة
import 'package:rhlaa/screens/agency/agency_location_edit_screen.dart'; // شاشة تعيين/تعديل موقع المكتب
import 'package:rhlaa/screens/agency/agency_wallet_screen.dart'; // شاشة إدارة المحفظة تفصيلياً
import 'package:rhlaa/screens/agency/agency_bookings_management_screen.dart'; // شاشة إدارة الحجوزات

class AgencyHomeScreen extends StatefulWidget {
  const AgencyHomeScreen({super.key});

  @override
  State<AgencyHomeScreen> createState() => _AgencyHomeScreenState();
}

class _AgencyHomeScreenState extends State<AgencyHomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _agencyName;
  String? _agencyId;
  String? _agencyEmail;
  String? _agencyPhone;
  bool _isActive = true;
  double _balance = 0.0;
  int _selectedWebPageIndex = 0;

  // متغيرات البحث والتصفية
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _darkBg = Color(0xFF0F1115);
  static const Color _cardBg = Color(0xFF181B20);

  @override
  void initState() {
    super.initState();
    _loadAgencyProfile();
    _listenBalance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAgencyProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('agencies').doc(uid).get();
    final data = doc.data();
    if (data != null && mounted) {
      setState(() {
        _agencyName = data['agencyName'] ?? data['name'] ?? 'مكتب السفريات';
        _agencyEmail = data['email'] ?? _auth.currentUser?.email ?? 'غير متوفر';
        _agencyPhone = data['phone'] ?? data['phoneNumber'] ?? 'غير متوفر';
        _agencyId = uid;
        _isActive = data['isActive'] ?? true;
        _balance = ((data['walletBalance'] ?? data['balance']) as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  void _listenBalance() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _firestore.collection('agencies').doc(uid).snapshots().listen((doc) {
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _balance = ((data['walletBalance'] ?? data['balance']) as num?)?.toDouble() ?? 0.0;
          _isActive = data['isActive'] ?? _isActive;
        });
      }
    });
  }

  void _showSnack(String msg, {Color color = Colors.green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToLocationEdit() {
    if (_agencyId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgencyLocationEditScreen(agencyId: _agencyId!),
      ),
    );
  }

  void _navigateToWallet() {
    if (_agencyId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgencyWalletScreen(agencyId: _agencyId!),
      ),
    );
  }

  // 🚗 إضافة مركبة جديدة
  Future<void> _addVehicleDialog() async {
    final plateController = TextEditingController();
    final modelController = TextEditingController();
    final seatsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إضافة مركبة جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(controller: plateController, label: 'رقم اللوحة', icon: Icons.confirmation_number),
            const SizedBox(height: 12),
            _buildTextField(controller: modelController, label: 'الموديل (مثال: تويوتا هايلوكس)', icon: Icons.directions_bus),
            const SizedBox(height: 12),
            _buildTextField(controller: seatsController, label: 'عدد المقاعد', icon: Icons.event_seat, keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (_agencyId != null && plateController.text.trim().isNotEmpty) {
                await _firestore.collection('vehicles').add({
                  'agencyId': _agencyId,
                  'plateNumber': plateController.text.trim(),
                  'model': modelController.text.trim(),
                  'seats': int.tryParse(seatsController.text.trim()) ?? 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                _showSnack('تمت إضافة المركبة بنجاح');
              } else {
                _showSnack('يجب إدخال رقم اللوحة على الأقل', color: Colors.red);
              }
              Navigator.pop(ctx);
            },
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✈️ إضافة رحلة جديدة
  Future<void> _addTripDialog() async {
    final titleController = TextEditingController();
    final driverController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إضافة رحلة جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(controller: titleController, label: 'عنوان الرحلة (مثال: صنعاء - عدن)', icon: Icons.route),
            const SizedBox(height: 12),
            _buildTextField(controller: driverController, label: 'اسم أو معرف السائق', icon: Icons.person),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (_agencyId != null && titleController.text.trim().isNotEmpty) {
                await _firestore.collection('trips').add({
                  'agencyId': _agencyId,
                  'title': titleController.text.trim(),
                  'driverId': driverController.text.trim(),
                  'status': 'نشطة',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                _showSnack('تمت إضافة الرحلة بنجاح');
              } else {
                _showSnack('يجب إدخال عنوان الرحلة', color: Colors.red);
              }
              Navigator.pop(ctx);
            },
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 13),
        prefixIcon: Icon(icon, color: _accentTeal, size: 20),
        filled: true,
        fillColor: const Color(0xFF0F1115),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  // 🚗 قائمة المركبات مع دعم البحث
  Widget _buildVehiclesList({bool isDark = false}) {
    if (_agencyId == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('vehicles').where('agencyId', isEqualTo: _agencyId).snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accentTeal));
        }
        final docs = snapshot.data?.docs ?? [];

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final model = (data['model'] ?? '').toString().toLowerCase();
          final plate = (data['plateNumber'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return model.contains(q) || plate.contains(q);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(child: Text('لا توجد مركبات مطابقة للبحث', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')));
        }
        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (ctx, i) {
            final doc = filteredDocs[i];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              color: isDark ? const Color(0xFF222732) : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _accentTeal.withOpacity(0.15),
                  child: const Icon(Icons.directions_bus, color: _accentTeal),
                ),
                title: Text('${data['model'] ?? 'مركبة'} - ${data['plateNumber'] ?? ''}', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                subtitle: Text('عدد المقاعد: ${data['seats'] ?? 0}', style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontFamily: 'Cairo', fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'حذف المركبة',
                  onPressed: () async {
                    await _firestore.collection('vehicles').doc(doc.id).delete();
                    _showSnack('تم حذف المركبة بنجاح', color: Colors.orange);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✈️ قائمة الرحلات مع دعم البحث
  Widget _buildTripsList({bool isDark = false}) {
    if (_agencyId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('trips').where('agencyId', isEqualTo: _agencyId).snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accentTeal));
        }
        final docs = snapshot.data?.docs ?? [];

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] ?? '').toString().toLowerCase();
          final driver = (data['driverId'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return title.contains(q) || driver.contains(q);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(child: Text('لا توجد رحلات مطابقة', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')));
        }
        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (ctx, i) {
            final tripDoc = filteredDocs[i];
            final data = tripDoc.data() as Map<String, dynamic>;
            return Card(
              color: isDark ? const Color(0xFF222732) : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.15),
                  child: const Icon(Icons.route, color: Colors.green),
                ),
                title: Text(data['title'] ?? 'رحلة', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                subtitle: Text('السائق: ${data['driverId'] ?? 'غير محدد'} | الحالة: ${data['status'] ?? 'نشطة'}', style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontFamily: 'Cairo', fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_note, color: _accentTeal),
                  tooltip: 'تعديل بيانات الرحلة',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditTripScreen(tripId: tripDoc.id),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditTripScreen(tripId: tripDoc.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // 💰 تبويب المعاملات المالية
  Widget _buildTransactionsList({bool isDark = false}) {
    if (_agencyId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('agencyTransactions')
          .where('agencyId', isEqualTo: _agencyId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accentTeal));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text('لا توجد معاملات مالية مسجلة', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final tx = AgencyTransaction.fromDoc(docs[i]);
            final isCredit = tx.type == 'credit';
            final color = isCredit ? Colors.greenAccent : Colors.redAccent;
            final sign = isCredit ? '+' : '-';

            return Card(
              color: isDark ? const Color(0xFF222732) : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: color),
                ),
                title: Text('$sign${tx.amount} ريال', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tx.reason != null) Text('السبب: ${tx.reason}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontSize: 13)),
                    if (tx.performedBy != null) Text('بواسطة: ${tx.performedBy}', style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontFamily: 'Cairo', fontSize: 11)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 📊 تبويب تحليلات الأداء والتقارير
  Widget _buildAnalyticsView({bool isDark = true}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تحليلات الأداء الأسبوعية والشهرية', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          const SizedBox(height: 16),
          const SizedBox(
            height: 280,
            child: WebPerformanceChart(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: WebStatCard(
                  title: 'إجمالي الحجوزات الناجحة',
                  value: '124 رحلة',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: WebStatCard(
                  title: 'نسبة إشغال المقاعد',
                  value: '84%',
                  icon: Icons.event_seat,
                  color: _accentTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 👤 تبويب الملف الشخصي للمكتب (Profile)
  Widget _buildProfileView({bool isDark = true}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: isDark ? _cardBg : Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const CircleAvatar(radius: 45, backgroundColor: _accentTeal, child: Icon(Icons.business, size: 45, color: Colors.white)),
              const SizedBox(height: 16),
              Text(_agencyName ?? 'مكتب السفريات', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const SizedBox(height: 6),
              Text(_agencyEmail ?? '', style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 13)),
              const Divider(height: 32, color: Colors.white12),
              _buildProfileInfoRow(Icons.phone, 'رقم الهاتف الأساسي', _agencyPhone ?? 'غير متوفر', isDark),
              const SizedBox(height: 12),
              _buildProfileInfoRow(Icons.verified, 'حالة حساب المكتب', _isActive ? 'حساب مفعل ونشط' : 'حساب معطل', isDark),
              const SizedBox(height: 12),
              _buildProfileInfoRow(Icons.location_on, 'موقع المكتب الجغرافي', 'انقر لتحديث الإحداثيات على الخريطة', isDark, onTap: _navigateToLocationEdit),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text('تعديل الموقع الجغرافي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                onPressed: _navigateToLocationEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String title, String value, bool isDark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: _accentTeal, size: 20),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontSize: 14)),
            const Spacer(),
            Text(value, style: TextStyle(color: onTap != null ? _accentTeal : (isDark ? Colors.grey : Colors.black54), fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ⚙️ تبويب إعدادات المكتب (Settings)
  Widget _buildSettingsView({bool isDark = true}) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('إعدادات النظام والمنظومة', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('استقبال إشعارات الحجوزات الفورية', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
          subtitle: const Text('تنبيهك عبر التطبيق فور قيام مسافر بحجز مقعد جديد', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 12)),
          value: true,
          activeColor: _accentTeal,
          onChanged: (val) {
            _showSnack('تم تحديث إعدادات الإشعارات');
          },
        ),
        const Divider(color: Colors.white12),
        SwitchListTile(
          title: const Text('الوضع الداكن المتقدم', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
          subtitle: const Text('تفعيل السمة الداكنة لراحة العين أثناء العمل الليلي', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 12)),
          value: isDark,
          activeColor: _accentTeal,
          onChanged: (val) {
            _showSnack('واجهة الويب تعمل بالوضع الداكن الافتراضي');
          },
        ),
        const Divider(color: Colors.white12),
        ListTile(
          leading: const Icon(Icons.lock_reset, color: Colors.orangeAccent),
          title: const Text('تغيير كلمة المرور الخاصة بالحساب', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
          onTap: () {
            _showSnack('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني', color: _primaryBlue);
          },
        ),
        ListTile(
          leading: const Icon(Icons.help_outline, color: _accentTeal),
          title: const Text('الدعم الفني وتوثيق المنظومة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
          onTap: () {
            _showSnack('رقم الدعم الفني: 00967770000000', color: _primaryBlue);
          },
        ),
      ],
    );
  }

  // 🔔 مركز الإشعارات (Notifications)
  Widget _buildNotificationsView({bool isDark = true}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('مركز الإشعارات والتنبيهات', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        _buildNotificationCard('تم قبول وثائق المكتب بنجاح', 'أصبح حسابك الآن مفعل بالكامل وجاهز لاستقبال الحجوزات.', 'منذ ساعتين', Icons.verified, Colors.green, isDark),
        _buildNotificationCard('تحديث جديد على سياسة الرحلات', 'يرجى مراجعة الشروط والأحكام الخاصة بتسعير التذاكر المحدثة.', 'منذ يوم', Icons.info, Colors.blue, isDark),
        _buildNotificationCard('إيداع مالى في محفظتك', 'تم إضافة مبلغ 25,000 ريال إلى رصيد المحفظة بنجاح.', 'منذ 3 أيام', Icons.account_balance_wallet, Colors.amber, isDark),
      ],
    );
  }

  Widget _buildNotificationCard(String title, String body, String time, IconData icon, Color color, bool isDark) {
    return Card(
      color: isDark ? _cardBg : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(body, style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontFamily: 'Cairo', fontSize: 12)),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 10)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 850) {
            return _buildWebDashboard();
          }
          return _buildMobileDashboard();
        },
      ),
    );
  }

  // 🌐 واجهة الويب الاحترافية المحدثة بالكامل
  Widget _buildWebDashboard() {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Row(
        children: [
          Container(
            width: 260,
            color: _cardBg,
            child: Column(
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flight_takeoff, color: _accentTeal, size: 42),
                      const SizedBox(height: 8),
                      Text(_agencyName ?? 'مكتب السفريات', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _buildSidebarItem(Icons.dashboard, 'لوحة التحكم', 0),
                      _buildSidebarItem(Icons.directions_bus, 'المركبات', 1),
                      _buildSidebarItem(Icons.route, 'الرحلات', 2),
                      _buildSidebarItem(Icons.account_balance_wallet, 'المعاملات المالية', 3),
                      _buildSidebarItem(Icons.bar_chart, 'تحليلات الأداء', 4),
                      _buildSidebarItem(Icons.notifications, 'الإشعارات', 5),
                      _buildSidebarItem(Icons.person, 'الملف الشخصي', 6),
                      _buildSidebarItem(Icons.settings, 'الإعدادات', 7),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo', fontSize: 14)),
                  onTap: () async {
                    await _auth.signOut();
                    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  color: _cardBg,
                  child: Row(
                    children: [
                      Text(
                        _selectedWebPageIndex == 0 ? 'لوحة التحكم الرئيسية' :
                        _selectedWebPageIndex == 1 ? 'إدارة المركبات' :
                        _selectedWebPageIndex == 2 ? 'إدارة الرحلات' :
                        _selectedWebPageIndex == 3 ? 'الحسابات والمعاملات' :
                        _selectedWebPageIndex == 4 ? 'تحليلات الأداء والتقارير' :
                        _selectedWebPageIndex == 5 ? 'مركز الإشعارات' :
                        _selectedWebPageIndex == 6 ? 'الملف الشخصي للمكتب' : 'إعدادات النظام',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      const Spacer(),
                      // شريط البحث المباشر للويب
                      if (_selectedWebPageIndex == 1 || _selectedWebPageIndex == 2)
                        Container(
                          width: 240,
                          height: 38,
                          margin: const EdgeInsets.only(left: 16),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 13),
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'بحث سريع...',
                              hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 12),
                              prefixIcon: const Icon(Icons.search, color: _accentTeal, size: 18),
                              filled: true,
                              fillColor: _darkBg,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_isActive ? 'الحساب نشط' : 'الحساب معطل',
                            style: TextStyle(color: _isActive ? Colors.greenAccent : Colors.redAccent, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildWebPageContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, int index) {
    final isSelected = _selectedWebPageIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? _accentTeal : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo', fontSize: 14)),
      tileColor: isSelected ? _primaryBlue.withOpacity(0.15) : Colors.transparent,
      onTap: () => setState(() {
        _selectedWebPageIndex = index;
        _searchQuery = '';
        _searchController.clear();
      }),
    );
  }

  Widget _buildWebPageContent() {
    switch (_selectedWebPageIndex) {
      case 1:
        return _buildVehiclesList(isDark: true);
      case 2:
        return _buildTripsList(isDark: true);
      case 3:
        return _buildTransactionsList(isDark: true);
      case 4:
        return _buildAnalyticsView(isDark: true);
      case 5:
        return _buildNotificationsView(isDark: true);
      case 6:
        return _buildProfileView(isDark: true);
      case 7:
        return _buildSettingsView(isDark: true);
      case 0:
      default:
        return SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _navigateToWallet,
                      child: WebStatCard(
                        title: 'الرصيد الحالي (انقر للتفاصيل)',
                        value: '$_balance ريال',
                        icon: Icons.account_balance_wallet,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WebStatCard(
                      title: 'حالة الحساب في النظام',
                      value: _isActive ? 'مفعل' : 'معطل',
                      icon: Icons.verified_user,
                      color: _primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      height: 420,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المركبات التابعة للمكتب', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              IconButton(icon: const Icon(Icons.add_circle_outline, color: _accentTeal), onPressed: _addVehicleDialog),
                            ],
                          ),
                          const Divider(color: Colors.white10),
                          Expanded(child: _buildVehiclesList(isDark: true)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 420,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الرحلات النشطة حالياً', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              IconButton(icon: const Icon(Icons.add_circle_outline, color: _accentTeal), onPressed: _addTripDialog),
                            ],
                          ),
                          const Divider(color: Colors.white10),
                          Expanded(child: _buildTripsList(isDark: true)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  // 📱 واجهة الموبايل الاحترافية المحدثة
  Widget _buildMobileDashboard() {
    return DefaultTabController(
      length: 6,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return Scaffold(
            backgroundColor: const Color(0xFFF4F6F9),
            appBar: AppBar(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.business, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_agencyName ?? 'مكتب السفريات',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: 'تحديد موقع المكتب',
                  onPressed: _navigateToLocationEdit,
                ),
              ],
            ),
            drawer: Drawer(
              child: Container(
                color: _cardBg,
                child: ListView(
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flight_takeoff, color: _accentTeal, size: 40),
                          const SizedBox(height: 8),
                          Text(_agencyName ?? 'مكتب السفريات', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.bar_chart, color: _accentTeal),
                      title: const Text('تحليلات الأداء', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: _darkBg, appBar: AppBar(backgroundColor: _primaryBlue, title: const Text('تحليلات الأداء', style: TextStyle(fontFamily: 'Cairo'))), body: _buildAnalyticsView(isDark: true))));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications, color: _accentTeal),
                      title: const Text('مركز الإشعارات', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: _darkBg, appBar: AppBar(backgroundColor: _primaryBlue, title: const Text('الإشعارات', style: TextStyle(fontFamily: 'Cairo'))), body: _buildNotificationsView(isDark: true))));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.person, color: _accentTeal),
                      title: const Text('الملف الشخصي', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: _darkBg, appBar: AppBar(backgroundColor: _primaryBlue, title: const Text('الملف الشخصي', style: TextStyle(fontFamily: 'Cairo'))), body: _buildProfileView(isDark: true))));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings, color: _accentTeal),
                      title: const Text('إعدادات النظام', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: _darkBg, appBar: AppBar(backgroundColor: _primaryBlue, title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Cairo'))), body: _buildSettingsView(isDark: true))));
                      },
                    ),
                  ],
                ),
              ),
            ),
            body: Column(
              children: [
                GestureDetector(
                  onTap: _navigateToWallet,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_accentTeal, Color(0xFF138886)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: _accentTeal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.white),
                            SizedBox(width: 8),
                            Text('الرصيد الحالي (اضغط للتفاصيل):', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo')),
                          ],
                        ),
                        Text('$_balance ريال', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                ),
                const Material(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    labelColor: _primaryBlue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: _primaryBlue,
                    labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(icon: Icon(Icons.directions_bus, size: 18), text: 'المركبات'),
                      Tab(icon: Icon(Icons.route, size: 18), text: 'الرحلات'),
                      Tab(icon: Icon(Icons.account_balance_wallet, size: 18), text: 'المعاملات'),
                      Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'التحليلات'),
                      Tab(icon: Icon(Icons.notifications, size: 18), text: 'الإشعارات'),
                      Tab(icon: Icon(Icons.person, size: 18), text: 'الملف'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildVehiclesList(isDark: false),
                      _buildTripsList(isDark: false),
                      _buildTransactionsList(isDark: false),
                      _buildAnalyticsView(isDark: false),
                      _buildNotificationsView(isDark: false),
                      _buildProfileView(isDark: false),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                return FloatingActionButton(
                  backgroundColor: _primaryBlue,
                  tooltip: tabController.index == 1 ? 'إضافة رحلة جديدة' : 'إضافة مركبة جديدة',
                  onPressed: () {
                    if (tabController.index == 1) {
                      _addTripDialog();
                    } else if (tabController.index == 0) {
                      _addVehicleDialog();
                    } else {
                      _showSnack('استخدم التبويب الأول أو الثاني لإضافة عناصر جديدة', color: _primaryBlue);
                    }
                  },
                  child: Icon(tabController.index == 1 ? Icons.add_road : Icons.add, color: Colors.white),
                );
              },
            ),
          );
        },
      ),
    );
  }
}