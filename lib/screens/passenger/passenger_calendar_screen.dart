import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/shared/app_scaffold.dart';
import '../../widgets/shared/app_card.dart';
import '../trip_details_screen.dart';

class PassengerCalendarScreen extends StatefulWidget {
  const PassengerCalendarScreen({super.key});

  @override
  State<PassengerCalendarScreen> createState() => _PassengerCalendarScreenState();
}

class _PassengerCalendarScreenState extends State<PassengerCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final String _selectedVehicleFilter = 'الكل';

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _logoGreen = Color(0xFF4EBF64);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false).fetchAvailableTrips();
    });
  }

  List<Trip> _getTripsForDay(DateTime day, List<Trip> allTrips) {
    return allTrips.where((trip) {
      if (trip.departureTime == null) return false;
      return isSameDay(trip.departureTime, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مفكرة الرحلات',
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          if (tripProvider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: _logoBlue));
          }

          final allTrips = tripProvider.availableTrips;
          final tripsForSelectedDay = _getTripsForDay(_selectedDay ?? _focusedDay, allTrips)
              .where((t) => _selectedVehicleFilter == 'الكل' || t.vehicleType == _selectedVehicleFilter)
              .toList();

          return Column(
            children: [
              _buildCalendarCard(allTrips),
              const SizedBox(height: 16),
              _buildDayHeader(),
              Expanded(
                child: tripsForSelectedDay.isEmpty
                    ? _buildEmptyState()
                    : _buildTripsList(tripsForSelectedDay),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarCard(List<Trip> allTrips) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: TableCalendar(
        locale: 'ar',
        firstDay: DateTime.now().subtract(const Duration(days: 30)),
        lastDay: DateTime.now().add(const Duration(days: 90)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: (day) => _getTripsForDay(day, allTrips),
        startingDayOfWeek: StartingDayOfWeek.saturday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _logoBlue),
        ),
        calendarStyle: CalendarStyle(
          markerDecoration: const BoxDecoration(color: _logoTeal, shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(color: _logoBlue, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: _logoBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: _logoBlue, fontWeight: FontWeight.bold),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  Widget _buildDayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: _logoTeal, size: 20),
          const SizedBox(width: 8),
          Text(
            'رحلات يوم ${DateFormat('EEEE, d MMMM', 'ar').format(_selectedDay ?? _focusedDay)}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList(List<Trip> trips) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
            title: Text(trip.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('من ${trip.origin} إلى ${trip.destination}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${trip.price.toInt()} ر.ي', style: const TextStyle(color: _logoGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${trip.availableSeats} مقاعد', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('لا توجد رحلات متاحة في هذا اليوم', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
        ],
      ),
    );
  }
}