import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../providers/booking_provider.dart'; // استخدام البروفايدر بدلاً من السيرفس مباشرة
import '../screens/payment_screen.dart';
import '../screens/auth_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  int? _selectedSeatIndex; // لتخزين المقعد الذي اختاره المستخدم

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoGreen = Color(0xFF4EBF64);

  // دالة معالجة الحجز باستخدام البروفايدر
  Future<void> _handleBooking() async {
    if (_selectedSeatIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار مقعد أولاً', style: TextStyle(fontFamily: 'Cairo')))
      );
      return;
    }

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }

    // إظهار مؤشر تحميل
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final bookingId = await bookingProvider.createNewBooking(
      tripId: widget.trip.id,
      passengerId: user.uid,
      seatsCount: 1,
      pricePerSeat: widget.trip.price,
    );

    Navigator.pop(context); // إغلاق مؤشر التحميل

    if (bookingId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(
        tripId: widget.trip.id,
        bookingId: bookingId,
        seatNumber: _selectedSeatIndex! + 1, amount: '',
      )));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bookingProvider.errorMessage ?? 'فشل الحجز'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _buildSeatGrid(), // واجهة اختيار المقاعد الجديدة
                ],
              ),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildTripInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          _buildInfoRow(Icons.location_on, 'من', widget.trip.origin),
          const Divider(),
          _buildInfoRow(Icons.flag, 'إلى', widget.trip.destination),
          const Divider(),
          _buildInfoRow(
              Icons.access_time,
              'الوقت',
              // نستخدم DateFormat مع التأكد من أن الوقت موجود، وإذا لم يوجد نضع الوقت الحالي
              DateFormat('hh:mm a', 'ar').format(widget.trip.departureTime ?? DateTime.now())
          ),        ],
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

  // واجهة اختيار المقاعد التفاعلية
  Widget _buildSeatGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1, crossAxisSpacing: 20, mainAxisSpacing: 20),
        itemCount: widget.trip.totalSeats,
        itemBuilder: (context, index) {
          // التحقق من حالة المقعد من مصفوفة seatStatus في الموديل
          bool isBooked = !widget.trip.seatStatus[index];
          bool isSelected = _selectedSeatIndex == index;

          return GestureDetector(
            onTap: isBooked ? null : () => setState(() => _selectedSeatIndex = index),
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
                  Text('مقعد ${index + 1}', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        children: [
          Text('${widget.trip.price} ر.ي', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _logoGreen)),
          const Spacer(),
          ElevatedButton(
            onPressed: _handleBooking,
            style: ElevatedButton.styleFrom(backgroundColor: _logoBlue, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('تأكيد الحجز', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}