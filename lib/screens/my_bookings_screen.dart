// lib/screens/my_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../services/booking_service.dart';
import '../screens/rating_screen.dart';
import '../models/booking_model.dart';
import '../models/trip.dart';
import '../widgets/app_card.dart';
import 'trip_details_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  bool _isCancelling = false;

  final Color _primaryColor = const Color(0xFF4A7DAB);
  final Color _backgroundColor = const Color(0xFFF4F7FA);

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _fetchBookings();
  }

  Future<void> _refresh() async {
    setState(() {
      _bookingsFuture = _fetchBookings();
    });
    await _bookingsFuture;
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    } catch (_) {}
    return DateTime.now();
  }

  /// جلب الحجوزات الخاصة بالمستخدم. نعيد قائمة من الخرائط:
  /// { 'booking': Booking, 'tripId': String, 'raw': Map<String,dynamic> }
  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final List<Map<String, dynamic>> allBookings = [];

    try {
      // 1. camelCase
      final camelSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in camelSnapshot.docs) {
        final bData = _parseBookingDoc(doc);
        if (bData != null) allBookings.add(bData);
      }

      // 2. snake_case (توافق رجعي)
      final snakeSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passenger_id', isEqualTo: uid)
          .orderBy('created_at', descending: true)
          .get();

      for (var doc in snakeSnapshot.docs) {
        if (!allBookings.any((element) => (element['booking'] as Booking).id == doc.id)) {
          final bData = _parseBookingDoc(doc);
          if (bData != null) allBookings.add(bData);
        }
      }

      return allBookings;
    } catch (e, st) {
      debugPrint('MyBookingsScreen._fetchBookings error: $e\n$st');
      return [];
    }
  }

  /// نحاول تحويل المستند إلى Booking ونُعيد أيضاً بيانات المستند الخام
  Map<String, dynamic>? _parseBookingDoc(DocumentSnapshot doc) {
    try {
      final booking = Booking.fromDocument(doc);
      final tripId = booking.tripId;
      if (tripId.isEmpty) return null;

      final raw = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      return {'booking': booking, 'tripId': tripId, 'raw': raw};
    } catch (e, st) {
      debugPrint('Error parsing booking doc: $e\n$st');
      return null;
    }
  }

  /// جلب بيانات الرحلات المرتبطة بالحجوزات
  Future<List<Map<String, dynamic>>> _populateTripsData(List<Map<String, dynamic>> partialBookings) async {
    final List<Map<String, dynamic>> fullData = [];
    for (var item in partialBookings) {
      try {
        final tripSnapshot = await FirebaseFirestore.instance.collection('trips').doc(item['tripId']).get();
        if (tripSnapshot.exists) {
          final trip = Trip.fromDocument(tripSnapshot);
          fullData.add({
            'booking': item['booking'] as Booking,
            'trip': trip,
            'raw': item['raw'] as Map<String, dynamic>,
          });
        } else {
          // إذا لم توجد الرحلة، نضيف الحجز مع trip = null لتتم معالجته لاحقاً
          fullData.add({
            'booking': item['booking'] as Booking,
            'trip': null,
            'raw': item['raw'] as Map<String, dynamic>,
          });
        }
      } catch (e, st) {
        debugPrint('Error populating trip details: $e\n$st');
      }
    }
    return fullData;
  }

  String _formatDateSafe(dynamic dateValue) {
    try {
      final dt = _toDate(dateValue);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'تاريخ غير محدد';
    }
  }

  bool _isConfirmed(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase().trim();
    return s == 'مؤكد' || s == 'confirmed' || s == 'نشط' || s == 'active';
  }

  bool _isCompleted(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase().trim();
    return s == 'مكتملة' || s == 'completed' || s == 'complete' || s == 'مكتمل';
  }

  Future<void> _confirmAndCancel(BuildContext context, Booking booking) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد أنك تريد إلغاء هذا الحجز واسترداد المقاعد؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final result = await BookingService().cancelBooking(
        bookingId: booking.id,
        passengerId: uid,
      );

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إلغاء الحجز بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
        await _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل إلغاء الحجز: $result', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ حدث خطأ غير متوقع: $e')));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _buildBookingCard(BuildContext context, Booking booking, Trip? trip, Map<String, dynamic> raw) {
    final formattedDate = _formatDateSafe(trip?.date);

    Color statusColor = Colors.grey;
    if (_isConfirmed(booking.bookingStatus)) statusColor = Colors.orange.shade700;
    if (_isCompleted(booking.bookingStatus)) statusColor = Colors.green.shade700;
    final lowerStatus = booking.bookingStatus.toLowerCase();
    if (lowerStatus.contains('ملغي') || lowerStatus.contains('cancel')) statusColor = Colors.red.shade700;

    final destinationText = (trip?.destination != null && trip!.destination.isNotEmpty) ? trip.destination : 'وجهة غير محددة';
    final driverNameText = (trip?.driverName != null && trip!.driverName.isNotEmpty) ? trip!.driverName : 'غير معروف';

    // استخراج معلومات اختيارية من raw (إن وُجدت)
    final List<dynamic>? seatIndexesRaw = raw['seatIndexes'] as List<dynamic>?;
    final String? paymentMethodRaw = raw['paymentMethod']?.toString();
    final List<int> seatIndexes = seatIndexesRaw != null ? seatIndexesRaw.map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? -1).where((i) => i >= 0).toList() : [];

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car_filled_outlined, color: _primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'رحلة إلى $destinationText',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.bookingStatus,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text('🧑‍✈️ الكابتن: $driverNameText', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('التاريخ: $formattedDate', style: TextStyle(fontSize: 12, color: Colors.black, fontFamily: 'Cairo')),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.event_seat_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('المقاعد: ${booking.bookedSeatsCount}', style: TextStyle(fontSize: 12, color: Colors.black, fontFamily: 'Cairo')),
                  ],
                )
              ],
            ),
            if (seatIndexes.isNotEmpty || (paymentMethodRaw != null && paymentMethodRaw.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (seatIndexes.isNotEmpty)
                      Text('💺 المقاعد المحجوزة: ${seatIndexes.map((i) => (i + 1).toString()).join(', ')}', style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.black87)),
                    if (paymentMethodRaw != null && paymentMethodRaw.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('💳 طريقة الدفع: $paymentMethodRaw', style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.black54)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: _primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: trip != null ? () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
                    } : null,
                    child: Text('تفاصيل الرحلة', style: TextStyle(color: _primaryColor, fontFamily: 'Cairo', fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isConfirmed(booking.bookingStatus))
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isCancelling ? null : () => _confirmAndCancel(context, booking),
                      child: const Text('إلغاء الحجز', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white)),
                    ),
                  ),
                if (_isCompleted(booking.bookingStatus))
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (trip != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(
                            tripId: trip.id,
                            targetUserId: trip.driverId,
                            userType: 'سائق',
                          )));
                        }
                      },
                      child: const Text('تقييم السائق', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white)),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: booking.id));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 تم نسخ رقم الحجز بنجاح')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.grey),
                  tooltip: 'نسخ رقم الحجز',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('رحلاتي المحجوزة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _primaryColor,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _primaryColor));
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 140),
                  const Center(child: Icon(Icons.error_outline_rounded, size: 48, color: Colors.red)),
                  const SizedBox(height: 12),
                  const Center(child: Text('حدث خطأ أثناء جلب تفاصيل الحجوزات', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
                  const SizedBox(height: 8),
                  Center(
                    child: ElevatedButton(
                      onPressed: _refresh,
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                      child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  )
                ],
              );
            }

            final partialList = snapshot.data ?? [];
            if (partialList.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  Center(child: Icon(Icons.calendar_today_outlined, size: 54, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  const Center(child: Text('لا توجد لديك أي حجوزات حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                ],
              );
            }

            // تحميل بيانات الرحلات الكاملة متزامنة مع الحجوزات
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _populateTripsData(partialList),
              builder: (context, tripSnapshot) {
                if (tripSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _primaryColor));
                }

                final fullList = tripSnapshot.data ?? [];
                if (fullList.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 140),
                      Center(child: Icon(Icons.bus_alert_rounded, size: 54, color: Colors.grey.shade400)),
                      const SizedBox(height: 12),
                      const Center(child: Text('عذراً، لم نجد بيانات الرحلات التابعة لحجوزاتك', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: fullList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final booking = fullList[index]['booking'] as Booking;
                    final trip = fullList[index]['trip'] as Trip?;
                    final raw = fullList[index]['raw'] as Map<String, dynamic>;
                    return _buildBookingCard(context, booking, trip, raw);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
