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

  // إعدادات ألوان رحلاء الموحدة والمقاومة للتشوه البصري
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  void _loadTrips() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      setState(() {
        _tripsFuture = _fetchDriverTrips(userId);
      });
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

  void _showTripActionsBottomSheet(Trip trip, int passengerCount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(trip.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.people_alt_outlined, color: _logoBlue),
                title: const Text('إدارة الركاب والحجوزات', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _logoBlue.withOpacity(0.1), shape: BoxShape.circle),
                  child: Text('$passengerCount', style: TextStyle(color: _logoBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DriverBookingsScreen(tripId: trip.id ?? '')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.mode_edit_outline_rounded, color: Colors.orange),
                title: const Text('تعديل تفاصيل الرحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EditTripScreen(tripId: trip.id!))).then((_) => _loadTrips());
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: _logoTeal),
                title: const Text('مشاركة بيانات الرحلة للعامة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                onTap: () { Navigator.pop(context); _shareTrip(trip); },
              ),
              if (trip.status == 'مكتملة')
                ListTile(
                  leading: Icon(Icons.star_border_rounded, color: _logoGreen),
                  title: const Text('تقييم ركاب الرحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  onTap: () { Navigator.pop(context); _rateTrip(trip); },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                title: const Text('إلغاء وحذف الرحلة نهائياً', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _deleteTrip(trip.id!); },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteTrip(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد تماماً من رغبتك في إلغاء وحذف هذه الرحلة؟ لا يمكن التراجع.', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، احذف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إلغاء الرحلة بنجاح من النظام', style: TextStyle(fontFamily: 'Cairo'))));
      _loadTrips();
    }
  }

  void _shareTrip(Trip trip) {
    final message = '''
🚗 رحلة جديدة عبر تطبيق رحلاء من ${trip.origin} إلى ${trip.destination}
🕒 وقت الانطلاق المحدد: ${trip.time}
💺 عدد المقاعد المتاحة: ${trip.availableSeats}
📌 للحجز الفوري، حمل التطبيق وتواصل مع الكابتن: ${trip.driverName}
''';
    Share.share(message);
  }

  void _rateTrip(Trip trip) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(tripId: trip.id!, targetUserId: trip.driverId, userType: 'سائق')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('إدارة رحلاتي المجدولة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 26),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen())).then((_) => _loadTrips());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Trip>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _logoBlue));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_filled_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('لا يوجد لديك أي رحلات مجدولة حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 13)),
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          children: [
                            TripCard(trip: trip),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.airline_seat_recline_normal_rounded, size: 18, color: _logoTeal),
                                    const SizedBox(width: 4),
                                    Text('عدد ركاب الرحلة: $passengerCount', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _showTripActionsBottomSheet(trip, passengerCount),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(color: _logoBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      children: [
                                        Text('خيارات التحكم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _logoBlue, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 4),
                                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _logoBlue),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            )
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
      ),
    );
  }
}