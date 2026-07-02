// lib/screens/available_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../models/trip.dart';
import '../widgets/trip_card.dart';
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
    // جلب البيانات عند فتح الشاشة من خلال الـ Provider بطريقة آمنة بعد بناء الشجرة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TripProvider>(context, listen: false);
      provider.fetchAvailableTrips();
    });
  }

  Future<void> _onRefresh() async {
    try {
      await Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips();
    } catch (_) {
      // يمكن إضافة لوج هنا إذا رغبت
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF4A7DAB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.destination.isNotEmpty ? 'رحلات إلى ${widget.destination}' : 'الرحلات المتاحة',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // فتح فلتر لاحقاً
            },
          ),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          // حالة التحميل
          if (tripProvider.isLoading) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          // حالة وجود خطأ
          if (tripProvider.errorMessage != null && tripProvider.errorMessage!.isNotEmpty) {
            return _buildErrorState(tripProvider.errorMessage!);
          }

          // تصفية الرحلات محلياً لضمان السرعة وتجنب مشاكل الـ Indexes في Firestore
          final allTrips = tripProvider.availableTrips;
          final filteredTrips = allTrips.where((trip) {
            final matchesDest = widget.destination.isEmpty ||
                trip.destination.trim().toLowerCase() == widget.destination.trim().toLowerCase();
            final matchesCat = widget.tripCategory == null ||
                widget.tripCategory!.isEmpty ||
                trip.tripCategory == widget.tripCategory;
            final matchesVehicle = widget.vehicleType == null ||
                widget.vehicleType!.isEmpty ||
                trip.vehicleType == widget.vehicleType;
            return matchesDest && matchesCat && matchesVehicle;
          }).toList();

          if (filteredTrips.isEmpty) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - kToolbarHeight - 80,
                  child: _buildEmptyState(),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: primaryColor,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTrips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final trip = filteredTrips[index];
                return TripCard(
                  trip: trip,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A7DAB)),
              child: const Text('حاول مرة أخرى', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, size: 80, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 20),
          const Text(
            'عذراً، لا توجد رحلات حالياً',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'جرب البحث عن وجهة أخرى أو عد لاحقاً',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7DAB),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('العودة للبحث', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: BottomNavigationBar(
        currentIndex: 1, // نحن الآن في شاشة الرحلات
        selectedItemColor: const Color(0xFF4A7DAB),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/passenger_home');
          if (index == 2) Navigator.pushNamed(context, '/my_bookings');
          if (index == 3) Navigator.pushNamed(context, '/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'الرحلات'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'حجوزاتي'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
