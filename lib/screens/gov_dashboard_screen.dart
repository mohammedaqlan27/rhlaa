import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔗 استيراد المكونات المشتركة
import '../widgets/shared/stat_card.dart';
import '../widgets/shared/settings_sheet.dart';
import '../widgets/shared/app_scaffold.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/notification_bell.dart';
import '../widgets/shared/loading_indicator.dart';
import '../widgets/shared/custom_button.dart';
import '../widgets/shared/custom_text_field.dart';
import 'admin/admin_dashboard_screen.dart' show LoadingIndicator;

// 🔗 اسم مستعار للشاشة ليتوافق مع الاستدعاء في main.dart
Widget GovDashboardScreen() => const GovernmentDashboardScreen();

class GovernmentDashboardScreen extends StatefulWidget {
  const GovernmentDashboardScreen({super.key});

  @override
  State<GovernmentDashboardScreen> createState() => _GovernmentDashboardScreenState();
}

class _GovernmentDashboardScreenState extends State<GovernmentDashboardScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedWebPageIndex = 0;

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _govGold = Color(0xFFD4AF37);

  void _showSnack(String msg, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
      ),
    );
  }

  // ⚙️ فتح ورقة الإعدادات المشتركة
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SettingsSheet(),
    );
  }

  // 📋 نافذة تفاصيل تصريح الرحلة والركاب للجهة الحكومية
  Future<void> _showPermitDetailsDialog(String tripId, Map<String, dynamic> tripData) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181B20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: _govGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تصريح رحلة: ${tripData['tripNumber'] ?? tripId.substring(0, 6)}',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('الشركة / الوكالة:', tripData['agencyName'] ?? 'غير محدد'),
                _buildInfoRow('خط السير:', '${tripData['fromCity'] ?? ''} ⬅️ ${tripData['toCity'] ?? ''}'),
                _buildInfoRow('تاريخ المغادرة:', tripData['departureDate'] ?? 'غير محدد'),
                _buildInfoRow('اسم السائق:', tripData['driverName'] ?? 'غير محدد'),
                _buildInfoRow('رقم اللوحة / الحافلة:', tripData['busPlateNumber'] ?? 'غير محدد'),
                _buildInfoRow('حالة التصريح:', tripData['permitStatus'] ?? 'مستوفي الشروط', isHighlight: true),
                const Divider(color: Colors.white24, height: 24),
                const Text('قائمة الركاب المسجلين:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('trips').doc(tripId).collection('passengers').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: LoadingIndicator());
                    }
                    final passengers = snapshot.data?.docs ?? [];
                    if (passengers.isEmpty) {
                      return const Text('لا يوجد ركاب مسجلون حالياً في التصريح', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 12));
                    }
                    return Column(
                      children: passengers.map((doc) {
                        final p = doc.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF222732), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p['fullName'] ?? 'راكب', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 13)),
                              Text('هوية: ${p['idNumber'] ?? 'غير مدخل'}', style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 11)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          CustomButton(
            text: 'إغلاق',
            backgroundColor: Colors.grey.shade700,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            text: 'اعتماد وموافقة المنفذ',
            backgroundColor: _accentTeal,
            onPressed: () async {
              await _firestore.collection('trips').doc(tripId).update({
                'govApproved': true,
                'govApprovedAt': FieldValue.serverTimestamp(),
              });
              _showSnack('تم تسجيل اعتماد الرحلة بالمنفذ الحكومي');
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? _govGold : Colors.white,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Cairo',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // 🔍 شريط البحث والاستعلام السريع عن الرحلات والتصاريح
  Widget _buildSearchHeader() {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: CustomTextField(
              controller: _searchController,
              label: 'البحث برقم التصريح، اسم السائق، أو رقم اللوحة...',
              prefixIcon: Icons.search,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ],
        ],
      ),
    );
  }

  // 🚌 قائمة التصاريح والرحلات للمراقبة الحكومية
  Widget _buildTripsPermitList({bool onlyPendingGov = false}) {
    Query query = _firestore.collection('trips').orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: LoadingIndicator());
        }
        var docs = snapshot.data?.docs ?? [];

        if (onlyPendingGov) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['govApproved'] ?? false) == false;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final tripNum = (data['tripNumber'] ?? '').toString().toLowerCase();
            final driver = (data['driverName'] ?? '').toString().toLowerCase();
            final busPlate = (data['busPlateNumber'] ?? '').toString().toLowerCase();
            final agency = (data['agencyName'] ?? '').toString().toLowerCase();

            return tripNum.contains(_searchQuery) ||
                driver.contains(_searchQuery) ||
                busPlate.contains(_searchQuery) ||
                agency.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return const Center(
            child: Text('لا توجد تصاريح مطابقة للبحث حالياً', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final tripData = docs[i].data() as Map<String, dynamic>;
            final tripId = docs[i].id;
            final isGovApproved = tripData['govApproved'] ?? false;

            return AppCard(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isGovApproved ? Colors.green.withOpacity(0.2) : _govGold.withOpacity(0.2),
                  child: Icon(
                    isGovApproved ? Icons.verified : Icons.gavel,
                    color: isGovApproved ? Colors.green : _govGold,
                  ),
                ),
                title: Text(
                  '${tripData['agencyName'] ?? 'وكالة'} (${tripData['fromCity'] ?? ''} ⬅️ ${tripData['toCity'] ?? ''})',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'السائق: ${tripData['driverName'] ?? 'غير محدد'} | اللوحة: ${tripData['busPlateNumber'] ?? 'غير محدد'}',
                  style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        isGovApproved ? 'معتمد' : 'قيد الفحص',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: isGovApproved ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.visibility, color: _primaryBlue),
                      onPressed: () => _showPermitDetailsDialog(tripId, tripData),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 850) {
            return _buildWebLayout();
          }
          return _buildMobileLayout();
        },
      ),
    );
  }

  // 🌐 لوحة الويب للجهة الحكومية
  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Row(
        children: [
          Container(
            width: 260,
            color: const Color(0xFF181B20),
            child: Column(
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance, color: _govGold, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'مكتب الرقابة والتصاريح',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                ),
                _buildSidebarItem(Icons.dashboard, 'الإحصائيات والرقابة', 0),
                _buildSidebarItem(Icons.playlist_add_check, 'التصاريح المعمدة', 1),
                _buildSidebarItem(Icons.pending_actions, 'رحلات بانتظار الاعتماد', 2),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text('الإعدادات', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  onTap: _openSettings,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: const Color(0xFF181B20),
                  child: Row(
                    children: [
                      Text(
                        _selectedWebPageIndex == 0
                            ? 'نظام الرقابة والتفتيش على الرحلات'
                            : _selectedWebPageIndex == 1
                            ? 'قائمة التصاريح المعمدة'
                            : 'التصاريح بانتظار التفتيش والاعتماد',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      const Spacer(),
                      const NotificationBell(),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white70),
                        onPressed: _openSettings,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildWebBody(),
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
      leading: Icon(icon, color: isSelected ? _govGold : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
      ),
      tileColor: isSelected ? _govGold.withOpacity(0.15) : Colors.transparent,
      onTap: () => setState(() => _selectedWebPageIndex = index),
    );
  }

  Widget _buildWebBody() {
    switch (_selectedWebPageIndex) {
      case 1:
        return Column(
          children: [
            _buildSearchHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildTripsPermitList(onlyPendingGov: false)),
          ],
        );
      case 2:
        return Column(
          children: [
            _buildSearchHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildTripsPermitList(onlyPendingGov: true)),
          ],
        );
      case 0:
      default:
        return SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('trips').snapshots(),
                      builder: (context, snap) => StatCard(
                        title: 'إجمالي الرحلات المسجلة',
                        value: '${snap.data?.docs.length ?? 0}',
                        icon: Icons.directions_bus,
                        iconColor: _primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('trips').where('govApproved', isEqualTo: true).snapshots(),
                      builder: (context, snap) => StatCard(
                        title: 'التصاريح المعمدة',
                        value: '${snap.data?.docs.length ?? 0}',
                        icon: Icons.verified_user,
                        iconColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('trips').where('govApproved', isEqualTo: false).snapshots(),
                      builder: (context, snap) => StatCard(
                        title: 'بانتظار الاعتماد',
                        value: '${snap.data?.docs.length ?? 0}',
                        icon: Icons.hourglass_top,
                        iconColor: _govGold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSearchHeader(),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تصاريح الرحلات الجارية والمغادرة',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      const Divider(color: Colors.white10),
                      Expanded(child: _buildTripsPermitList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  // 📱 لوحة الموبايل للجهة الحكومية
  Widget _buildMobileLayout() {
    return AppScaffold(
      title: 'مكتب الرقابة والتصاريح',
      actions: [
        const NotificationBell(),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: _openSettings,
        ),
      ],
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildSearchHeader(),
            ),
            const TabBar(
              labelColor: _govGold,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _govGold,
              tabs: [
                Tab(text: 'كل التصاريح'),
                Tab(text: 'بانتظار الاعتماد'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTripsPermitList(onlyPendingGov: false),
                  _buildTripsPermitList(onlyPendingGov: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget? LoadingIndicator() {
}