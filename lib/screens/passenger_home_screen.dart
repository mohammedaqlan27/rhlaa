// lib/screens/passenger_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // تأكد من إضافة الحزمة في pubspec.yaml

import '../widgets/shared/app_card.dart';
import '../widgets/Passenger/trip_card.dart';
import '../widgets/shared/custom_button.dart';

import '../models/trip.dart';
import '../providers/trip_provider.dart';
import 'available_trips_screen.dart' hide TripProvider;
import 'my_bookings_screen.dart';
import 'passenger_calendar_screen.dart';
import 'trip_details_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  String? _selectedTripCategory;
  String? _selectedDestination;

  final _formKey = GlobalKey<FormState>();

  // ألوان الهوية البصرية
  final Color _primaryBlue = const Color(0xFF1E70B8);
  final Color _accentTeal = const Color(0xFF17A5A3);
  final Color _bgGrey = const Color(0xFFF8FAFC);

  // قائمة المحافظات اليمنية الشاملة والوجهات الخارجية (نقطة 2)
  final List<String> _tripCategories = ['داخلية', 'خارجية'];
  final Map<String, List<String>> _destinations = {
    'داخلية': [
      'صنعاء', 'عدن', 'تعز', 'حضرموت', 'إب', 'الحديدة', 'ذمار', 'مأرب',
      'شبوة', 'المهرة', 'أبين', 'لحج', 'البيضاء', 'عمران', 'صعدة', 'الجوف',
      'حجة', 'المحويت', 'ريمة', 'الضالع', 'سقطرى'
    ],
    'خارجية': ['الرياض', 'جدة', 'مكة', 'دبي', 'عمان', 'القاهرة', 'الأردن'],
  };

  @override
  void initState() {
    super.initState();
    // جلب الرحلات فور فتح التطبيق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchAvailableTrips();
    });
  }

  // تفعيل الدعم الفني عبر واتساب (نقطة 5)
  Future<void> _launchSupport() async {
    final Uri url = Uri.parse("https://wa.me/967770000000"); // استبدله برقمك
    if (!await launchUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب الدعم')));
    }
  }

  void _searchTrips() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableTripsScreen(
          destination: _selectedDestination!,
          tripCategory: _selectedTripCategory!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ملاحظة: لا يوجد Scaffold هنا لأنه يُعرض داخل HomeScreen الرئيسي
    return RefreshIndicator(
      onRefresh: () => context.read<TripProvider>().fetchAvailableTrips(),
      color: _primaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 20),
            _buildSearchCard(), // كرت البحث الرئيسي
            const SizedBox(height: 24),
            _buildTravelMessages(), // نقطة 1: رسائل تهم المسافر
            const SizedBox(height: 24),
            _buildQuickActions(), // أزرار الوصول السريع
            const SizedBox(height: 24),
            _buildSectionHeader('✨ رحلات مقترحة لك'),
            _buildSuggestionsSection(), // قائمة الاقتراحات
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 1. رأس الصفحة الترحيبي
  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('أهلاً بك في رحلاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black54)),
        Text('خطط لرحلتك القادمة بكل سهولة',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: _primaryBlue)),
      ],
    );
  }

  // 2. كرت البحث المطور (Visual Hierarchy)
  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryBlue, _accentTeal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const Text('أين تريد الذهاب اليوم؟', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const SizedBox(height: 20),
            _buildWhiteDropdown('فئة الرحلة', Icons.map_outlined, _tripCategories, _selectedTripCategory, (val) {
              setState(() { _selectedTripCategory = val; _selectedDestination = null; });
            }),
            const SizedBox(height: 12),
            _buildWhiteDropdown('الوجهة المطلوبة', Icons.location_on_outlined,
                _selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : [],
                _selectedDestination, (val) {
                  setState(() => _selectedDestination = val);
                }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searchTrips,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('ابحث عن رحلة الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. رسائل تهم المسافر (نقطة 1)
  Widget _buildTravelMessages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('💡 معلومات تهمك', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildMessageCard('دعاء السفر', 'سبحان الذي سخر لنا هذا وما كنا له مقرنين...', Icons.auto_stories, Colors.amber),
              _buildMessageCard('نصيحة أمان', 'تأكد من حمل وثائق الهوية الأصلية قبل التوجه للموقف.', Icons.gpp_good, Colors.blue),
              _buildMessageCard('حالة الطريق', 'طريق هيجة العبد مفتوح حالياً للمسافرين.', Icons.add_road, Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageCard(String title, String content, IconData icon, Color color) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. أزرار الوصول السريع (نقطة 5 و 7)
  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionItem(Icons.history, 'حجوزاتي', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()))),
        const SizedBox(width: 12),
        _buildActionItem(Icons.calendar_month, 'التقويم', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerCalendarScreen()))),
        const SizedBox(width: 12),
        _buildActionItem(Icons.support_agent, 'الدعم', Colors.green, _launchSupport),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // 5. قائمة الاقتراحات
  Widget _buildSuggestionsSection() {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        if (provider.availableTrips.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد رحلات متاحة حالياً')));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.availableTrips.length > 3 ? 3 : provider.availableTrips.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TripCard(
                trip: provider.availableTrips[index],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: provider.availableTrips[index]))),
              ),
            );
          },
        );
      },
    );
  }

  // ويدجت المنسدلة البيضاء
  Widget _buildWhiteDropdown(String hint, IconData icon, List<String> items, String? value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)))).toList(),
        onChanged: onChanged,
        validator: (val) => val == null ? 'مطلوب' : null,
        decoration: InputDecoration(icon: Icon(icon, color: _primaryBlue, size: 20), border: InputBorder.none),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }
}