// lib/screens/my_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../services/booking_service.dart';
import '../screens/rating_screen.dart';
import '../models/booking_model.dart';
import '../models/trip.dart';
import '../widgets/trip_card.dart';
import 'trip_details_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  bool _isCancelling = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _fetchBookings();
  }

  Future<void> _refresh() async {
    setState(() {
      _bookingsFuture = _fetchBookings();
      _errorMessage = null;
    });
    await _bookingsFuture;
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      if (value is DateTime) return value;
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate() as DateTime;
      }
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    } catch (_) {}
    return DateTime.now();
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    try {
      final bookingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      final bookings = <Map<String, dynamic>>[];

      for (var doc in bookingSnapshot.docs) {
        try {
          final booking = Booking.fromDocument(doc);
          final tripId = booking.tripId;
          if (tripId == null || tripId.isEmpty) continue;

          final tripSnapshot = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
          if (!tripSnapshot.exists) continue;

          final trip = Trip.fromDocument(tripSnapshot);
          bookings.add({'booking': booking, 'trip': trip});
        } catch (e, st) {
          debugPrint('MyBookingsScreen._fetchBookings parse error: $e\n$st');
        }
      }

      return bookings;
    } catch (e, st) {
      debugPrint('MyBookingsScreen._fetchBookings error: $e\n$st');
      return [];
    }
  }

  String _formatDateSafe(dynamic dateValue) {
    try {
      final dt = _toDate(dateValue);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  bool _isConfirmed(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s == 'مؤكد' || s == 'confirmed';
  }

  bool _isCompleted(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s == 'مكتملة' || s == 'completed' || s == 'complete';
  }

  Future<void> _confirmAndCancel(BuildContext context, Booking booking) async {
    final bookingService = Provider.of<BookingService>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد أنك تريد إلغاء هذا الحجز؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('لا')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('نعم')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final result = await bookingService.cancelBooking(
        bookingId: booking.bookingId,
        passengerId: uid,
      );

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إلغاء الحجز بنجاح')));
        await _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل في إلغاء الحجز: $result')));
      }
    } catch (e, st) {
      debugPrint('MyBookingsScreen.cancel error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ حدث خطأ أثناء الإلغاء: $e')));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _buildBookingCard(BuildContext context, Booking booking, Trip trip) {
    final theme = Theme.of(context);
    final formattedDate = _formatDateSafe(trip.date);

    final statusColor = _isConfirmed(booking.bookingStatus)
        ? Colors.orange
        : _isCompleted(booking.bookingStatus)
            ? Colors.green
            : theme.colorScheme.onSurface.withOpacity(0.6);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Icon(Icons.event, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(trip.title ?? 'رحلة', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  booking.bookingStatus ?? '-',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('الوجهة: ${trip.destination ?? '-'}', style: theme.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 6),
              Text('التاريخ: $formattedDate', style: theme.textTheme.bodySmall),
              const Spacer(),
              Icon(Icons.event_seat, color: theme.colorScheme.secondary, size: 18),
              const SizedBox(width: 6),
              Text('عدد المقاعد: ${booking.bookedSeatsCount}', style: theme.textTheme.bodySmall),
            ],
          ),

          const SizedBox(height: 10),
          if (booking.seatNumber != null || (booking.paymentMethod != null && booking.paymentMethod!.isNotEmpty))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.04)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (booking.seatNumber != null)
                  Row(
                    children: [
                      Icon(Icons.event_seat, color: theme.colorScheme.secondary, size: 18),
                      const SizedBox(width: 8),
                      Text('رقم المقعد: ${booking.seatNumber}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                if (booking.paymentMethod != null && booking.paymentMethod!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: theme.colorScheme.secondary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('طريقة الدفع: ${booking.paymentMethod}', style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
              ]),
            ),

          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
                },
                icon: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                label: Text('تفاصيل الرحلة', style: TextStyle(color: theme.colorScheme.primary)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              if (_isConfirmed(booking.bookingStatus))
                ElevatedButton.icon(
                  onPressed: _isCancelling ? null : () => _confirmAndCancel(context, booking),
                  icon: const Icon(Icons.cancel),
                  label: const Text('إلغاء الحجز'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              if (_isCompleted(booking.bookingStatus))
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(
                      tripId: trip.id ?? '',
                      targetUserId: trip.driverId ?? '',
                      userType: 'سائق',
                    )));
                  },
                  icon: const Icon(Icons.star),
                  label: const Text('تقييم السائق'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  final data = 'Booking ID: ${booking.bookingId}';
                  Clipboard.setData(ClipboardData(text: data));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الحجز')));
                },
                icon: Icon(Icons.copy, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                tooltip: 'نسخ رقم الحجز',
              ),
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلاتي'),
        backgroundColor: theme.colorScheme.primary,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: theme.colorScheme.primary,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
                  const SizedBox(height: 12),
                  Center(child: Text('جاري تحميل الحجوزات...', style: theme.textTheme.bodyLarge)),
                ],
              );
            }

            if (snapshot.hasError) {
              debugPrint('MyBookingsScreen FutureBuilder error: ${snapshot.error}');
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                  Center(child: Text('حدث خطأ أثناء تحميل الحجوزات.', style: theme.textTheme.bodyLarge)),
                  const SizedBox(height: 8),
                  Center(
                    child: ElevatedButton(
                      onPressed: _refresh,
                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                      child: const Text('حاول مرة أخرى'),
                    ),
                  ),
                ],
              );
            }

            final bookings = snapshot.data ?? [];
            if (bookings.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: Icon(Icons.event_busy, size: 60, color: theme.colorScheme.onSurface.withOpacity(0.2))),
                  const SizedBox(height: 10),
                  Center(child: Text('لا توجد حجوزات حتى الآن.', style: theme.textTheme.bodyLarge)),
                ],
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
      ),
    );
  }
}
