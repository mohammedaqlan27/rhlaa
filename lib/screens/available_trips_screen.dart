// lib/screens/available_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../widgets/trip_card.dart';
import 'trip_details_screen.dart';

class AvailableTripsScreen extends StatelessWidget {
  final String destination;
  final String? tripCategory;
  final String? vehicleType;

  const AvailableTripsScreen({
    super.key,
    required this.destination,
    this.tripCategory,
    this.vehicleType,
  });

  Future<List<Trip>> _fetchTrips() async {
    try {
      Query query = FirebaseFirestore.instance.collection('trips');

      if (destination.isNotEmpty) {
        query = query.where('destination', isEqualTo: destination);
      }
      query = query.where('status', whereIn: ['active', 'مفعّلة']);
      query = query.where('availableSeats', isGreaterThan: 0);

      if (tripCategory != null && tripCategory!.trim().isNotEmpty) {
        query = query.where('tripCategory', isEqualTo: tripCategory);
      }

      if (vehicleType != null && vehicleType!.trim().isNotEmpty) {
        query = query.where('vehicleType', isEqualTo: vehicleType);
      }

      Query orderedQuery;
      try {
        orderedQuery = query.orderBy('departureTime');
      } catch (_) {
        try {
          orderedQuery = query.orderBy('date');
        } catch (_) {
          orderedQuery = query;
        }
      }

      final snapshot = await orderedQuery.get();
      final List<Trip> trips = [];

      for (final doc in snapshot.docs) {
        try {
          final trip = Trip.fromDocument(doc);
          bool matches = true;
          final raw = doc.data() as Map<String, dynamic>;

          if (tripCategory != null && tripCategory!.trim().isNotEmpty) {
            final tc = raw['tripCategory'] ?? raw['trip_category'];
            if (tc == null || tc.toString() != tripCategory) matches = false;
          }

          if (vehicleType != null && vehicleType!.trim().isNotEmpty) {
            final vt = raw['vehicleType'] ?? raw['vehicle_type'];
            if (vt == null || vt.toString() != vehicleType) matches = false;
          }

          if (destination.isNotEmpty) {
            final destRaw = raw['destination'] ?? raw['dest'] ?? raw['to'];
            if (destRaw != null && destRaw.toString() != destination) matches = false;
          }

          if (matches) trips.add(trip);
        } catch (e, st) {
          debugPrint('AvailableTripsScreen.parse doc error: $e\n$st');
        }
      }

      return trips;
    } catch (e, st) {
      debugPrint('AvailableTripsScreen._fetchTrips error: $e\n$st');
      return [];
    }
  }

  Widget buildTripList(List<Trip> trips, BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF4A7DAB);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(destination.isNotEmpty ? 'رحلات إلى $destination' : 'الرحلات المتاحة',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Trip>>(
        future: _fetchTrips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('❌ حدث خطأ أثناء تحميل الرحلات.', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
            );
          }

          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_filled_outlined, size: 54, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('لا توجد رحلات متاحة حالياً لهذه الوجهة.',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.grey)),
                ],
              ),
            );
          }

          return buildTripList(trips, context);
        },
      ),
    );
  }
}