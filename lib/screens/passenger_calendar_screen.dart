// lib/screens/passenger_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import '../widgets/app_card.dart';
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

  // إدارة فلترة نوع المركبة برمجياً وقائمتها السفلية
  String _selectedVehicleFilter = 'الكل';
  final List<String> _availableVehicleTypes = ['الكل'];

  // لوحة ألوان هوية لوجو "رحلاء" الموحدة
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDay(_focusedDay);
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
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('status', whereIn: ['active', 'مفعّلة', 'نشطة'])
          .where('availableSeats', isGreaterThan: 0)
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> events = {};
      final Set<String> vehicleTypesSet = {'الكل'};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final raw = data['departureTime'] ?? data['date'] ?? data['createdAt'];
          final date = _toDateTime(raw);
          final day = _normalizeDay(date);

          final vehicleType = (data['vehicleType'] ?? data['vehicle_type'] ?? 'صالون').toString();
          vehicleTypesSet.add(vehicleType);

          events.putIfAbsent(day, () => []);
          events[day]!.add({
            'id': doc.id,
            'title': (data['title'] ?? data['tripTitle'] ?? 'رحلة بدون عنوان').toString(),
            'origin': (data['origin'] ?? 'غير محددة').toString(),
            'destination': (data['destination'] ?? 'غير محددة').toString(),
            'time': DateFormat('hh:mm a', 'ar').format(date),
            'vehicleType': vehicleType,
            'availableSeats': (data['availableSeats'] is int)
                ? data['availableSeats']
                : (int.tryParse('${data['availableSeats']}') ?? 0),
          });
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _tripEvents = events;
        _availableVehicleTypes.clear();
        _availableVehicleTypes.addAll(vehicleTypesSet);
        _isLoading = false;
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

  // قائمة سفلية (Bottom Sheet) تمكن الراكب من فرز وتصفية المركبات المتاحة
  void _showVehicleFilterBottomSheet() {
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
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('🚗 تصفية حسب نوع وسيلة النقل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableVehicleTypes.length,
                  itemBuilder: (context, index) {
                    final type = _availableVehicleTypes[index];
                    final isSelected = _selectedVehicleFilter == type;
                    return ListTile(
                      leading: Icon(Icons.directions_car_filled_rounded, color: isSelected ? _logoBlue : Colors.grey),
                      title: Text(type, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? Icon(Icons.check_circle, color: _logoGreen) : null,
                      onTap: () {
                        setState(() => _selectedVehicleFilter = type);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTripDetailsById(String? tripId) async {
    if (tripId == null || tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ معرف الرحلة غير متوفر للركوب', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ عذراً، تم إلغاء هذه الرحلة حديثاً', style: TextStyle(fontFamily: 'Cairo'))),
        );
        return;
      }
      final trip = Trip.fromDocument(doc);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ فشل تحميل تفاصيل الرحلة المحددة', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawTrips = _getEventsForDay(_selectedDay ?? _focusedDay);

    // فلترة القائمة المعروضة بناءً على خيار الراكب في القائمة السفلية
    final selectedTrips = rawTrips.where((trip) {
      if (_selectedVehicleFilter == 'الكل') return true;
      return trip['vehicleType'].toString() == _selectedVehicleFilter;
    }).toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('مفكرة الرحلات المتاحة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showVehicleFilterBottomSheet,
            tooltip: 'تصفية المركبات',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTrips,
            tooltip: 'تحديث الجدولة',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _logoBlue))
          : _hasError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Colors.red.shade400),
            const SizedBox(height: 12),
            const Text('حدث خطأ أثناء مزامنة التقويم المباشر', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _logoBlue),
              onPressed: _loadTrips,
              child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
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
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: TableCalendar(
              locale: 'ar',
              firstDay: DateTime.utc(2025, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.saturday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _logoBlue, fontSize: 15),
                leftChevronIcon: Icon(Icons.chevron_left, color: _logoBlue),
                rightChevronIcon: Icon(Icons.chevron_right, color: _logoBlue),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                weekendTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.red.shade400),
                todayDecoration: BoxDecoration(color: _logoTeal.withOpacity(0.2), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: _logoTeal, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                selectedDecoration: BoxDecoration(color: _logoBlue, shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                markerDecoration: BoxDecoration(color: _logoTeal, shape: BoxShape.circle),
                markersMaxCount: 3,
                outsideDaysVisible: false,
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 16, color: _logoBlue),
                    const SizedBox(width: 6),
                    Text(
                      'رحلات المتاحة ليوم: ${DateFormat('yyyy-MM-dd').format(_selectedDay ?? _focusedDay)}',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                if (_selectedVehicleFilter != 'الكل')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _logoBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_selectedVehicleFilter, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: _logoBlue, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),

          Expanded(
            child: selectedTrips.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_filled_rounded, size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('لا توجد رحلات مطابقة متاحة لهذا اليوم', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: selectedTrips.length,
              itemBuilder: (context, index) {
                final trip = selectedTrips[index];
                return AppCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openTripDetailsById(trip['id'] as String?),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(width: 4, height: 16, decoration: BoxDecoration(color: _logoBlue, borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(width: 8),
                                  Text(
                                    trip['title'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: _logoGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  '💺 متاح ${trip['availableSeats']} كراسي',
                                  style: TextStyle(color: _logoGreen, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                ),
                              )
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Icon(Icons.trip_origin_rounded, size: 16, color: _logoTeal),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'من ${trip['origin']} إلى ${trip['destination']}',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('الانطلاق: ${trip['time']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black54)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.directions_car_outlined, size: 14, color: _logoBlue),
                                  const SizedBox(width: 4),
                                  Text('${trip['vehicleType']}', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: _logoBlue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
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