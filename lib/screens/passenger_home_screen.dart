// lib/screens/passenger_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/trip_card.dart';

import '../models/trip.dart';
import 'available_trips_screen.dart';
import 'notification_screen.dart';
import 'my_bookings_screen.dart';
import 'passenger_calendar_screen.dart';
import 'auth_screen.dart';
import 'trip_details_screen.dart';

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
  final List<String> _vehicleTypes = ['سيارة سيدان', 'سيارة دفع رباعي', 'سيارة فان'];

  final Map<String, List<String>> _destinations = {
    'داخلية': [
      'صنعاء', 'عدن', 'تعز', 'الحديدة', 'إب', 'حضرموت', 'ذمار', 'المكلا', 'مأرب', 'شبوة'
    ],
    'خارجية': ['الرياض', 'جدة', 'مكة', 'مسقط', 'أبوظبي', 'دبي', 'الشارقة'],
  };

  final _formKey = GlobalKey<FormState>();

  final Color _backgroundColor = const Color(0xFFF4F7FA);
  final Color _primaryColor = const Color(0xFF4A7DAB);

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

  void _openMyBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
  }

  void _openCalendar() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerCalendarScreen()));
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم تسجيل الخروج')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
    );
  }

  Widget _buildCustomDropdownContainer({required Widget child, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('🧭 فئة الرحلة', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          const SizedBox(height: 8),
          _buildCustomDropdownContainer(
            icon: Icons.category_outlined,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: _selectedTripCategory,
                hint: const Text('اختر الفئة المستهدفة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                items: _tripCategories
                    .map((category) => DropdownMenuItem<String>(value: category, child: Text(category, style: const TextStyle(fontFamily: 'Cairo'))))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTripCategory = val;
                    _selectedDestination = null;
                  });
                },
                validator: (val) => val == null ? 'الرجاء اختيار فئة الرحلة' : null,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('📍 الوجهة المقصودة', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          const SizedBox(height: 8),
          _buildCustomDropdownContainer(
            icon: Icons.location_on_outlined,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: _selectedDestination,
                hint: const Text('إلى أين تريد الذهاب؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                items: (_selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : [])
                    .map((dest) => DropdownMenuItem<String>(value: dest, child: Text(dest, style: const TextStyle(fontFamily: 'Cairo'))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedDestination = val),
                validator: (val) => val == null ? 'الرجاء اختيار الوجهة' : null,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('🚗 نوع السيارة المفضلة (اختياري)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          const SizedBox(height: 8),
          _buildCustomDropdownContainer(
            icon: Icons.directions_car_filled_outlined,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                hint: const Text('اختر نوع المركبة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                items: _vehicleTypes
                    .map((type) => DropdownMenuItem<String>(value: type, child: Text(type, style: const TextStyle(fontFamily: 'Cairo'))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedVehicleType = val),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(height: 24),

          CustomButton(
            onPressed: _searchTrips,
            text: 'البحث عن الرحلات المتوفرة الآن',
            icon: Icons.search_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(BuildContext context) {
    final mockTrip = Trip(
      id: 'mock-1',
      title: 'رحلة تجريبية متميزة',
      origin: 'صنعاء',
      destination: 'عدن',
      departureTime: DateTime.now().add(const Duration(hours: 6)),
      availableSeats: 3,
      totalSeats: 4,
      price: 25.0,
      status: 'مفعّلة',
      driverName: 'سائق محترف',
      vehicleType: 'سيارة سيدان',
      carPlateNumber: 'ABC-123',
      carOwnerOfficialName: 'رحلاء الرسمي',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('✨ اقتراحات مخصصة لك', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableTripsScreen(destination: ''))),
              child: Text('عرض الكل', style: TextStyle(color: _primaryColor, fontFamily: 'Cairo')),
            )
          ],
        ),
        const SizedBox(height: 8),
        AppCard(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.local_offer, color: Colors.green),
            ),
            title: const Text('عروض التوفير اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            subtitle: const Text('سافر بأقل الأسعار مع كابتن تقييمه عالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _primaryColor),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableTripsScreen(destination: '')));
            },
          ),
        ),
        const SizedBox(height: 16),
        TripCard(
          trip: mockTrip,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: mockTrip)));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: AppScaffold(
        title: 'أهلاً بك في رحلة 👋',
        showSettingsButton: true,
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 700 ? 32.0 : 20.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildFilters(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSuggestionsSection(context),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _openMyBookings,
                              icon: const Icon(Icons.history_toggle_off_rounded),
                              label: const Text('سجل الرحلات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _openCalendar,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: const Text('التقويم العام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, spreadRadius: 2),
          ],
        ),

        child: BottomNavigationBar(
        currentIndex: _currentBottomIndex,
        onTap: (index) {
      setState(() {
      _currentBottomIndex = index;
      });
      if (index == 1) {
      _openMyBookings();
      } else if (index == 2) {
      _openCalendar();
      }
      },
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_max_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_travel_outlined),
            activeIcon: Icon(Icons.card_travel_rounded),
            label: 'رحلاتي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'التقويم',
          ),
        ]),
      ),
    );
  }
}