// lib/screens/driver_calendar_screen.dart
// (معدّل: عند الضغط على زر التفاصيل يجلب المستند من Firestore ثم يمرّر كائن Trip إلى TripDetailsScreen)

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import 'trip_details_screen.dart'; // تأكد من المسار الصحيح في مشروعك

class DriverCalendarScreen extends StatefulWidget {
  const DriverCalendarScreen({super.key});

  @override
  State<DriverCalendarScreen> createState() => _DriverCalendarScreenState();
}

class _DriverCalendarScreenState extends State<DriverCalendarScreen> {
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
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _tripEvents = {};
          _isLoading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance.collection('trips').where('driverId', isEqualTo: userId).get();
      final Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawDate = data['departureTime'] ?? data['date'] ?? data['createdAt'];
        final date = _toDateTime(rawDate);
        final day = _normalizeDay(date);

        events.putIfAbsent(day, () => []);
        events[day]!.add({
          'id': doc.id,
          'title': (data['title'] ?? data['tripTitle'] ?? 'رحلة بدون عنوان').toString(),
          'destination': (data['destination'] ?? data['to'] ?? 'غير محددة').toString(),
          'time': DateFormat('HH:mm').format(date),
          'status': (data['status'] ?? 'غير معروف').toString(),
        });
      }

      if (!mounted) return;
      setState(() {
        _tripEvents = events;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e, st) {
      debugPrint('DriverCalendarScreen._loadTrips error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) => _tripEvents[_normalizeDay(day)] ?? [];

  Future<void> _openTripDetails(String? tripId) async {
    if (tripId == null || tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('معرف الرحلة غير متوفر')));
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرحلة غير موجودة')));
        return;
      }
      final trip = Trip.fromDocument(doc);
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
    } catch (e) {
      debugPrint('DriverCalendarScreen._openTripDetails error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل جلب تفاصيل الرحلة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 تقويم الرحلات'),
        backgroundColor: Colors.blue.shade900,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTrips)],
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
                    TableCalendar(
                      locale: 'ar',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: _getEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: events.isEmpty
                          ? const Center(child: Text('لا توجد رحلات في هذا اليوم.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final trip = events[index];
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
                                        Text('📍 الوجهة: ${trip['destination']}'),
                                        Text('🕒 الوقت: ${trip['time']}'),
                                        Text('📌 الحالة: ${trip['status']}'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.open_in_new),
                                      onPressed: () => _openTripDetails(trip['id'] as String?),
                                    ),
                                    onTap: () => _openTripDetails(trip['id'] as String?),
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
