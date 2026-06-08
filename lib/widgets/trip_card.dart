// lib/widgets/trip_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final String currencyLabel;
  final bool useAlternativeDesign;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.currencyLabel = 'ريال',
    this.useAlternativeDesign = false,
  });

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _formatDateShort(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _safeString(dynamic v, {String fallback = '-'}) =>
      (v == null || v.toString().isEmpty) ? fallback : v.toString();

  int _safeInt(dynamic v, {int fallback = 0}) =>
      (v is int) ? v : int.tryParse(v.toString()) ?? fallback;

  double _safeDouble(dynamic v, {double fallback = 0.0}) =>
      (v is double) ? v : double.tryParse(v.toString()) ?? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _toDateTime(trip.date ?? trip.departureTime);
    final dateText = _formatDateShort(date);

    final titleText = trip.title?.isNotEmpty == true
        ? trip.title!
        : '${_safeString(trip.origin)} → ${_safeString(trip.destination)}';

    final originText = _safeString(trip.origin);
    final destinationText = _safeString(trip.destination);
    final timeText = _safeString(trip.time, fallback: '');
    final available = _safeInt(trip.availableSeats);
    final total = _safeInt(trip.totalSeats);
    final price = _safeDouble(trip.price);
    final priceText =
    price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    final vehicleType = _safeString(trip.vehicleType);
    final driverName = _safeString(trip.driverName);
    final hasSeats = available > 0;

    return Opacity(
      opacity: hasSeats ? 1.0 : 0.85,
      child: InkWell(
        onTap: hasSeats ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // شعار التطبيق + العنوان
                Row(
                  children: [
                    // شعار أو أيقونة مميزة للتطبيق
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.directions_bus,
                          color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        titleText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasSeats
                            ? theme.colorScheme.secondary.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasSeats ? 'متاح' : 'ممتلئ',
                        style: TextStyle(
                          color: hasSeats ? theme.colorScheme.secondary : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // الموقع
                Row(
                  children: [
                    Icon(Icons.location_on, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$originText → $destinationText',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // الوقت والتاريخ
                Row(
                  children: [
                    Icon(Icons.access_time, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      timeText.isNotEmpty ? '$timeText • $dateText' : dateText,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // المقاعد والسعر
                Row(
                  children: [
                    Icon(Icons.event_seat, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text('المقاعد: $available من $total',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 14)),
                    const Spacer(),
                    Icon(Icons.attach_money, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text('$priceText $currencyLabel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        )),
                  ],
                ),
                const SizedBox(height: 10),

                // نوع المركبة واسم السائق
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('نوع السيارة: $vehicleType',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.person, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('السائق: $driverName',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),

                if (!hasSeats) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('لا توجد مقاعد متاحة حالياً',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
