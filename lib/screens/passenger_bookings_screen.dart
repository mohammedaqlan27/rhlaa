// lib/screens/passenger_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import '../models/trip.dart';
import 'trip_details_screen.dart';

class PassengerBookingsScreen extends StatefulWidget {
  const PassengerBookingsScreen({super.key});

  @override
  State<PassengerBookingsScreen> createState() => _PassengerBookingsScreenState();
}

class _PassengerBookingsScreenState extends State<PassengerBookingsScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _bookingsFuture = _fetchBookings(userId);
    } else {
      _bookingsFuture = Future.value(<Map<String, dynamic>>[]);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBookings(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('passenger_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    final bookings = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final booking = Booking.fromDocument(doc);
      if (booking.tripId == null || booking.tripId!.isEmpty) continue;

      final tripSnapshot = await FirebaseFirestore.instance.collection('trips').doc(booking.tripId).get();

      if (tripSnapshot.exists) {
        final trip = Trip.fromDocument(tripSnapshot);
        bookings.add({
          'booking': booking,
          'trip': trip,
        });
      }
    }

    return bookings;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'تاريخ غير محدد';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildBookingCard(BuildContext context, Booking booking, Trip trip) {
    final formattedDate = _formatDate(trip.date);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🚗 ${trip.vehicleType} إلى ${trip.destination}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('🧑‍✈️ السائق: ${trip.driverName}'),
          Text('📅 التاريخ: $formattedDate'),
          Text('🕒 الوقت: ${trip.time}'),
          Text('🪑 عدد المقاعد المحجوزة: ${booking.bookedSeatsCount ?? 0}'),
          Text('📌 حالة الحجز: ${booking.bookingStatus ?? '-'}'),
          Text('💳 حالة الدفع: ${booking.paymentStatus ?? '-'}'),
          const SizedBox(height: 12),
          Row(
            children: [
              if ((booking.bookingStatus ?? '').toLowerCase() == 'مؤكد' || (booking.bookingStatus ?? '').toLowerCase() == 'confirmed')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('تأكيد الإلغاء'),
                          content: const Text('هل أنت متأكد أنك تريد إلغاء هذا الحجز؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('لا')),
                            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('نعم')),
                          ],
                        ),
                      );

                      if (confirm == true && userId != null) {
                        final result = await BookingService().cancelBooking(
                          bookingId: booking.bookingId,
                          passengerId: userId,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result == null ? '✅ تم إلغاء الحجز بنجاح' : '❌ فشل في إلغاء الحجز: $result',
                              ),
                            ),
                          );
                          setState(() {
                            _bookingsFuture = _fetchBookings(userId);
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('إلغاء الحجز'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              if ((booking.bookingStatus ?? '').toLowerCase() == 'مؤكد' || (booking.bookingStatus ?? '').toLowerCase() == 'confirmed')
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('تفاصيل الرحلة'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('❌ يجب تسجيل الدخول لعرض الحجوزات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزاتي'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
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

          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('لا توجد حجوزات حتى الآن.', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index]['booking'] as Booking;
              final trip = bookings[index]['trip'] as Trip;
              return _buildBookingCard(context, booking, trip);
            },
          );
        },
      ),
    );
  }
}
