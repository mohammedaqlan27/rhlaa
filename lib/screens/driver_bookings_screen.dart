// lib/screens/driver_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/booking_model.dart';
import '../models/app_user.dart';

class DriverBookingsScreen extends StatefulWidget {
  final String tripId;

  const DriverBookingsScreen({super.key, required this.tripId});

  @override
  State<DriverBookingsScreen> createState() => _DriverBookingsScreenState();
}

class _DriverBookingsScreenState extends State<DriverBookingsScreen> {
  /// محول آمن لأنواع التاريخ (Timestamp, DateTime, String)
  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
    } catch (_) {}
    return DateTime.now();
  }

  /// جلب الحجوزات المرتبطة برقم الرحلة مع معلومات الرحلة والراكب
  Future<List<Map<String, dynamic>>> _fetchBookingsWithTripInfo(String tripId) async {
    final firestore = FirebaseFirestore.instance;

    // جلب بيانات الرحلة (لعرض العنوان والوجهة)
    final tripDoc = await firestore.collection('trips').doc(tripId).get();
    final tripData = tripDoc.data() as Map<String, dynamic>?;

    final tripTitle = tripData?['title'] ?? tripData?['tripTitle'] ?? 'رحلة غير معروفة';
    final tripDestination = tripData?['destination'] ?? tripData?['to'] ?? '';

    // نحاول الاستعلام بصيغ متعددة للحقل tripId و createdAt
    QuerySnapshot bookingSnapshot;
    try {
      bookingSnapshot = await firestore
          .collection('bookings')
          .where('tripId', isEqualTo: tripId)
          .orderBy('createdAt', descending: true)
          .get();
      // إذا لم تُرجع نتائج، نجرب snake_case
      if (bookingSnapshot.docs.isEmpty) {
        bookingSnapshot = await firestore
            .collection('bookings')
            .where('trip_id', isEqualTo: tripId)
            .orderBy('created_at', descending: true)
            .get();
      }
    } catch (e) {
      // في حال فشل orderBy بسبب عدم وجود الحقل أو فهرس، نجرب بدون orderBy
      try {
        bookingSnapshot = await firestore.collection('bookings').where('tripId', isEqualTo: tripId).get();
        if (bookingSnapshot.docs.isEmpty) {
          bookingSnapshot = await firestore.collection('bookings').where('trip_id', isEqualTo: tripId).get();
        }
      } catch (e2) {
        debugPrint('DriverBookingsScreen._fetchBookingsWithTripInfo query error: $e / $e2');
        return [];
      }
    }

    final bookings = <Map<String, dynamic>>[];

    for (final doc in bookingSnapshot.docs) {
      try {
        final booking = Booking.fromDocument(doc);

        // جلب بيانات الراكب إن أمكن
        String passengerName = 'راكب غير معروف';
        if (booking.passengerId != null && booking.passengerId!.isNotEmpty) {
          try {
            final userDoc = await firestore.collection('users').doc(booking.passengerId).get();
            if (userDoc.exists) {
              final appUser = AppUser.fromDocument(userDoc);
              // استخدم الحقل المعروف nickname كخيار أول، وإلا احتفظ بالقيمة الافتراضية
              passengerName = appUser.nickname ?? passengerName;
            }
          } catch (e) {
            debugPrint('DriverBookingsScreen._fetchBookingsWithTripInfo user fetch error: $e');
          }
        }

        bookings.add({
          'booking': booking,
          'passengerName': passengerName,
          'tripTitle': tripTitle,
          'tripDestination': tripDestination,
        });
      } catch (e, st) {
        debugPrint('DriverBookingsScreen._parseBooking error: $e\n$st');
      }
    }

    return bookings;
  }

  Widget buildBookingCard(Map<String, dynamic> data) {
    final booking = data['booking'] as Booking;
    final passengerName = data['passengerName'] as String? ?? 'راكب غير معروف';
    final tripTitle = data['tripTitle'] as String? ?? 'رحلة';
    final tripDestination = data['tripDestination'] as String? ?? '';

    // تحويل آمن لحقل createdAt الموجود داخل نموذج الحجز
    final createdAtDt = _toDateTime(booking.createdAt);
    final createdAt = DateFormat('yyyy-MM-dd – HH:mm').format(createdAtDt);

    // دعم حالات متعددة للنص (عربي/إنجليزي)
    final status = booking.bookingStatus ?? '';
    final statusLower = status.toLowerCase();
    final bool isConfirmed = statusLower == 'مؤكد' || statusLower == 'confirmed';
    final statusColor = isConfirmed ? Colors.green : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🧑‍💼 $passengerName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('🪑 عدد المقاعد: ${booking.bookedSeatsCount ?? 0}'),
          const SizedBox(height: 4),
          Text('📌 حالة الحجز: ${booking.bookingStatus ?? '-'}', style: TextStyle(color: statusColor)),
          const SizedBox(height: 4),
          Text('💳 حالة الدفع: ${booking.paymentStatus ?? '-'}'),
          const SizedBox(height: 4),
          Text('📅 تاريخ الحجز: $createdAt'),
          const SizedBox(height: 8),
          Text('🛣️ الرحلة: $tripTitle → $tripDestination'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('يجب تسجيل الدخول لعرض الحجوزات')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزات الرحلة'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchBookingsWithTripInfo(widget.tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('جاري تحميل الحجوزات...', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            debugPrint('DriverBookingsScreen FutureBuilder error: ${snapshot.error}');
            return const Center(child: Text('حدث خطأ أثناء تحميل الحجوزات.'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('لا توجد حجوزات حالياً.', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final bookings = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) => buildBookingCard(bookings[index]),
          );
        },
      ),
    );
  }
}
