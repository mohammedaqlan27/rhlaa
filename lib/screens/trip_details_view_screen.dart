// lib/screens/trip_details_view_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import 'trip_details_screen.dart';

class TripDetailsViewScreen extends StatelessWidget {
  final dynamic tripData;

  const TripDetailsViewScreen({super.key, required this.tripData});

  String _getString(dynamic src, String fallback) {
    if (src == null) return fallback;
    try {
      return src.toString();
    } catch (_) {
      return fallback;
    }
  }

  int _getInt(dynamic src, [int fallback = 0]) {
    if (src == null) return fallback;
    if (src is int) return src;
    if (src is num) return src.toInt();
    if (src is String) return int.tryParse(src) ?? fallback;
    return fallback;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value', style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Trip? _asTrip() {
    if (tripData == null) return null;
    if (tripData is Trip) return tripData as Trip;

    if (tripData is Map<String, dynamic>) {
      final Map<String, dynamic> d = Map<String, dynamic>.from(tripData as Map);
      return Trip(
        id: d['id']?.toString(),
        title: _getString(d['title'], ''),
        description: _getString(d['description'], ''),
        driverId: _getString(d['driverId'] ?? d['driver_id'], ''),
        driverName: _getString(d['driverName'] ?? d['driver_name'], ''),
        tripCategory: _getString(d['tripCategory'] ?? d['trip_category'], 'داخلية'),
        origin: _getString(d['origin'], ''),
        destination: _getString(d['destination'], ''),
        vehicleType: _getString(d['vehicleType'] ?? d['vehicle_type'], ''),
        vehicleId: _getString(d['vehicleId'] ?? d['vehicle_id'], ''),
        totalSeats: _getInt(d['totalSeats'] ?? d['total_seats'], 0),
        availableSeats: _getInt(d['availableSeats'] ?? d['available_seats'], 0),
        seatStatus: (d['seatStatus'] is List)
            ? List<bool>.from((d['seatStatus'] as List).map((e) {
                if (e is bool) return e;
                if (e is num) return e != 0;
                if (e is String) return e.toLowerCase() == 'true' || e == '1';
                return false;
              }))
            : <bool>[],
        departureTime: _toDateTime(d['departureTime'] ?? d['date'] ?? d['departure_time']),
        date: _toDateTime(d['date'] ?? d['trip_date']),
        time: _getString(d['time'], ''),
        flexibleWindow: _getString(d['flexibleWindow'] ?? d['flexible_window'], ''),
        status: _getString(d['status'], 'غير معروف'),
        price: (d['price'] is num) ? (d['price'] as num).toDouble() : double.tryParse('${d['price']}') ?? 0.0,
        driverRating: (d['driverRating'] is num) ? (d['driverRating'] as num).toDouble() : double.tryParse('${d['driverRating']}') ?? 0.0,
        carPlateNumber: _getString(d['carPlateNumber'] ?? d['car_plate_number'], 'غير متوفر'),
        carOwnerOfficialName: _getString(d['carOwnerOfficialName'] ?? d['car_owner_official_name'], 'غير متوفر'),
        createdAt: (d['createdAt'] is Timestamp) ? d['createdAt'] as Timestamp : (d['created_at'] is Timestamp ? d['created_at'] as Timestamp : null),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Trip? trip = _asTrip();

    final title = trip?.title ?? (tripData is Map ? _getString(tripData['title'], 'رحلة') : 'رحلة');
    final origin = trip?.origin ?? (tripData is Map ? _getString(tripData['origin'], '-') : '-');
    final destination = trip?.destination ?? (tripData is Map ? _getString(tripData['destination'], '-') : '-');
    final vehicleType = trip?.vehicleType ?? (tripData is Map ? _getString(tripData['vehicleType'], '-') : '-');
    final driverName = trip?.driverName ?? (tripData is Map ? _getString(tripData['driverName'], '-') : '-');
    final price = trip?.price ?? (tripData is Map ? double.tryParse('${tripData['price']}') ?? 0.0 : 0.0);
    final status = trip?.status ?? (tripData is Map ? _getString(tripData['status'], '-') : '-');
    final availableSeats = trip?.availableSeats ?? (tripData is Map ? _getInt(tripData['availableSeats']) : 0);
    final totalSeats = trip?.totalSeats ?? (tripData is Map ? _getInt(tripData['totalSeats']) : 0);
    final timeStr = trip?.time ?? (tripData is Map ? _getString(tripData['time'], '') : '');
    final departure = trip?.departureTime ?? (tripData is Map ? _toDateTime(tripData['departureTime'] ?? tripData['date']) : null);

    final formattedDate = departure != null ? DateFormat('yyyy-MM-dd').format(departure) : 'غير محدد';
    final formattedTime = (departure != null && (timeStr == null || timeStr.isEmpty))
        ? DateFormat('HH:mm').format(departure)
        : (timeStr.isNotEmpty ? timeStr : 'غير محدد');

    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.indigo),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: ListView(
              shrinkWrap: true,
              children: [
                Center(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.location_on, 'من', origin),
                _buildInfoRow(Icons.flag, 'إلى', destination),
                _buildInfoRow(Icons.directions_car, 'نوع المركبة', vehicleType),
                _buildInfoRow(Icons.person, 'السائق', driverName),
                _buildInfoRow(Icons.calendar_today, 'التاريخ', formattedDate),
                _buildInfoRow(Icons.access_time, 'الوقت', formattedTime),
                _buildInfoRow(Icons.attach_money, 'السعر', price > 0 ? '${price.toStringAsFixed(2)}' : 'مجاني'),
                _buildInfoRow(Icons.event_seat, 'المقاعد المتاحة', '$availableSeats من $totalSeats'),
                _buildInfoRow(Icons.info_outline, 'الحالة', status),
                const SizedBox(height: 12),
                if (trip != null && trip.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('الوصف', style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                  ),
                if (trip != null && trip.description.isNotEmpty) Text(trip.description, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.info),
                        label: const Text('تفاصيل كاملة'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                        onPressed: () {
                          if (trip != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
                          } else if (tripData is Map<String, dynamic>) {
                            final id = tripData['id']?.toString();
                            if (id != null && id.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: Trip.fromDocument(FakeDoc(id, Map<String, dynamic>.from(tripData))))),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: Trip(
                                  id: null,
                                  title: title,
                                  description: tripData['description']?.toString() ?? '',
                                  driverId: tripData['driverId']?.toString() ?? '',
                                  driverName: driverName,
                                  tripCategory: tripData['tripCategory']?.toString() ?? 'داخلية',
                                  origin: origin,
                                  destination: destination,
                                  vehicleType: vehicleType,
                                  vehicleId: tripData['vehicleId']?.toString(),
                                  totalSeats: totalSeats,
                                  availableSeats: availableSeats,
                                  seatStatus: tripData['seatStatus'] is List ? List<bool>.from((tripData['seatStatus'] as List).map((e) => e == true || e == 'true' || e == 1)) : <bool>[],
                                  departureTime: departure,
                                  date: departure,
                                  time: formattedTime,
                                  flexibleWindow: tripData['flexibleWindow']?.toString() ?? '',
                                  status: status,
                                  price: price,
                                  driverRating: tripData['driverRating'] is num ? (tripData['driverRating'] as num).toDouble() : 0.0,
                                  carPlateNumber: tripData['carPlateNumber']?.toString() ?? 'غير متوفر',
                                  carOwnerOfficialName: tripData['carOwnerOfficialName']?.toString() ?? 'غير متوفر',
                                  createdAt: tripData['createdAt'] is Timestamp ? tripData['createdAt'] as Timestamp : null,
                                ))),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.book_online),
                        label: const Text('حجز مقعد'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () {
                          if (trip != null) {
                            Navigator.pushNamed(context, '/payment', arguments: {'tripId': trip.id ?? '', 'seatNumber': 1});
                          } else if (tripData is Map<String, dynamic>) {
                            Navigator.pushNamed(context, '/payment', arguments: {'tripId': tripData['id']?.toString() ?? '', 'seatNumber': 1});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر بدء عملية الحجز')));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FakeDoc implements DocumentSnapshot {
  final String _id;
  final Map<String, dynamic> _data;

  FakeDoc(this._id, this._data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Map<String, dynamic> data() => _data;

  @override
  String get id => _id;
}
