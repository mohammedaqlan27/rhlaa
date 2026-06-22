// lib/screens/trip_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';
import '../services/booking_service.dart';
import '../screens/payment_screen.dart';
import '../screens/auth_screen.dart';

class TripDetailsScreen extends StatelessWidget {
  final Trip trip;

  const TripDetailsScreen({super.key, required this.trip});

  // مُنشئ إضافي (Named Constructor) مرن لتعويض الملف المحذوف واستقبال البيانات الخام Map بسهولة
  factory TripDetailsScreen.fromMap({required Map<String, dynamic> map, String? docId}) {
    return TripDetailsScreen(
      trip: Trip(
        driverId: map['driverId']?.toString() ?? map['driver_id']?.toString() ?? '',
        title: map['title']?.toString() ?? 'رحلة مشتركة',
        description: map['description']?.toString() ?? '',
        driverName: map['driverName'] ?? map['driver_name']?.toString() ?? 'كابتن غير محدد',
        tripCategory: map['tripCategory'] ?? map['trip_category']?.toString() ?? 'داخلية',
        origin: map['origin']?.toString() ?? 'غير محدد',
        destination: map['destination']?.toString() ?? 'غير محدد',
        vehicleType: map['vehicleType'] ?? map['vehicle_type']?.toString() ?? 'صالون',
        totalSeats: map['totalSeats'] is int ? map['totalSeats'] : (int.tryParse('${map['totalSeats']}') ?? 4),
        availableSeats: map['availableSeats'] is int ? map['availableSeats'] : (int.tryParse('${map['availableSeats']}') ?? 0),
        departureTime: map['departureTime'] is Timestamp
            ? (map['departureTime'] as Timestamp).toDate()
            : (DateTime.tryParse(map['departureTime']?.toString() ?? '') ?? DateTime.now()),
        status: map['status']?.toString() ?? 'active',
        price: map['price'] is num ? (map['price'] as num).toDouble() : (double.tryParse('${map['price']}') ?? 0.0),
        carPlateNumber: map['carPlateNumber'] ?? map['car_plate_number']?.toString() ?? 'غير متوفر',
        carOwnerOfficialName: map['carOwnerOfficialName'] ?? map['car_owner_official_name']?.toString() ?? 'غير متوفر',
      ),
    );
  }

  // ثيمات وألوان هوية لوجو "رحلاء" الموحدة
  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _logoGreen = Color(0xFF4EBF64);
  static const Color _backgroundColor = Color(0xFFF8FAFC);

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

  bool _isStatusActive(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s == 'مفعّلة' || s == 'active' || s == 'مفعلة' || s == 'confirmed' || s == 'مؤكد' || s == 'نشطة';
  }

