import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/trip_card.dart';

import '../models/trip.dart';
import '../providers/trip_provider.dart';
import 'available_trips_screen.dart' hide TripProvider;
import 'notification_screen.dart';
import 'my_bookings_screen.dart';
import 'passenger_calendar_screen.dart';
import 'auth_screen.dart';
import 'trip_details_screen.dart';
import 'profile_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  String? _selectedTripCategory;
  String? _selectedDestination;
  String? _selectedVehicleType;
  int _currentBottomIndex = 0;

  final List<String> _tripCategories = ['داخلية', 'خارجية'];
  final Map<String, List<String>> _destinations = {
    'داخلية': ['صنعاء', 'عدن', 'تعز', 'الحديدة', 'إب', 'حضرموت', 'ذمار', 'المكلا', 'مأرب', 'شبوة'],
    'خارجية': ['الرياض', 'جدة', 'مكة', 'مسقط', 'أبوظبي', 'دبي', 'الشارقة'],
  };

  final _formKey = GlobalKey<FormState>();
  final Color _primaryColor = const Color(0xFF4A7DAB);

  @override
  void initState() {
    super.initState();
    // جلب الرحلات فور فتح التطبيق لضمان تحديث البيانات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips();
    });
  }

  void _searchTrips() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableTripsScreen(
          destination: _selectedDestination!,
          tripCategory: _selectedTripCategory!,
          vehicleType: _selectedVehicleType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AppScaffold(
        title: 'رحلاء - وجهتك القادمة',
        showSettingsButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () => Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('✨ اقتراحات مخصصة', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableTripsScreen(destination: '')));
                }),
                const SizedBox(height: 12),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildSuggestionsSection(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
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
            _buildWhiteDropdown('الوجهة', Icons.location_on_outlined, _selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : [], _selectedDestination, (val) {
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ابحث عن رحلة الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        decoration: InputDecoration(icon: Icon(icon, color: _primaryColor, size: 20), border: InputBorder.none),
      ),
    );
  }

  Widget _buildSectionTitle(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        TextButton(onPressed: onTap, child: Text('عرض الكل', style: TextStyle(color: _primaryColor, fontFamily: 'Cairo'))),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionItem(Icons.history, 'رحلاتي', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()))),
        const SizedBox(width: 12),
        _buildActionItem(Icons.calendar_month, 'التقويم', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerCalendarScreen()))),
        const SizedBox(width: 12),
        _buildActionItem(Icons.support_agent, 'الدعم', Colors.green, () {}),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
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

  Widget _buildSuggestionsSection() {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        if (provider.availableTrips.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('لا توجد رحلات متاحة حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey[600])),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.availableTrips.length > 3 ? 3 : provider.availableTrips.length,
          itemBuilder: (context, index) {
            final trip = provider.availableTrips[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TripCard(
                trip: trip,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentBottomIndex,
      selectedItemColor: _primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        setState(() => _currentBottomIndex = index);
        if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
        if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerCalendarScreen()));
        if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'حجوزاتي'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'التقويم'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'حسابي'),
      ],
    );
  }
}