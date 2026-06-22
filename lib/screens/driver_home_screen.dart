// lib/screens/driver_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/app_card.dart';
import '../widgets/trip_card.dart';
import '../widgets/custom_button.dart';

import '../models/trip.dart';
import 'notification_screen.dart';
import 'user_ratings_screen.dart';
import 'create_trip_screen.dart';
import 'trip_details_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String? userId;

  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF4F7FA);

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
  }

  Stream<List<Trip>> _driverTripsStream() {
    final uid = userId;
    if (uid == null || uid.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList());
  }

  Future<void> _goToCreateTrip() async {
    final uid = userId;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      final plateNumber = (data['plate_number'] as String?)?.trim();
      final vehicleOwner = (data['vehicle_owner'] as String?)?.trim();

      if (plateNumber == null || plateNumber.isEmpty || vehicleOwner == null || vehicleOwner.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 يرجى تحديث ملفك الشخصي: رقم اللوحة واسم مالك المركبة مطلوبان لإضافة رحلة',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen()));
    } catch (e, st) {
      debugPrint('goToCreateTrip error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ حدث خطأ أثناء التحقق من بيانات مركبتك', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  Widget _buildDriverCard() {
    final uid = userId;
    if (uid == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('تعذر تحميل بيانات السائق أو لم يتم تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(color: _logoBlue, backgroundColor: _logoBlue.withOpacity(0.1)),
          );
        }

        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('بيانات السائق غير متوفرة حالياً في قاعدة البيانات', style: TextStyle(fontFamily: 'Cairo')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = (data['nickname'] as String?) ?? 'سائق رحلاء المتميز';
        final rating = (data['average_rating'] as num?)?.toDouble() ?? 5.0;
        final plateNumber = (data['plate_number'] as String?) ?? 'غير محددة';
        final vehicleOwner = (data['vehicle_owner'] as String?) ?? 'غير محدد';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [_logoBlue, _logoTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: _logoBlue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '🧑‍✈️ كابتن: $name',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white, fontFamily: 'Cairo'),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('اللوحة: $plateNumber', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontFamily: 'Cairo')),
                    ),
                    const Icon(Icons.assignment_ind_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('المالك: $vehicleOwner', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontFamily: 'Cairo')),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Colors.white24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CustomButton(
                      onPressed: () {
                        if (uid.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: uid)));
                        }
                      },
                      text: 'تقييماتي',
                      icon: Icons.rate_review_outlined,
                      backgroundColor: Colors.white,
                      textColor: _logoBlue,
                      compact: true,
                    ),
                    const SizedBox(width: 8),
                    CustomButton(
                      onPressed: () => Navigator.pushNamed(context, '/calendar'),
                      text: 'جدول التقويم',
                      icon: Icons.calendar_month_outlined,
                      backgroundColor: _logoGreen,
                      textColor: Colors.white,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTripList() {
    return StreamBuilder<List<Trip>>(
      stream: _driverTripsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _logoBlue));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'لم تقم بإنشاء أي رحلات كسائق حتى الآن.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final trips = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: trips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final trip = trips[index];
            return TripCard(
              trip: trip,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
              },
              showPrice: true,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('الرجاء تسجيل الدخول أولاً لعرض لوحة التحكم الخاص بك', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('لوحة تحكم السائق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_active_outlined, color: _logoBlue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: _logoGreen, size: 26),
            tooltip: 'إنشاء رحلة جديدة',
            onPressed: _goToCreateTrip,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView( // الحماية الكبرى لواجهة المستخدم من أي تضارب مساحات
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDriverCard(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.history_toggle_off_rounded, size: 18, color: _logoBlue),
                    const SizedBox(width: 6),
                    const Text(
                      'رحلاتي المضافة حالياً',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              _buildTripList(), // تم إزالته من الـ Expanded لحمايته داخل الـ SingleChildScrollView
            ],
          ),
        ),
      ),
    );
  }
}