  Future<String?> _fetchLatestBookingId(String tripId, String passengerId) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('bookings')
          .where('tripId', isEqualTo: tripId)
          .where('passengerId', isEqualTo: passengerId)
          .where('bookingStatus', whereIn: ['مؤكد', 'confirmed', 'نشط'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) return q.docs.first.id;
      return null;
    } catch (e) {
      debugPrint('TripDetailsScreen._fetchLatestBookingId error: $e');
      return null;
    }
  }

  Widget _buildDetailTile({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _logoTeal.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child:  Icon(icon, color: _logoTeal, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistentBottomBar(BuildContext context) {
    BookingService? bookingService;
    try {
      bookingService = Provider.of<BookingService>(context, listen: false);
    } catch (_) {}

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final int availableSeats = trip.availableSeats ?? 0;
    final double price = trip.price ?? 0.0;

    // تصميم ذكي في حال لم يسجل المستخدم الدخول بعد
    if (uid == null) {
      return _buildBottomContainer(
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
          icon: const Icon(Icons.login_rounded),
          label: const Text('تسجيل الدخول لتتمكن من الحجز', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _logoBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      );
    }

    if (bookingService == null || !_isStatusActive(trip.status)) {
      return _buildBottomContainer(
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('الرحلة غير متاحة للحجز حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
        ),
      );
    }

    return _buildBottomContainer(
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تكلفة المقعد الواحد', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
              Text('${price.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: _logoGreen)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: availableSeats > 0 ? () => _handleBookingProcess(context, bookingService!, uid, price) : null,
              icon: const Icon(Icons.airline_seat_recline_normal_rounded),
              label: Text(availableSeats > 0 ? 'احجز مقعدك الآن' : 'ممتلئة بالكامل', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _logoBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -3))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(child: child),
    );
  }

  Future<void> _handleBookingProcess(BuildContext context, BookingService service, String uid, double price) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏳ جاري معالجة طلب الحجز المقعد...', style: TextStyle(fontFamily: 'Cairo'))));

    try {
      final errorMessage = await service.createBooking(
        tripId: trip.id ?? '',
        passengerId: uid,
        seatsToBook: 1,
        tripPricePerSeat: price,
        isFamilyBooking: false,
        childrenCount: 0,
      );

      if (!context.mounted) return;

      if (errorMessage == null) {
        final bookingId = await _fetchLatestBookingId(trip.id ?? '', uid);
        if (!context.mounted) return;

        Navigator.pushReplacement(
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل الحجز: $errorMessage', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ حدث خطأ غير متوقع: $e', style: const TextStyle(fontFamily: 'Cairo'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = _toDateTime(trip.departureTime);
    final formattedDate = DateFormat('yyyy/MM/dd | hh:mm a', 'ar').format(dt);
    final bool isActive = _isStatusActive(trip.status);
    final Color statusColor = isActive ? _logoGreen : Colors.red.shade400;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('تفاصيل الرحلة المتاحة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // كرت الواجهة والمظهر الجمالي للرحلة والوجهات السريعة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                trip.title ?? 'رحلة ركاب مشتركة',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                isActive ? 'نشطة ومتاحة' : (trip.status ?? 'غير متاح'),
                                style: TextStyle(fontFamily: 'Cairo', color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (trip.description != null && trip.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(trip.description!, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600)),
                        ],
                        const Divider(height: 28),

                        _buildDetailTile(icon: Icons.trip_origin_rounded, label: 'نقطة الانطلاق والتحرك', value: trip.origin ?? 'غير محددة'),
                        _buildDetailTile(icon: Icons.flag_rounded, label: 'وجهة الوصول النهائية', value: trip.destination ?? 'غير محددة'),
                        _buildDetailTile(icon: Icons.calendar_month_rounded, label: 'موعد وتاريخ التحرك المقدر', value: formattedDate),
                        _buildDetailTile(icon: Icons.person_pin_rounded, label: 'اسم الكابتن / السائق', value: trip.driverName ?? 'كابتن رحلاء المعين'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // كرت تفاصيل المركبة القانونية لضمان سلامة وأمان "رحلاء"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: _logoBlue, size: 18),
                            const SizedBox(width: 8),
                            Text('بيانات الأمان والمركبة القانونية', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildDetailTile(icon: Icons.directions_car_filled_rounded, label: 'نوع واسم المركبة', value: trip.vehicleType ?? 'غير معروفة'),
                        _buildDetailTile(icon: Icons.event_seat_rounded, label: 'وضعية المقاعد المتبقية', value: '${trip.availableSeats ?? 0} مقعد متاح حالياً (من أصل ${trip.totalSeats ?? 0})'),
                        _buildDetailTile(icon: Icons.tag_rounded, label: 'رقم لوحة المركبة الرسمية', value: trip.carPlateNumber ?? 'غير متوفرة'),
                        _buildDetailTile(icon: Icons.business_rounded, label: 'المالك الرسمي المقيد للمركبة', value: trip.carOwnerOfficialName ?? 'مسجلة وموثقة في معارض رحلاء'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // شريط الحجز السفلي التفاعلي الموحد والأنيق
          _buildPersistentBottomBar(context),
        ],
      ),
    );
  }
}