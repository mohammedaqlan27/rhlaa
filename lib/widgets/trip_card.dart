// lib/widgets/trip_card.dart
import 'package:flutter/material.dart';
import '../models/trip.dart';

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

  String _formatSeats(Trip t) {
    final avail = t.availableSeats ?? 0;
    final total = t.totalSeats ?? 0;
    return '$avail / $total';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusActive = (trip.status ?? '').toLowerCase().contains('مفع');
    final priceText = (trip.price ?? 0.0).toStringAsFixed(2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              // Left: icon / vehicle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.directions_car, color: theme.colorScheme.primary, size: 32),
              ),
              const SizedBox(width: 12),

              // Middle: details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.title ?? 'رحلة', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${trip.origin ?? 'غير معروف'} → ${trip.destination ?? 'غير معروف'}', style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.event_seat, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(_formatSeats(trip), style: theme.textTheme.bodySmall),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(trip.departureTime != null ? trip.departureTime.toString().split('.').first : '-', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: price & status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showPrice)
                    Text('$priceText ر.س', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusActive ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      trip.status ?? '',
                      style: TextStyle(color: statusActive ? Colors.green : Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
