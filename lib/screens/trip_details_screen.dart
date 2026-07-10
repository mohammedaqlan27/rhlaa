// lib/screens/trip_details_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../providers/booking_provider.dart';
import '../screens/payment_screen.dart';
import '../screens/auth_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  int? _selectedSeatIndex;
  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoGreen = Color(0xFF4EBF64);

  Future<void> _handleBooking() async {
    if (_selectedSeatIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مقعد أولاً', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    // منع النقرات المتكررة إذا الـ Provider مشغول
    if (bookingProvider.isLoading) return;

    // استدعاء الحجز عبر الـ Provider (root bookings)
    final bookingId = await bookingProvider.createNewBooking(
      tripId: widget.trip.id,
      passengerId: user.uid,
      seatsCount: 1,
      pricePerSeat: widget.trip.price ?? 0, paymentMethod: '',
      // يمكنك تمرير isFamily, children, notes إن لزم
    );

    if (!mounted) return;

    if (bookingId != null) {
      // نجاح: انتقل لصفحة الدفع
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            tripId: widget.trip.id,
            bookingId: bookingId,
            seatNumber: _selectedSeatIndex! + 1,
            amount: (widget.trip.price ?? 0).toString(),
          ),
        ),
      );
    } else {
      // فشل: عرض رسالة الخطأ من الـ Provider أو رسالة عامة
      final msg = bookingProvider.errorMessage ?? 'حدث خطأ أثناء الحجز. حاول مرة أخرى.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final isBooking = bookingProvider.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('تفاصيل الرحلة وحجز المقاعد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTripInfoCard(),
                  const SizedBox(height: 20),
                  const Text('اختر مقعدك المفضل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildSeatGrid(isBooking),
                  if (bookingProvider.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(bookingProvider.errorMessage!, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomAction(isBooking),
        ],
      ),
    );
  }

  Widget _buildTripInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.location_on, 'من', widget.trip.origin),
          const Divider(),
          _buildInfoRow(Icons.flag, 'إلى', widget.trip.destination),
          const Divider(),
          _buildInfoRow(
            Icons.access_time,
            'الوقت',
            DateFormat('hh:mm a', 'ar').format(widget.trip.departureTime ?? DateTime.now()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _logoBlue, size: 20),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
        Text(value, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSeatGrid(bool isBooking) {
    final seatStatus = widget.trip.seatStatus;
    final total = widget.trip.totalSeats;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: total,
        itemBuilder: (context, index) {
          final bool isBooked = (index < seatStatus.length) ? !seatStatus[index] : false;
          final bool isSelected = _selectedSeatIndex == index;

          return GestureDetector(
            onTap: isBooked || isBooking ? null : () {
              setState(() => _selectedSeatIndex = index);
            },
            child: Container(
              decoration: BoxDecoration(
                color: isBooked ? Colors.grey.shade300 : (isSelected ? _logoGreen : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? _logoGreen : Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.airline_seat_recline_normal, color: isBooked ? Colors.grey : (isSelected ? Colors.white : _logoBlue)),
                  const SizedBox(height: 6),
                  Text('مقعد ${index + 1}', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomAction(bool isBooking) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        children: [
          Text('${widget.trip.price ?? 0} ر.ي', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _logoGreen)),
          const Spacer(),
          ElevatedButton(
            onPressed: isBooking ? null : _handleBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: _logoBlue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isBooking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('تأكيد الحجز', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
