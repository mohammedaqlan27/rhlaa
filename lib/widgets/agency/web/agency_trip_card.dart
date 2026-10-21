// lib/widgets/agency/agency_trip_card.dart
import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/models/trip.dart'; // أو نموذج الرحلات الخاص بالوكالة
import '/widgets/shared/app_card.dart';

class AgencyTripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AgencyTripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الكارت: عنوان الرحلة والحالة مع أزرار الإدارة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  trip.title.isNotEmpty ? trip.title : '${trip.origin} إلى ${trip.destination}',
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
              // أزرار التعديل والحذف السريع الخاصة بالوكالة
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                      tooltip: 'تعديل الرحلة',
                      onPressed: onEdit,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      tooltip: 'حذف الرحلة',
                      onPressed: onDelete,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // تفاصيل السائق والمقاعد المتبقية
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.gray500),
              const SizedBox(width: 6),
              Text(
                'السائق: ${trip.driverName.isNotEmpty ? trip.driverName : 'غير محدد'}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? AppColors.gray400 : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'المقاعد: ${trip.availableSeats} / ${trip.totalSeats}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: trip.availableSeats > 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}