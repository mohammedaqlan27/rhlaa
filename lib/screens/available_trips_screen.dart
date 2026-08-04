// lib/screens/available_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../models/trip.dart';
import '../widgets/Passenger/trip_card.dart';
import 'trip_details_screen.dart';

class AvailableTripsScreen extends StatefulWidget {
  final String destination;
  final String? tripCategory;
  final String? vehicleType;

  const AvailableTripsScreen({
    super.key,
    required this.destination,
    this.tripCategory,
    this.vehicleType,
  });

  @override
  State<AvailableTripsScreen> createState() => _AvailableTripsScreenState();
}

class _AvailableTripsScreenState extends State<AvailableTripsScreen> {
  // لوحة الألوان المعتمدة (Modern Flat Design 2.0)
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _bgSecondary = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().fetchAvailableTrips();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<TripProvider>().fetchAvailableTrips(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgSecondary,
        // --- 1. القائمة الجانبية الكبيرة (Drawer) ---
        drawer: _buildSideDrawer(context),

        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _textDark),
          title: const Text(
            'الرحلات المتاحة', // تم تبسيط العنوان بناءً على طلبك
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: _textDark,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () {
                // منطق الفلترة المتقدمة
              },
            ),
          ],
        ),

        body: Consumer<TripProvider>(
          builder: (context, tripProvider, child) {
            if (tripProvider.isLoading) {
              return const Center(child: CircularProgressIndicator(color: _primaryBlue));
            }

            if (tripProvider.errorMessage != null) {
              return _buildErrorState(tripProvider.errorMessage!);
            }

            // منطق عرض جميع الرحلات أو المفلترة
            final allTrips = tripProvider.availableTrips;
            final filteredTrips = allTrips.where((trip) {
              final matchesDest = widget.destination.isEmpty ||
                  trip.destination.contains(widget.destination);
              return matchesDest;
            }).toList();

            if (filteredTrips.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: _primaryBlue,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: filteredTrips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return Hero(
                    tag: 'trip-${filteredTrips[index].id}',
                    child: TripCard(
                      trip: filteredTrips[index],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripDetailsScreen(trip: filteredTrips[index]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),

        // --- 2. القائمة السفلية (Bottom Navigation) ---
        bottomNavigationBar: _buildBottomNav(context),
      ),
    );
  }

  // تصميم القائمة الجانبية (Drawer)
  Widget _buildSideDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: _primaryBlue),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: _primaryBlue),
            ),
            accountName: const Text('مستخدم رحلاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            accountEmail: const Text('user@rhlaa.com', style: TextStyle(fontFamily: 'Cairo')),
          ),
          _buildDrawerItem(Icons.home_rounded, 'الرئيسية', () => Navigator.pushReplacementNamed(context, '/passenger_home')),
          _buildDrawerItem(Icons.confirmation_number_rounded, 'حجوزاتي', () => Navigator.pushNamed(context, '/my_bookings')),
          _buildDrawerItem(Icons.settings_suggest_rounded, 'الإعدادات', () => Navigator.pushNamed(context, '/settings')),
          const Divider(),
          _buildDrawerItem(Icons.help_outline_rounded, 'مركز المساعدة', () {}),
          _buildDrawerItem(Icons.logout_rounded, 'تسجيل الخروج', () {}, color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? _textDark),
      title: Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: color ?? _textDark)),
      onTap: onTap,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network('https://cdn-icons-png.flaticon.com/512/7486/7486744.png', height: 150, opacity: const AlwaysStoppedAnimation(0.5)),
          const SizedBox(height: 20),
          const Text('لا توجد رحلات متاحة حالياً', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(), // إصلاح زر العودة للبحث
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('العودة للبحث', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.orange),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontFamily: 'Cairo')),
          TextButton(onPressed: _onRefresh, child: const Text('تحديث القائمة')),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
        onTap: (index) {
          switch (index) {
            case 0: Navigator.pushReplacementNamed(context, '/passenger_home'); break;
            case 2: Navigator.pushNamed(context, '/my_bookings'); break;
            case 3: Navigator.pushNamed(context, '/profile'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'الرحلات'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'حجوزاتي'),
          BottomNavigationBarItem(icon: Icon(Icons.person_2_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}