import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:url_launcher/url_launcher.dart';

import '../../providers/vehicle_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../create_trip_screen.dart';
import '../vehicle_screen.dart';
import '../trip_details_screen.dart';
import 'driver_calendar_screen.dart';
import '../user_ratings_screen.dart';
import '../../widgets/Passenger/trip_card.dart';
import '../../widgets/shared/settings_sheet.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String? userId;
  bool _isRefreshing = false;

  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF4F7FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final authProv = context.read<AuthProvider>();
        userId = authProv.currentUserId ?? fb.FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        userId = fb.FirebaseAuth.instance.currentUser?.uid;
      }
      userId ??= "test_driver_123";
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    if (userId != null && !userId!.startsWith('test_')) {
      context.read<VehicleProvider>().fetchDriverVehicles(userId!);
      context.read<TripProvider>().watchDriverTripsRealtime(userId!);
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _isRefreshing = true);
    if (userId != null && !userId!.startsWith('test_')) {
      await context.read<VehicleProvider>().fetchDriverVehicles(userId!);
      await context.read<TripProvider>().fetchDriverTrips(userId!, forceRefresh: true);
    }
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() => _isRefreshing = false);
  }

  Future<void> _goToCreateTrip() async {
    final vehicleProvider = context.read<VehicleProvider>();
    if (vehicleProvider.vehicles.isEmpty) {
      _showSnack('🚨 يرجى إضافة مركبة أولاً في قسم المركبات');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen()));
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: const TextStyle(fontFamily: 'Cairo')), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _contactSupport() async {
    final Uri whatsapp = Uri.parse("https://wa.me/967770000000");
    try {
      await launchUrl(whatsapp, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnack('تعذر فتح واتساب');
    }
  }

  @override
  void dispose() {
    try {
      context.read<TripProvider>().stopWatchingAvailableTrips();
      context.read<TripProvider>().stopWatchingDriverTrips();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProv = context.watch<VehicleProvider>();
    final tripProv = context.watch<TripProvider>();
    final userProvider = context.watch<UserProvider>();
    final authProv = context.watch<AuthProvider>();

    final userName = authProv.currentUserName ?? 'سائق';
    final currentVehicle = vehicleProv.selectedVehicle ?? (vehicleProv.vehicles.isNotEmpty ? vehicleProv.vehicles.first : null);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _logoBlue,
        title: const Text('لوحة السائق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _contactSupport, icon: const Icon(Icons.headset_mic)),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VehicleScreen(driverId: userId ?? "")),
            ),
            icon: const Icon(Icons.directions_car),
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SettingsSheet(),
              );
            },
            icon: const Icon(Icons.settings), // زر الإعدادات
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: _logoBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDriverHeaderCard(userName, currentVehicle),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(userProvider),
              const SizedBox(height: 12),
              _buildVehiclesSection(vehicleProv),
              const SizedBox(height: 12),
              _buildTripsHeader(),
              _buildTripList(tripProv),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToCreateTrip,
        backgroundColor: _logoGreen,
        icon: const Icon(Icons.add),
        label: const Text('نشر رحلة جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDriverHeaderCard(String userName, dynamic vehicle) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_logoBlue, _logoTeal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _logoBlue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Text(userName.isNotEmpty ? userName[0] : 'س', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(userName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const SizedBox(height: 6),
              if (vehicle != null)
                Text('${vehicle.vehicleType ?? ''} • ${vehicle.plateNumber ?? ''}', style: const TextStyle(color: Colors.white70))
              else
                const Text('لم يتم اختيار مركبة', style: TextStyle(color: Colors.white70)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(UserProvider userProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8,
        children: [
          _buildActionBtn('إنشاء رحلة', Icons.add_location_alt, _logoGreen, _goToCreateTrip),
          _buildActionBtn('التقويم', Icons.calendar_month, Colors.orange, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverCalendarScreen()));
          }),
          _buildActionBtn('تقييماتي', Icons.reviews, _logoBlue, () {
            final uid = userId ?? context.read<AuthProvider?>()?.currentUserId ?? '';
            Navigator.push(context, MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: uid)));
          }),
          _buildActionBtn('الدعم الفني', Icons.headset_mic, Colors.teal, _contactSupport),
          if (userProvider.currentUser != null && userProvider.currentUser!.isActiveDriver != true)
            _buildActionBtn('تفعيل السائق', Icons.verified_user, Colors.green, () async {
              final success = await userProvider.isIdVerified(context: context);
              if (!true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('فشل تفعيل السائق'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehiclesSection(VehicleProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'المركبة النشطة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (provider.vehicles.isEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.car_repair, color: Colors.grey),
                const SizedBox(width: 12),
                const Text('لا توجد مركبات مسجلة', style: TextStyle(fontFamily: 'Cairo')),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VehicleScreen(driverId: userId ?? '')),
                  ),
                  child: const Text('إضافة'),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: provider.vehicles.length,
              itemBuilder: (context, index) {
                final v = provider.vehicles[index];
                final isSelected = provider.selectedVehicle?.id == v.id;
                return GestureDetector(
                  onTap: () => provider.selectVehicleById(v.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 150,
                    margin: EdgeInsets.only(left: index == 0 ? 0 : 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? _logoBlue : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? _logoBlue : Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: _logoBlue.withOpacity(0.12), blurRadius: 8)]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car, color: isSelected ? Colors.white : _logoBlue),
                        const SizedBox(height: 8),
                        Text(
                          v.plateNumber ?? '-',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.vehicleType ?? '',
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTripsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        'رحلاتي الحالية',
        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildTripList(TripProvider tripProv) {
    final trips = tripProv.driverTrips;
    if (tripProv.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (trips.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            'لا توجد رحلات نشطة حالياً',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: trips.length,
      itemBuilder: (context, index) => TripCard(
        trip: trips[index],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trips[index])),
        ),
      ),
    );
  }
}
