// lib/screens/available_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

      query = query.where('destination', isEqualTo: destination);
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

          final destRaw = raw['destination'] ?? raw['dest'] ?? raw['to'];
          if (destRaw != null && destRaw.toString() != destination) matches = false;

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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرحلات المتاحة'),
        backgroundColor: theme.colorScheme.primary,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Trip>>(
        future: _fetchTrips(),
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

          if (snapshot.hasError) {
            debugPrint('AvailableTripsScreen FutureBuilder error: ${snapshot.error}');
            return const Center(
              child: Text('❌ حدث خطأ أثناء تحميل الرحلات. حاول مرة أخرى لاحقًا.'),
            );
          }

          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return const Center(
              child: Text('لا توجد رحلات متاحة حالياً لهذه الوجهة.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            );
          }

          return buildTripList(trips, context);
        },
      ),
    );
  }
}
