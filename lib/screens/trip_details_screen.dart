import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../providers/booking_provider.dart';
import '../screens/payment_screen.dart';
import '../screens/auth_screen.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart' as app_constants;

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  int? _selectedSeatIndex;

  bool get _hasAvailableSeats => widget.trip.availableSeats > 0;

  Future<void> _handleBooking() async {
    if (_selectedSeatIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مقعد أولاً', style: TextStyle(fontFamily: AppFonts.arabic)),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    if (bookingProvider.isLoading) return;

    final bookingId = await bookingProvider.createNewBooking(
      tripId: widget.trip.id,
      passengerId: user.uid,
      seatsCount: 1,
      pricePerSeat: widget.trip.price,
      paymentMethod: '',
    );

    if (!mounted) return;

    if (bookingId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            tripId: widget.trip.id,
            bookingId: bookingId,
            seatNumber: _selectedSeatIndex! + 1,
            amount: widget.trip.price.toStringAsFixed(0),
          ),
        ),
      );
    } else {
      final msg = bookingProvider.errorMessage ?? 'حدث خطأ أثناء الحجز. حاول مرة أخرى.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontFamily: AppFonts.arabic))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final isBooking = bookingProvider.isLoading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        appBar: AppBar(
          title: const Text(
            'تفاصيل الرحلة وحجز المقاعد',
            style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
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
                    _buildTripInfoCard(context),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اختر مقعدك المفضل',
                        style: TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSeatLegend(),
                    const SizedBox(height: 10),
                    _buildSeatGrid(isBooking),
                    if (bookingProvider.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        bookingProvider.errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontFamily: AppFonts.arabic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildBottomAction(isBooking),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfoCard(BuildContext context) {
    final dt = widget.trip.departureTime;
    final timeText = dt != null ? DateFormat.jm('ar').format(dt) : (widget.trip.time.isNotEmpty ? widget.trip.time : 'غير محدد');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(app_constants.AppConstants.borderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.location_on, 'من', widget.trip.origin),
          const Divider(),
          _buildInfoRow(Icons.flag, 'إلى', widget.trip.destination),
          const Divider(),
          _buildInfoRow(Icons.access_time, 'الوقت', timeText),
          const Divider(),
          _buildInfoRow(Icons.directions_car, 'نوع المركبة', widget.trip.vehicleType.isNotEmpty ? widget.trip.vehicleType : 'غير محدد'),
          const Divider(),
          _buildInfoRow(Icons.person, 'السائق', widget.trip.driverName.isNotEmpty ? widget.trip.driverName : 'غير معروف'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontFamily: AppFonts.arabic, color: AppColors.gray500)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _legendItem(Colors.white, 'متاح'),
        const SizedBox(width: 12),
        _legendItem(AppColors.gray300, 'محجوز'),
        const SizedBox(width: 12),
        _legendItem(AppColors.success, 'مختار'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.gray300),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: AppFonts.arabic, fontSize: 12)),
      ],
    );
  }

  Widget _buildSeatGrid(bool isBooking) {
    final seatStatus = widget.trip.seatStatus;
    final total = widget.trip.totalSeats;
    final availableSeats = widget.trip.availableSeats;

    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('لا توجد معلومات عن المقاعد', style: TextStyle(fontFamily: AppFonts.arabic))),
      );
    }

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (width > 900) {
      crossAxisCount = 4;
    } else if (width > 600) {
      crossAxisCount = 3;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text('المقاعد المتاحة: $availableSeats', style: const TextStyle(fontFamily: AppFonts.arabic, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: total,
            itemBuilder: (context, index) {
              final bool isBooked = index < seatStatus.length ? !seatStatus[index] : false;
              final bool isSelected = _selectedSeatIndex == index;

              final bgColor = isBooked
                  ? AppColors.gray300
                  : (isSelected ? AppColors.success : Theme.of(context).canvasColor);
              final borderColor = isSelected ? AppColors.success : AppColors.gray300;
              final iconColor = isBooked ? AppColors.gray500 : (isSelected ? Colors.white : AppColors.primary);
              final textColor = isSelected ? Colors.white : AppColors.textPrimary;

              return Semantics(
                button: true,
                enabled: !isBooked && !isBooking,
                label: 'مقعد ${index + 1} ${isBooked ? "محجوز" : isSelected ? "مختار" : "متاح"}',
                child: GestureDetector(
                  onTap: isBooked || isBooking
                      ? null
                      : () {
                    setState(() => _selectedSeatIndex = index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.airline_seat_recline_normal, color: iconColor),
                        const SizedBox(height: 6),
                        Text(
                          'مقعد ${index + 1}',
                          style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 12, color: textColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(bool isBooking) {
    final price = widget.trip.price;
    final priceText = NumberFormat.decimalPattern('ar').format(price);
    final canBook = _hasAvailableSeats && !isBooking;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$priceText ر.ي', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
              const SizedBox(height: 4),
              const Text('للمقعد الواحد', style: TextStyle(fontFamily: AppFonts.arabic, fontSize: 12, color: AppColors.gray500)),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: canBook ? _handleBooking : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canBook ? AppColors.primary : AppColors.gray400,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isBooking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
              _hasAvailableSeats ? 'تأكيد الحجز' : 'لا توجد مقاعد',
              style: const TextStyle(fontFamily: AppFonts.arabic, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}