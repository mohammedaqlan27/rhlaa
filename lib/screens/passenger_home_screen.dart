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

/// شاشة رئيسية للمسافر محسّنة: تستخدم AppScaffold و AppCard و CustomButton و TripCard
/// لتحسين التناسق، الاستجابة، وتجربة المستخدم.
class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  String? _selectedTripCategory;
  String? _selectedDestination;
  String? _selectedVehicleType;

  final List<String> _tripCategories = ['داخلية', 'خارجية'];
  final List<String> _vehicleTypes = ['سيارة سيدان', 'سيارة دفع رباعي', 'سيارة فان'];

  final Map<String, List<String>> _destinations = {
    'داخلية': [
      'صنعاء',
      'عدن',
      'تعز',
      'الحديدة',
      'إب',
      'حضرموت',
      'ذمار',
      'المكلا',
      'مأرب',
      'شبوة'
    ],
    'خارجية': ['الرياض', 'جدة', 'مكة', 'مسقط', 'أبوظبي', 'دبي', 'الشارقة'],
  };

  final _formKey = GlobalKey<FormState>();

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

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🧭 اختر فئة الرحلة', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTripCategory,
            hint: const Text('اختر الفئة'),
            items: _tripCategories
                .map((category) => DropdownMenuItem<String>(value: category, child: Text(category)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedTripCategory = val;
                _selectedDestination = null;
              });
            },
            validator: (val) => val == null ? 'الرجاء اختيار فئة الرحلة' : null,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.category)),
          ),
          const SizedBox(height: 16),

          Text('📍 اختر الوجهة', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDestination,
            hint: const Text('اختر الوجهة'),
            items: (_selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : [])
                .map((dest) => DropdownMenuItem<String>(value: dest, child: Text(dest)))
                .toList(),
            onChanged: (val) => setState(() => _selectedDestination = val),
            validator: (val) => val == null ? 'الرجاء اختيار الوجهة' : null,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on)),
          ),
          const SizedBox(height: 16),

          Text('🚗 نوع السيارة (اختياري)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedVehicleType,
            hint: const Text('اختر نوع السيارة'),
            items: _vehicleTypes
                .map((type) => DropdownMenuItem<String>(value: type, child: Text(type)))
                .toList(),
            onChanged: (val) => setState(() => _selectedVehicleType = val),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.directions_car)),
          ),
          const SizedBox(height: 20),

          // أزرار الإجراءات الرئيسية باستخدام CustomButton لثبات الستايل
          CustomButton(
            onPressed: _searchTrips,
            text: 'بحث عن الرحلات',
            icon: Icons.search,
          ),
          const SizedBox(height: 12),
          CustomButton(
            onPressed: _openMyBookings,
            text: 'رحلاتي',
            icon: Icons.list_alt,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          ),
          const SizedBox(height: 12),
          CustomButton(
            onPressed: _openCalendar,
            text: 'عرض الرحلات في التقويم',
            icon: Icons.calendar_today,
            backgroundColor: Colors.indigo,
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(BuildContext context) {
    // مثال لعرض بطاقة اقتراح أو TripCard باستخدام نموذج Trip المركزي
    final mockTrip = Trip(
      id: 'mock-1',
      title: 'رحلة تجريبية',
      origin: 'صنعاء',
      destination: 'عدن',
      departureTime: DateTime.now().add(const Duration(hours: 6)),
      availableSeats: 3,
      totalSeats: 4,
      price: 25.0,
      status: 'مفعّلة',
      driverName: 'سائق تجريبي',
      vehicleType: 'سيارة سيدان',
      carPlateNumber: 'ABC-123',
      carOwnerOfficialName: 'معرض تجريبي',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اقتراحات سريعة', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        AppCard(
          child: ListTile(
            leading: const Icon(Icons.local_offer, color: Colors.green),
            title: const Text('رحلات مميزة اليوم'),
            subtitle: const Text('اطّلع على أفضل الرحلات المتاحة الآن'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableTripsScreen(destination: '')));
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // مثال على TripCard قابلة للنقر
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
    return AppScaffold(
      title: 'أهلاً بك أيها المسافر!',
      showSettingsButton: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 700 ? 32.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // بطاقة البحث الرئيسية باستخدام AppCard
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: _buildFilters(context),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // قسم الاقتراحات والرحلات
                    _buildSuggestionsSection(context),
                    const SizedBox(height: 24),

                    // روابط سريعة
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
                            icon: const Icon(Icons.history),
                            label: const Text('سجل الرحلات'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerCalendarScreen())),
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('التقويم'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        IconButton(
          tooltip: 'الإشعارات',
          icon: const Icon(Icons.notifications),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
        ),
        IconButton(
          tooltip: 'تسجيل الخروج',
          icon: const Icon(Icons.logout),
          onPressed: _logout,
        ),
      ],
    );
  }
}
