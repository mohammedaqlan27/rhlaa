import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/available_trips_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/my_bookings_screen.dart';
import '../screens/passenger_calendar_screen.dart';

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
      'صنعاء', 'عدن', 'تعز', 'الحديدة', 'إب', 'حضرموت', 'ذمار', 'المكلا', 'مأرب', 'شبوة'
    ],
    'خارجية': ['الرياض', 'جدة', 'مكة', 'مسقط', 'أبوظبي', 'دبي', 'الشارقة'],
  };

  void _searchTrips() {
    if (_selectedTripCategory == null || _selectedDestination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار فئة الرحلة والوجهة')),
      );
      return;
    }

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
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم تسجيل الخروج')),
    );
    Navigator.pushReplacementNamed(context, '/auth');
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🧭 اختر فئة الرحلة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedTripCategory,
          hint: const Text('اختر الفئة'),
          items: _tripCategories
              .map<DropdownMenuItem<String>>((category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedTripCategory = val;
              _selectedDestination = null;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
        ),
        const SizedBox(height: 16),

        const Text('📍 اختر الوجهة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedDestination,
          hint: const Text('اختر الوجهة'),
          items: (_selectedTripCategory != null ? _destinations[_selectedTripCategory] ?? [] : [])
              .map<DropdownMenuItem<String>>((dest) => DropdownMenuItem<String>(
                    value: dest,
                    child: Text(dest),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _selectedDestination = val),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 16),

        const Text('🚗 نوع السيارة (اختياري):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedVehicleType,
          hint: const Text('اختر نوع السيارة'),
          items: _vehicleTypes
              .map<DropdownMenuItem<String>>((type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _selectedVehicleType = val),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.directions_car),
          ),
        ),
        const SizedBox(height: 30),

        ElevatedButton.icon(
          onPressed: _searchTrips,
          icon: const Icon(Icons.search),
          label: const Text('بحث عن الرحلات'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade900,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: _openMyBookings,
          icon: const Icon(Icons.list_alt),
          label: const Text('رحلاتي'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: _openCalendar,
          icon: const Icon(Icons.calendar_today),
          label: const Text('عرض الرحلات في التقويم'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أهلاً بك أيها المسافر!'),
        backgroundColor: Colors.blue.shade900,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildFilters(),
          ),
        ),
      ),
    );
  }
}
