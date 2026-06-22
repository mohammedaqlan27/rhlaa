// lib/screens/driver_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import 'trip_details_screen.dart';

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

  // ألوان هوية لوجو "رحلاء"
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDay(DateTime.now());
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
    if (!mounted) return;
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

      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: userId)
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawDate = data['departureTime'] ?? data['date'] ?? data['createdAt'];
        final date = _toDateTime(rawDate);
        final day = _normalizeDay(date);

        // جلب السعر لغرض تقدير الإيرادات اليومية في القائمة السفلية
        final double tripPrice = double.tryParse(data['price'].toString()) ?? 0.0;

        events.putIfAbsent(day, () => []);
        events[day]!.add({
          'id': doc.id,
          'title': (data['title'] ?? data['tripTitle'] ?? 'رحلة بدون عنوان').toString(),
          'destination': (data['destination'] ?? data['to'] ?? 'غير محددة').toString(),
          'time': DateFormat('hh:mm a', 'ar').format(date),
          'status': (data['status'] ?? 'نشطة').toString(),
          'price': tripPrice,
        });
      }

      if (!mounted) return;
      setState(() {
        _tripEvents = events;
        _isLoading = false;
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

  // قائمة سفلية (Bottom Sheet) حديثة تظهر ملخص الإيرادات والرحلات لليوم المحدد
  void _showDailySummaryBottomSheet(DateTime day, List<Map<String, dynamic>> dayEvents) {
    double totalRevenue = 0;
    for (var ev in dayEvents) {
      totalRevenue += ev['price'] as double;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              Text(
                '📊 تقرير يوم ${DateFormat('yyyy-MM-md').format(day)}',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_logoBlue, _logoTeal]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي الإيرادات المتوقعة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${totalRevenue.toStringAsFixed(0)} ريال',
                          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                    const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.white70),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('عدد الرحلات المجدولة:', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700, fontSize: 14)),
                  Text('${dayEvents.length} رحلة', style: TextStyle(fontFamily: 'Cairo', color: _logoBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _logoGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق اللوحة الإحصائية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTripDetails(String? tripId) async {
    if (tripId == null || tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('معرف الرحلة غير متوفر', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرحلة تم حذفها من الخادم', style: TextStyle(fontFamily: 'Cairo'))));
        return;
      }
      final trip = Trip.fromDocument(doc);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل جلب تفاصيل الرحلة المحددة', style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDay = _selectedDay ?? _focusedDay;
    final events = _getEventsForDay(activeDay);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('جدول وتقويم الرحلات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => _showDailySummaryBottomSheet(activeDay, events),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadTrips),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _logoBlue))
          : _hasError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('حدث خطأ أثناء الاتصال بالخادم الرئيسي.', style: TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _logoBlue),
              onPressed: _loadTrips,
              child: const Text('تحديث الاتصال', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
            ),
            child: TableCalendar(
              locale: 'ar',
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.saturday,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(color: _logoTeal.withOpacity(0.4), shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: _logoBlue, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: _logoTeal, shape: BoxShape.circle),
                markersMaxCount: 3,
                outsideDaysVisible: false,
                defaultTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                weekendTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.red),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _logoBlue, fontSize: 15),
                leftChevronIcon: Icon(Icons.chevron_left, color: _logoBlue),
                rightChevronIcon: Icon(Icons.chevron_right, color: _logoBlue),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('رحلات اليوم المحدد (${events.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                if (events.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showDailySummaryBottomSheet(activeDay, events),
                    icon: Icon(Icons.assessment_rounded, size: 16, color: _logoTeal),
                    label: Text('الملخص المالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _logoTeal, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('جدولك فارغ، لا توجد رحلات مجدولة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final trip = events[index];
                final statusStr = trip['status'].toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _logoBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.directions_car_filled_rounded, color: _logoBlue, size: 22),
                    ),
                    title: Text(trip['title'].toString(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '🏁 الوجهة: ${trip['destination']}  •  ⏰ ${trip['time']}',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _logoGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            '${(trip['price'] as double).toStringAsFixed(0)} ر.ي',
                            style: TextStyle(fontSize: 11, color: _logoGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                      ],
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