// lib/screens/driver_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../state/auth_state.dart';
import '../models/trip.dart';
import 'edit_trip_screen.dart';
import 'trip_details_screen.dart';
import 'user_ratings_screen.dart'; // شاشة التقييمات

class DriverTripsScreen extends StatefulWidget {
  final String? targetDriverId;

  const DriverTripsScreen({super.key, this.targetDriverId});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  // لوحة الألوان الاحترافية (رحلاء)
  final Color _primaryBlue = const Color(0xFF1E70B8);
  final Color _tealAccent = const Color(0xFF17A5A3);
  final Color _goldMedal = const Color(0xFFFFB300);
  final Color _softBg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    Future.microtask(() {
      final authState = context.read<AuthState>();
      // تحديد المعرف الفعلي (effectiveDriverId)
      final effectiveId = widget.targetDriverId ?? authState.userId;
      if (effectiveId != null) {
        context.read<TripProvider>().fetchDriverTrips(effectiveId.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final tripProvider = context.watch<TripProvider>();

    // التحقق من الملكية: هل الزائر هو صاحب الرحلات؟
    final bool isOwner = widget.targetDriverId == null || widget.targetDriverId == authState.userId;
    final List<Trip> trips = tripProvider.driverTrips;

    return Scaffold(
      backgroundColor: _softBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. AppBar متفاعل (SliverAppBar)
          _buildModernAppBar(isOwner),

          // 2. رأس الصفحة (Driver Profile Header)
          SliverToBoxAdapter(
            child: _buildDriverProfileHeader(isOwner, widget.targetDriverId ?? authState.userId.toString()),
          ),

          // 3. قائمة الرحلات
          tripProvider.isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : trips.isEmpty
              ? _buildEmptyState()
              : SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTripCard(trips[index], isOwner),
                childCount: trips.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(bool isOwner) {
    return SliverAppBar(
      expandedHeight: 100.0,
      pinned: true,
      elevation: 0,
      backgroundColor: _primaryBlue,
      centerTitle: true,
      title: Text(
        isOwner ? 'رحلاتي المجدولة' : 'رحلات الكابتن',
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _refreshData,
        )
      ],
    );
  }

  Widget _buildDriverProfileHeader(bool isOwner, String driverId) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // صورة السائق مع Hero Animation
              Hero(
                tag: 'driver_avatar_$driverId',
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: _primaryBlue.withOpacity(0.1),
                  child: Icon(Icons.person_rounded, size: 40, color: _primaryBlue),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('كابتن رحلاء المتميز', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: driverId))),
                      child: Row(
                        children: [
                          Icon(Icons.star_rounded, color: _goldMedal, size: 18),
                          const SizedBox(width: 4),
                          const Text('4.9', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text(' (عرض التقييمات)', style: TextStyle(color: Colors.blue, fontSize: 11, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // وسام سائق الشهر (يظهر للجميع)
              _buildBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_goldMedal, Colors.orange.shade700]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.workspace_premium, color: Colors.white, size: 20),
          Text('سائق الشهر', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip, bool isOwner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(trip.status ?? 'مجدولة'),
                  Text('${trip.price} ر.ي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: _tealAccent, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              // مسار الرحلة (Visual Hierarchy)
              Row(
                children: [
                  Column(
                    children: [
                      Icon(Icons.radio_button_checked, size: 18, color: _primaryBlue),
                      Container(width: 2, height: 20, color: Colors.grey.shade200),
                      const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.origin, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),
                        Text(trip.destination, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(trip.time ?? '--:--', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  // زر التعديل: يظهر فقط للمالك (isOwner)
                  if (isOwner)
                    ElevatedButton.icon(
                      onPressed: () => _navigateToEdit(trip),
                      icon: const Icon(Icons.edit_square, size: 16),
                      label: const Text('تعديل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _tealAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: _tealAccent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  void _navigateToEdit(Trip trip) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditTripScreen(tripId: trip.id))).then((_) => _refreshData());
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_filled_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('لا توجد رحلات مجدولة حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

extension on AuthState {
  Object? get userId => null;
}