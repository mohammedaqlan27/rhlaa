// lib/screens/trip_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';
import '../services/booking_service.dart';
import '../screens/payment_screen.dart';

class TripDetailsScreen extends StatelessWidget {
  final Trip trip;

  const TripDetailsScreen({super.key, required this.trip});

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      if (value is DateTime) return value;
      if (value.runtimeType.toString().contains('Timestamp')) {
        final toDate = (value as dynamic).toDate();
        if (toDate is DateTime) return toDate;
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
    } catch (_) {}
    return DateTime.now();
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 14,
                    )),
                const SizedBox(height: 4),
                Text(value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isStatusActive(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s == 'مفعّلة' || s == 'active' || s == 'مفعلة';
  }

  Future<String?> _fetchLatestBookingId(String tripId, String passengerId) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('bookings')
          .where('tripId', isEqualTo: tripId)
          .where('passengerId', isEqualTo: passengerId)
          .where('bookingStatus', whereIn: ['مؤكد', 'confirmed'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) return q.docs.first.id;

      final q2 = await FirebaseFirestore.instance
          .collection('bookings')
          .where('trip_id', isEqualTo: tripId)
          .where('passenger_id', isEqualTo: passengerId)
          .where('booking_status', whereIn: ['مؤكد', 'confirmed'])
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (q2.docs.isNotEmpty) return q2.docs.first.id;
      return null;
    } catch (e, st) {
      debugPrint('TripDetailsScreen._fetchLatestBookingId error: $e\n$st');
      return null;
    }
  }

  Widget _buildBookButton(BuildContext context) {
    final bookingService = Provider.of<BookingService>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    if (uid == null || !_isStatusActive(trip.status)) return const SizedBox();

    final int availableSeats = trip.availableSeats ?? 0;
    final double price = trip.price ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: availableSeats > 0
            ? () async {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري محاولة حجز المقعد...')),
                );

                try {
                  final errorMessage = await bookingService.createBooking(
                    tripId: trip.id ?? '',
                    passengerId: uid,
                    seatsToBook: 1,
                    tripPricePerSeat: price,
                    isFamilyBooking: false,
                    childrenCount: 0,
                  );

                  if (!context.mounted) return;

                  if (errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم حجز المقعد بنجاح')),
                    );

                    final bookingId = await _fetchLatestBookingId(trip.id ?? '', uid);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          tripId: trip.id ?? '',
                          seatNumber: 1,
                          bookingId: bookingId ?? '',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ فشل في الحجز: $errorMessage')),
                    );
                  }
                } catch (e, st) {
                  debugPrint('TripDetailsScreen.booking error: $e\n$st');
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ حدث خطأ أثناء الحجز: $e')),
                  );
                }
              }
            : null,
        icon: const Icon(Icons.event_seat),
        label: Text(
          availableSeats > 0
              ? 'حجز المقعد - ${price.toStringAsFixed(2)}ريال'
              : 'لا توجد مقاعد متاحة',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: availableSeats > 0
              ? theme.colorScheme.primary
              : Colors.grey,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = _toDateTime(trip.departureTime);
    final formattedDate = DateFormat('yyyy/MM/dd | HH:mm').format(dt);
    final statusColor = _isStatusActive(trip.status)
        ? Colors.green
        : theme.colorScheme.error;
    final titleText = (trip.title ?? 'رحلة').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الرحلة'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // العنوان والحالة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              titleText,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              trip.status ?? '',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30),

                      // تفاصيل الرحلة الأساسية
                      _buildDetailRow(context, Icons.place, 'الانطلاق', trip.origin ?? 'غير معروف'),
                      _buildDetailRow(context, Icons.flag, 'الوجهة', trip.destination ?? 'غير معروف'),
                      _buildDetailRow(context, Icons.access_time, 'التاريخ والوقت', formattedDate),
                      _buildDetailRow(context, Icons.person, 'السائق', trip.driverName ?? 'غير معروف'),

                      const Divider(height: 30),

                      // تفاصيل الحجز والمركبة
                      _buildDetailRow(context, Icons.event_seat, 'المقاعد المتاحة', '${trip.availableSeats ?? 0} من ${trip.totalSeats ?? 0}'),
                      _buildDetailRow(context, Icons.attach_money, 'سعر المقعد', '${(trip.price ?? 0.0).toStringAsFixed(2)} ريال'),
                      _buildDetailRow(context, Icons.directions_car, 'نوع المركبة', trip.vehicleType ?? 'غير معروف'),
                      _buildDetailRow(context, Icons.confirmation_number, 'رقم اللوحة', trip.carPlateNumber ?? 'غير متوفر'),
                      _buildDetailRow(context, Icons.business, 'اسم مالك المركبة / المعرض', trip.carOwnerOfficialName )
                    ],
                  ),
                ),
              ),
            ),
          ),

          // زر الحجز
          _buildBookButton(context),
        ],
      ),
    );
  }
}
