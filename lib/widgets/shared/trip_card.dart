import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../theme/app_colors.dart';
import '../../models/trip.dart';
import 'app_card.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final Widget? actionButton;
  final bool showDriverInfo;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.actionButton,
    this.showDriverInfo = true,
  });

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return trip.time.isNotEmpty ? trip.time : 'غير محدد';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(dateTime);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'متاحة';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(trip.status);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category/Status Badges & Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(trip.status),
                      style: TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (trip.tripCategory.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trip.tripCategory,
                        style: TextStyle(
                          fontFamily: AppFonts.arabic,
                          fontSize: 12,
                          color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Price
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${trip.price.toStringAsFixed(0)} ',
                      style: TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: 'ر.ي',
                      style: TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Route Info (Origin -> Destination)
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.circle_outlined, size: 16, color: AppColors.primary),
                  Container(
                    width: 2,
                    height: 24,
                    color: isDark ? AppColors.gray700 : AppColors.gray300,
                  ),
                  const Icon(Icons.location_on, size: 16, color: AppColors.error),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.origin.isNotEmpty ? trip.origin : 'الانطلاق غير محدد',
                      style: TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      trip.destination.isNotEmpty ? trip.destination : 'الوجهة غير محدودة',
                      style: TextStyle(
                        fontFamily: AppFonts.arabic,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: isDark ? AppColors.webBorder : AppColors.gray200, height: 1),
          const SizedBox(height: 12),

          // Departure Date & Available Seats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Departure Date
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.gray500),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(trip.departureTime ?? trip.date),
                    style: TextStyle(
                      fontFamily: AppFonts.arabic,
                      fontSize: 12,
                      color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Seats
              Row(
                children: [
                  const Icon(Icons.event_seat_outlined, size: 16, color: AppColors.gray500),
                  const SizedBox(width: 6),
                  Text(
                    'المتبقي ${trip.availableSeats} من ${trip.totalSeats}',
                    style: TextStyle(
                      fontFamily: AppFonts.arabic,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trip.availableSeats > 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Driver Details (Optional)
          if (showDriverInfo && trip.driverName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.driverName,
                    style: TextStyle(
                      fontFamily: AppFonts.arabic,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trip.driverRating > 0) ...[
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    trip.driverRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontFamily: AppFonts.arabic,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Optional Action Button Slot
          if (actionButton != null) ...[
            const SizedBox(height: 12),
            actionButton!,
          ],
        ],
      ),
    );
  }
}