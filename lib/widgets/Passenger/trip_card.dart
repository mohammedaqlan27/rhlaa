// lib/widgets/trip_card.dart (نسخة مؤقتة محمية من null)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../../theme/app_colors.dart';
import '../shared/app_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String status = (trip.status ?? 'غير معروف').toString();
    final bool isStatusActive = status.toLowerCase().contains('active') || status.contains('مفع');

    final int availableSeats = trip.availableSeats ?? 0;
    final bool isLowSeats = availableSeats <= 1;

    final DateTime? dt = trip.departureTime;
    final String formattedTime = dt != null
        ? DateFormat('hh:mm a', 'ar').format(dt)
        : (trip.time ?? 'غير محدد');

    final double price = trip.price ?? 0.0;
    final String title = (trip.title != null && trip.title!.isNotEmpty) ? trip.title! : 'رحلة تنقل مباشر';
    final String origin = trip.origin ?? 'غير معروف';
    final String destination = trip.destination ?? 'غير معروف';

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildCategoryIcon(context),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(isStatusActive, status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoutePath(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCityName(origin, isDark),
                      const SizedBox(height: 24),
                      _buildCityName(destination, isDark),
                    ],
                  ),
                ),
                if (showPrice) _buildPriceSection(context, price),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : AppColors.gray100.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  Icons.event_seat_rounded,
                  '$availableSeats مقاعد متاحة',
                  isLowSeats ? AppColors.error : AppColors.textSecondary,
                ),
                _buildInfoItem(
                  Icons.access_time_filled_rounded,
                  formattedTime,
                  AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_car_filled_rounded, color: AppColors.primary, size: 20),
    );
  }

  Widget _buildStatusBadge(bool isActive, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.gray200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        isActive ? 'نشطة الآن' : status,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildRoutePath(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.radio_button_checked_rounded, size: 18, color: AppColors.secondary),
        Container(
          width: 2,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.secondary, Colors.redAccent.withOpacity(0.5)],
            ),
          ),
        ),
        const Icon(Icons.location_on_rounded, size: 18, color: Colors.redAccent),
      ],
    );
  }

  Widget _buildCityName(String name, bool isDark) {
    return Text(
      name,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : AppColors.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPriceSection(BuildContext context, double price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              price.toStringAsFixed(0),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'ر.ي',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const Text(
          'للمقعد الواحد',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
