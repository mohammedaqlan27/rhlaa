// lib/widgets/agency/agency_booking_card.dart
import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/widgets/shared/app_card.dart';

class AgencyBookingCard extends StatelessWidget {
  final String bookingId;
  final String passengerName;
  final String tripTitle;
  final int seatsCount;
  final double totalPrice;
  final String status;
  final VoidCallback? onTap;

  const AgencyBookingCard({
    super.key,
    required this.bookingId,
    required this.passengerName,
    required this.tripTitle,
    required this.seatsCount,
    required this.totalPrice,
    required this.status,
    this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'مؤكد':
      case 'confirmed':
        return Colors.green;
      case 'قيد الانتظار':
      case 'pending':
        return Colors.orange;
      case 'ملغى':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(status);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'رقم الحجز: #$bookingId',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            passengerName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.route, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tripTitle,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: isDark ? AppColors.gray300 : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عدد المقاعد: $seatsCount',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                ),
              ),
              Text(
                '${totalPrice.toStringAsFixed(2)} ريال',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
