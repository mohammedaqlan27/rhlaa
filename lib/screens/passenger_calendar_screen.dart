// lib/screens/passenger_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import 'trip_details_screen.dart';

class PassengerCalendarScreen extends StatefulWidget {
  const PassengerCalendarScreen({super.key});

  @override
  State<PassengerCalendarScreen> createState() => _PassengerCalendarScreenState();
}

class _PassengerCalendarScreenState extends State<PassengerCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _tripEvents = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  DateTime _normalizeDay(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('status', isEqualTo: 'مفعّلة')
          .where('availableSeats', isGreaterThan: 0)
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final raw = data['departureTime'] ?? data['date'] ?? data['createdAt'];
        final date = _toDateTime(raw);
        final day = _normalizeDay(date);

        events.putIfAbsent(day, () => []);
        events[day]!.add({
          'id': doc.id,
          'title': (data['title'] ?? data['tripTitle'] ?? 'رحلة بدون عنوان').toString(),
          'origin': (data['origin'] ?? 'غير محددة').toString(),
          'destination': (data['destination'] ?? 'غير محددة').toString(),
          'time': DateFormat('HH:mm').format(date),
          'vehicleType': (data['vehicleType'] ?? data['vehicle_type'] ?? 'غير معروف').toString(),
          'availableSeats': (data['availableSeats'] is int) ? data['availableSeats'] : (int.tryParse('${data['availableSeats']}') ?? 0),
        });
      }

      if (!mounted) return;
      setState(() {
        _tripEvents = events;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e, st) {
      debugPrint('PassengerCalendarScreen._loadTrips error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _tripEvents[_normalizeDay(day)] ?? [];
  }

  Future<void> _openTripDetailsById(String? tripId) async {
    if (tripId == null || tripId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('معرف الرحلة غير متوفر')));
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
      if (!doc.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرحلة غير موجودة')));
        return;
      }
      final trip = Trip.fromDocument(doc);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
    } catch (e) {
      debugPrint('PassengerCalendarScreen._openTripDetailsById error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل جلب تفاصيل الرحلة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTrips = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 تقويم الرحلات المتاحة'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTrips, tooltip: 'تحديث'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text('حدث خطأ أثناء تحميل الرحلات. حاول مرة أخرى لاحقًا.'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _loadTrips, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    TableCalendar<Map<String, dynamic>>(
                      locale: 'ar',
                      firstDay: DateTime.utc(2023, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: (day) => _getEventsForDay(day),
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        markerDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: selectedTrips.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy, size: 60, color: Colors.grey),
                                  SizedBox(height: 10),
                                  Text('لا توجد رحلات في هذا اليوم.', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: selectedTrips.length,
                              itemBuilder: (context, index) {
                                final trip = selectedTrips[index];
                                return Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: const Icon(Icons.directions_car, color: Colors.blue),
                                    title: Text('🚗 ${trip['title']}'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('📍 من ${trip['origin']} إلى ${trip['destination']}'),
                                        Text('🕒 الوقت: ${trip['time']}'),
                                        Text('🚗 النوع: ${trip['vehicleType']}'),
                                        Text('🪑 المقاعد المتاحة: ${trip['availableSeats']}'),
                                      ],
                                    ),
                                    onTap: () => _openTripDetailsById(trip['id'] as String?),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
