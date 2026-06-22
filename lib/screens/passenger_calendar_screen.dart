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

  String _selectedVehicleFilter = 'الكل';
  final List<String> _availableVehicleTypes = ['الكل'];

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _logoGreen = Color(0xFF4EBF64);
  static const Color _backgroundColor = Color(0xFFF1F5F9);

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
          .where('status', whereIn: ['active', 'مفعّلة', 'نشطة', 'Active'])
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> events = {};
      final Set<String> vehicleTypesSet = {'الكل'};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final rawSeats = data['availableSeats'] ?? data['available_seats'];
          final seats = (rawSeats is int) ? rawSeats : (int.tryParse('$rawSeats') ?? 0);
          if (seats <= 0) continue;

          final raw = data['departureTime'] ?? data['date'] ?? data['createdAt'];
          final date = _toDateTime(raw);
          final day = _normalizeDay(date);

          final vehicleType = (data['vehicleType'] ?? data['vehicle_type'] ?? 'صالون').toString();
          vehicleTypesSet.add(vehicleType);

          String formattedTime;
          try {
            formattedTime = DateFormat('hh:mm a', 'ar').format(date);
          } catch (_) {
            formattedTime = DateFormat('hh:mm a').format(date);
          }

          events.putIfAbsent(day, () => []);
          events[day]!.add({
            'id': doc.id,
            'title': (data['title'] ?? data['tripTitle'] ?? 'رحلة مجدولة').toString(),
            'origin': (data['origin'] ?? 'غير محددة').toString(),
            'destination': (data['destination'] ?? 'غير محددة').toString(),
            'time': formattedTime,
            'vehicleType': vehicleType,
            'availableSeats': seats,
          });
        } catch (e) {
          debugPrint('خطأ في معالجة رحلة فردية: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _tripEvents = events;
        _availableVehicleTypes.clear();
        _availableVehicleTypes.addAll(vehicleTypesSet);
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('PassengerCalendarScreen._loadTrips حرج الاستعلام: $e\n$st');
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

  void _showVehicleFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              Text('🚗 تصفية حسب نوع وسيلة النقل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: _logoBlue)),
              const SizedBox(height: 12),
              Flexible(
                child: AppCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableVehicleTypes.length,
                    itemBuilder: (context, index) {
                      final type = _availableVehicleTypes[index];
                      final isSelected = _selectedVehicleFilter == type;
                      return ListTile(
                        leading: Icon(Icons.directions_car_filled_rounded, color: isSelected ? _logoBlue : Colors.grey),
                        title: Text(type, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? Icon(Icons.check_circle, color: _logoGreen) : null,
                        onTap: () {
                          setState(() => _selectedVehicleFilter = type);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
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
        const SnackBar(content: Text('⚠️ معرف الرحلة غير متوفر حالياً للركاب', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ عذراً، تم إلغاء أو حجز هذه الرحلة بالكامل حديثاً', style: TextStyle(fontFamily: 'Cairo'))),
        );
        return;
      }
      final trip = Trip.fromDocument(doc);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ فشل تحميل تفاصيل الرحلة، يرجى التحقق من الشبكة', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawTrips = _getEventsForDay(_selectedDay ?? _focusedDay);

    final selectedTrips = rawTrips.where((trip) {
      if (_selectedVehicleFilter == 'الكل') return true;
      return trip['vehicleType'].toString() == _selectedVehicleFilter;
    }).toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('مفكرة الرحلات المتاحة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _backgroundColor,
        foregroundColor: _logoBlue,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: _logoBlue),
            onPressed: _showVehicleFilterBottomSheet,
            tooltip: 'تصفية المركبات',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _logoBlue),
            onPressed: _loadTrips,
            tooltip: 'تحديث الجدولة',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)))
            : _hasError
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: Colors.red.withOpacity(0.7)),
              const SizedBox(height: 12),
              const Text('حدث خطأ أثناء مزامنة التقويم المباشر لرحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _logoBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _loadTrips,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة المباشرة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        )
            : Column(
          children: [
            AppCard(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(4),
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
                  titleTextStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _logoBlue, fontSize: 14),
                  leftChevronIcon: Icon(Icons.chevron_left, color: _logoBlue),
                  rightChevronIcon: Icon(Icons.chevron_right, color: _logoBlue),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  weekendTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.red.shade400),
                  todayDecoration: BoxDecoration(color: _logoTeal.withOpacity(0.15), shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: _logoTeal, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  selectedDecoration: BoxDecoration(color: _logoBlue, shape: BoxShape.circle),
                  selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  markerDecoration: BoxDecoration(color: _logoTeal, shape: BoxShape.circle),
                  markersMaxCount: 1,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 16, color: _logoBlue),
                      const SizedBox(width: 6),
                      Text(
                        'الرحلات المتاحة ليوم: ${DateFormat('yyyy-MM-dd').format(_selectedDay ?? _focusedDay)}',
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
                    Icon(Icons.directions_car_filled_rounded, size: 52, color: _logoBlue.withOpacity(0.2)),
                    const SizedBox(height: 10),
                    const Text('لا توجد رحلات مطابقة متاحة لهذا اليوم كابتن', style: TextStyle(fontFamily: 'Cairo', color: Colors.black45, fontSize: 12)),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: selectedTrips.length,
                itemBuilder: (context, index) {
                  final trip = selectedTrips[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.zero,
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: _logoGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '💺 متاح ${trip['availableSeats']} مقاعد',
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
      ),
    );
  }
}
