// lib/screens/driver_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/app_card.dart';
import '../widgets/trip_card.dart';
import '../widgets/custom_button.dart';

import '../models/trip.dart';
import 'notification_screen.dart';
import 'driver_bookings_screen.dart';
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

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
  }

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
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
          const SnackBar(content: Text('🚨 يرجى تحديث الملف الشخصي: رقم اللوحة واسم مالك المركبة مطلوبان')),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen()));
    } catch (e, st) {
      debugPrint('goToCreateTrip error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ حدث خطأ أثناء التحقق من بيانات الملف الشخصي')),
      );
    }
  }

  void _goToEditTrip(Trip trip) {
    Navigator.pushNamed(context, '/editTrip', arguments: trip.id);
  }

  Future<void> _deleteTrip(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذه الرحلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('trips').doc(tripId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حذف الرحلة بنجاح')),
        );
      } catch (e, st) {
        debugPrint('deleteTrip error: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ حدث خطأ أثناء حذف الرحلة')),
        );
      }
    }
  }

  Future<void> _updateTripStatus(String tripId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({'status': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تحديث حالة الرحلة إلى "$newStatus"')),
      );
    } catch (e, st) {
      debugPrint('updateTripStatus error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ فشل تحديث حالة الرحلة')),
      );
    }
  }

  Widget _buildDriverCard() {
    final uid = userId;
    if (uid == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('تعذر تحميل بيانات السائق أو لم يتم تسجيل الدخول'),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('تعذر تحميل بيانات السائق أو البيانات مفقودة'),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = (data['nickname'] as String?) ?? 'سائق غير معروف';
        final rating = (data['average_rating'] as num?)?.toDouble() ?? 0.0;
        final plateNumber = (data['plate_number'] as String?) ?? 'غير متوفر';
        final vehicleOwner = (data['vehicle_owner'] as String?) ?? 'غير متوفر';

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👤 $name', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('⭐ ${rating.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodyLarge),
                  CustomButton(
                    onPressed: () {
                      if (uid.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: uid)));
                      }
                    },
                    text: 'عرض التقييمات',
                    icon: Icons.rate_review,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                    compact: true,
                  ),
                  CustomButton(
                    onPressed: () => Navigator.pushNamed(context, '/calendar'),
                    text: 'التقويم',
                    icon: Icons.calendar_today,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.confirmation_number, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text('رقم اللوحة: $plateNumber')),
                  const SizedBox(width: 12),
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text('مالك المركبة: $vehicleOwner')),
                ],
              ),
            ],
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
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لم تقم بإنشاء أي رحلات بعد.', style: Theme.of(context).textTheme.bodyLarge));
        }

        final trips = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: trips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      return AppScaffold(
        title: 'رحلاتي كسائق',
        body: const Center(child: Text('يجب تسجيل الدخول لعرض الرحلات')),
      );
    }

    return AppScaffold(
      title: 'رحلاتي كسائق',
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'إنشاء رحلة جديدة',
          onPressed: _goToCreateTrip,
        ),
      ],
      body: Column(
        children: [
          _buildDriverCard(),
          const SizedBox(height: 8),
          Expanded(child: _buildTripList()),
        ],
      ),
    );
  }
}
