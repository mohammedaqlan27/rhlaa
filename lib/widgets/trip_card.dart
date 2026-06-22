// lib/widgets/trip_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import 'app_card.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final bool showPrice;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.showPrice = true,
  });

  // ألوان الهوية البصرية المعتمدة
  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _logoGreen = Color(0xFF4EBF64);

  String _formatSeats(Trip t) {
    final avail = t.availableSeats;
    final total = t.totalSeats;
    return '$avail / $total';
  }

  @override
  Widget build(BuildContext context) {
    // فحص حالة الرحلة للتلوين الديناميكي الذكي
    final bool isStatusActive =
        trip.status.toLowerCase() == 'active' || trip.status.contains('مفع');
    final String priceText = trip.price.toStringAsFixed(0);

    // تنسيق وقت المغادرة بشكل أنيق للمستخدم العربي
    final String formattedTime = trip.departureTime != null
        ? DateFormat('hh:mm a', 'ar').format(trip.departureTime!)
        : (trip.time ?? 'غير محدد');

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // السطر العلوي: اسم الرحلة / الكابتن وحالة الرحلة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _logoBlue.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car_filled_rounded,
                        color: _logoBlue, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (trip.title != null && trip.title!.isNotEmpty)
                        ? trip.title!
                        : 'رحلة تنقل',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              // حالة الرحلة
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isStatusActive
                      ? _logoGreen.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isStatusActive ? 'نشطة' : trip.status,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isStatusActive ? _logoGreen : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5, color: Color(0xFFCBD5E1)),

          // مسار الرحلة: من وإلى
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked_rounded,
                            size: 16, color: _logoTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.origin,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 7),
                      child: SizedBox(
                          height: 8,
                          child: VerticalDivider(
                              width: 2,
                              thickness: 1.5,
                              color: Colors.black12)),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 16, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.destination,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // السعر
              if (showPrice)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _logoBlue,
                      ),
                    ),
                    const Text(
                      'ريال يمني',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: Colors.black38,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5, color: Color(0xFFCBD5E1)),

          // المقاعد والوقت
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_seat_rounded,
                      size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(
                    'المقاعد المتاحة: ${_formatSeats(trip)}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded,
                      size: 16, color: _logoTeal),
                  const SizedBox(width: 6),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: _logoTeal,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
