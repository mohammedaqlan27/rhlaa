// lib/screens/manage_trip_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip.dart';
import '../widgets/shared/app_card.dart';
import '../widgets/shared/custom_button.dart';
import 'trip_details_screen.dart';

class ManageTripScreen extends StatefulWidget {
  // جعلنا الـ trip اختيارية لأن الشاشة تعرض قائمة رحلات السائق
  final Trip? trip;
  const ManageTripScreen({super.key, this.trip});

  @override
  State<ManageTripScreen> createState() => _ManageTripScreenState();
}

class _ManageTripScreenState extends State<ManageTripScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Trip> _allTrips = [];
  bool _isLoading = true;

  // الألوان المعتمدة في النظام الاحترافي
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _bgGrey = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _allTrips = snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading trips: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String tripId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({'status': newStatus});
      _loadTrips(); // إعادة التحميل لتحديث القائمة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم تحديث الحالة إلى: $newStatus', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // تصفية الرحلات بناءً على الحالة
    final activeTrips = _allTrips.where((t) => t.status != 'ملغاة' && t.status != 'مكتملة').toList();
    final pastTrips = _allTrips.where((t) => t.status == 'ملغاة' || t.status == 'مكتملة').toList();

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('إدارة رحلاتي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _primaryBlue, fontSize: 18)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryBlue,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'الرحلات النشطة'),
            Tab(text: 'المنتهية / الملغاة'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildTripList(activeTrips, isPast: false),
          _buildTripList(pastTrips, isPast: true),
        ],
      ),
    );
  }

  Widget _buildTripList(List<Trip> trips, {required bool isPast}) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_filled_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(isPast ? 'لا توجد رحلات سابقة' : 'لا توجد رحلات نشطة حالياً',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) => _buildEnhancedTripCard(trips[index], isPast),
      ),
    );
  }

  Widget _buildEnhancedTripCard(Trip trip, bool isPast) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(trip.status),
              Text(trip.time, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: _primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(trip.destination, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.event, 'التاريخ: ${trip.date}'),
          _buildInfoRow(Icons.airline_seat_recline_normal, 'المقاعد المتاحة: ${trip.availableSeats} / ${trip.totalSeats}'),
          const Divider(height: 24),
          if (!isPast) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatusDropdown(trip),
                ),
                const SizedBox(width: 12),
                CustomButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
                  text: 'التفاصيل',
                  width: 100,
                  compact: true,
                  backgroundColor: _accentTeal,
                ),
              ],
            ),
          ] else
            const Center(child: Text('هذه الرحلة مؤرشفة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'مفعّلة': color = Colors.green; break;
      case 'في الطريق': color = Colors.orange; break;
      case 'ملغاة': color = Colors.red; break;
      default: color = _primaryBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(Trip trip) {
    final options = ['مفعّلة', 'في الطريق', 'تم الوصول', 'مكتملة', 'ملغاة'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: options.contains(trip.status) ? trip.status : options.first,
          items: options.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)))).toList(),
          onChanged: (val) => val != null ? _updateStatus(trip.id, val) : null,
        ),
      ),
    );
  }
}