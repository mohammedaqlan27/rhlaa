import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        drawer: _buildSideDrawer(context),
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.webCardBackground : Colors.white,
          elevation: 0.5,
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : AppColors.textPrimary),
          title: Text(
            'الرحلات المتاحة',
            style: TextStyle(
              fontFamily: AppFonts.arabic,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () {
                // فلترة إضافية حسب الحاجة
              },
            ),
          ],
        ),
        body: Consumer<TripProvider>(
          builder: (context, tripProvider, child) {
            if (tripProvider.isLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            if (tripProvider.errorMessage != null) {
              return _buildErrorState(tripProvider.errorMessage!);
            }

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
              color: AppColors.primary,
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
        bottomNavigationBar: _buildBottomNav(context),
      ),
    );
  }

  Widget _buildSideDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.webCardBackground : Colors.white,
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: AppColors.primary),
            ),
            accountName: Text('مستخدم رحلاء', style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold)),
            accountEmail: Text('user@rhlaa.com', style: TextStyle(fontFamily: AppFonts.arabic)),
          ),
          _buildDrawerItem(Icons.home_rounded, 'الرئيسية', () => Navigator.pushReplacementNamed(context, '/passenger_home')),
          _buildDrawerItem(Icons.confirmation_number_rounded, 'حجوزاتي', () => Navigator.pushNamed(context, '/my_bookings')),
          _buildDrawerItem(Icons.settings_suggest_rounded, 'الإعدادات', () => Navigator.pushNamed(context, '/settings')),
          const Divider(),
          _buildDrawerItem(Icons.help_outline_rounded, 'مركز المساعدة', () {}),
          _buildDrawerItem(Icons.logout_rounded, 'تسجيل الخروج', () {}, color: AppColors.error),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : AppColors.textPrimary;

    return ListTile(
      leading: Icon(icon, color: color ?? defaultColor),
      title: Text(title, style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.w600, color: color ?? defaultColor)),
      onTap: onTap,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_bus_filled_outlined, size: 80, color: AppColors.gray400),
          const SizedBox(height: 20),
          const Text(
            'لا توجد رحلات متاحة حالياً',
            style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('العودة للبحث', style: TextStyle(fontFamily: AppFonts.arabic, color: Colors.white)),
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
          const Icon(Icons.wifi_off_rounded, size: 60, color: AppColors.warning),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontFamily: AppFonts.arabic)),
          TextButton(onPressed: _onRefresh, child: const Text('تحديث القائمة', style: TextStyle(fontFamily: AppFonts.arabic))),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.webCardBackground : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.gray400,
        selectedLabelStyle: const TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 11),
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