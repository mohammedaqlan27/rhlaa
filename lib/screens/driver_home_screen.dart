import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../screens/notification_screen.dart';
import '../screens/driver_bookings_screen.dart';
import '../screens/user_ratings_screen.dart';
import '../screens/create_trip_screen.dart';

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

  // محول آمن لأنواع التاريخ (Timestamp, DateTime, String)
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

  /// عند الضغط على زر "إنشاء رحلة" نتحقق أولاً من أن بيانات السائق الأساسية موجودة
  /// (رقم اللوحة واسم مالك المركبة). إذا كانت ناقصة نعرض SnackBar يطلب تحديث الملف الشخصي.
  /// خلاف ذلك ننتقل إلى شاشة إنشاء الرحلة.
  void _goToCreateTrip() async {
    final uid = userId;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      // الحقول في قاعدة البيانات كما ذكرت: plate_number و vehicle_owner
      final plateNumber = (data['plate_number'] as String?)?.trim();
      final vehicleOwner = (data['vehicle_owner'] as String?)?.trim();

      if (plateNumber == null || plateNumber.isEmpty || vehicleOwner == null || vehicleOwner.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚨 يرجى تحديث الملف الشخصي: رقم اللوحة واسم مالك المركبة مطلوبان')),
        );
        return;
      }

      // كل شيء جيد — انتقل إلى شاشة إنشاء الرحلة
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateTripScreen()),
      );
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

  Widget buildDriverCard() {
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

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👤 $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('⭐ متوسط التقييم: ${rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (uid.isNotEmpty) {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: uid)));
                        }
                      },
                      icon: const Icon(Icons.rate_review),
                      label: const Text('عرض التقييمات'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/calendar'),
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('عرض التقويم'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < rating.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // عرض رقم اللوحة واسم المالك داخل بطاقة السائق لتذكير المستخدم
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
          ),
        );
      },
    );
  }

  Widget buildTripCard(Trip trip) {
    final dt = _toDateTime(trip.departureTime);
    final formattedTime = DateFormat('yyyy-MM-dd – HH:mm').format(dt);
    final statusColor = {
      'مفعّلة': Colors.green,
      'ملغاة': Colors.red,
      'في الطريق': Colors.orange,
      'مكتملة': Colors.grey,
    }[trip.status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🚗 ${trip.vehicleType} من ${trip.origin} إلى ${trip.destination}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text('التاريخ: $formattedTime'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event_seat, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text('المقاعد المتاحة: ${trip.availableSeats} من ${trip.totalSeats}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text('الحالة: ${trip.status}', style: TextStyle(color: statusColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (trip.id != null && trip.id!.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DriverBookingsScreen(tripId: trip.id!)),
                      );
                    }
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('الركاب'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'تعديل') {
                      _goToEditTrip(trip);
                    } else if (value == 'حذف') {
                      _deleteTrip(trip.id ?? '');
                    } else {
                      _updateTripStatus(trip.id ?? '', value);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'مفعّلة', child: Text('تفعيل')),
                    PopupMenuItem(value: 'ملغاة', child: Text('إلغاء')),
                    PopupMenuItem(value: 'في الطريق', child: Text('بدء الرحلة')),
                    PopupMenuItem(value: 'مكتملة', child: Text('إنهاء الرحلة')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'تعديل', child: Text('تعديل الرحلة')),
                    PopupMenuItem(value: 'حذف', child: Text('حذف الرحلة')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('يجب تسجيل الدخول لعرض الرحلات')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلاتي كسائق'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _goToCreateTrip,
            tooltip: 'إنشاء رحلة جديدة',
          ),
        ],
      ),
      body: Column(
        children: [
          buildDriverCard(),
          Expanded(
            child: StreamBuilder<List<Trip>>(
              stream: _driverTripsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('لم تقم بإنشاء أي رحلات بعد.'));
                }

                final trips = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return buildTripCard(trip);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
