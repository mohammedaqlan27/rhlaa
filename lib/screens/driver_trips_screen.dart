// lib/screens/driver_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../screens/create_trip_screen.dart';
import '../screens/edit_trip_screen.dart';
import '../screens/driver_bookings_screen.dart';
import '../screens/rating_screen.dart';
import '../widgets/trip_card.dart';
import '../models/trip.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  void _loadTrips() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _tripsFuture = _fetchDriverTrips(userId);
    }
  }

  Future<List<Trip>> _fetchDriverTrips(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('driverId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();
  }

  Future<int> _getPassengerCount(String tripId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('trip_id', isEqualTo: tripId)
        .get();
    return snapshot.docs.length;
  }

  Future<void> _deleteTrip(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد أنك تريد إلغاء هذه الرحلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إلغاء الرحلة')),
      );
      setState(() => _loadTrips());
    }
  }

  void _shareTrip(Trip trip) {
    final message = '''
🚗 رحلة جديدة من ${trip.origin} إلى ${trip.destination}
🕒 وقت الانطلاق: ${trip.time}
💺 المقاعد المتاحة: ${trip.availableSeats}
📌 للحجز أو التفاصيل، تواصل مع السائق: ${trip.driverName}
''';
    Share.share(message);
  }

  void _rateTrip(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          tripId: trip.id!,
          targetUserId: trip.driverId,
          userType: 'سائق',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('❌ يجب تسجيل الدخول لعرض الرحلات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚘 إدارة رحلاتي'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTripScreen()),
              ).then((_) => setState(() => _loadTrips()));
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Trip>>(
        future: _tripsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('جاري تحميل الرحلات...', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('لا توجد رحلات حالياً.', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final trips = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return FutureBuilder<int>(
                future: _getPassengerCount(trip.id ?? ''),
                builder: (context, countSnapshot) {
                  final passengerCount = countSnapshot.data ?? 0;

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TripCard(trip: trip),
                          const SizedBox(height: 8),
                          Text('🚶‍♂️ عدد الركاب الحاليين: $passengerCount'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DriverBookingsScreen(tripId: trip.id ?? ''),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.people),
                                label: const Text('الركاب'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditTripScreen(tripId: trip.id!),
                                    ),
                                  ).then((_) => setState(() => _loadTrips()));
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('تعديل'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _deleteTrip( trip.id!),
                                icon: const Icon(Icons.cancel),
                                label: const Text('إلغاء'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _shareTrip(trip),
                                icon: const Icon(Icons.share),
                                label: const Text('مشاركة'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                              ),
                              if (trip.status == 'مكتملة')
                                ElevatedButton.icon(
                                  onPressed: () => _rateTrip(trip),
                                  icon: const Icon(Icons.star),
                                  label: const Text('تقييم'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
