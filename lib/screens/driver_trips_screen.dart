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
import '../widgets/app_card.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  // تم إلغاء كلمة late المسببة للخطأ وتعيين القيمة الابتدائية كـ null بأمان
  Future<List<Trip>>? _tripsFuture;
  String? _currentUserId;

  // إعدادات ألوان تطبيق "رحلة" الرسمية الموحدة
  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _logoGreen = Color(0xFF4EBF64);
  static const Color _backgroundColor = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _initUserAndLoadTrips();
  }

  void _initUserAndLoadTrips() {
    // جلب مستخدم فايربيز الحالي
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      _tripsFuture = _fetchDriverTrips(user.uid);
    } else {
      // إذا لم يتعرف فايربيز على المستخدم فوراً، نستمع للتغييرات الحية للجلسة
      FirebaseAuth.instance.authStateChanges().listen((User? updatedUser) {
        if (updatedUser != null && mounted) {
          setState(() {
            _currentUserId = updatedUser.uid;
            _tripsFuture = _fetchDriverTrips(updatedUser.uid);
          });
        }
      });
    }
  }

  void _loadTrips() {
    if (_currentUserId != null) {
      setState(() {
        _tripsFuture = _fetchDriverTrips(_currentUserId!);
      });
    }
  }

  Future<List<Trip>> _fetchDriverTrips(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('driverId', isEqualTo: userId)
        .get();

    final list = snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();
    // فرز محلي آمن للتاريخ
    list.sort((a, b) => (b.createdAt ?? Timestamp.now()).compareTo(a.createdAt ?? Timestamp.now()));
    return list;
  }

  Future<int> _getPassengerCount(String tripId) async {
    if (tripId.isEmpty) return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('tripId', isEqualTo: tripId)
        .get();
    return snapshot.docs.length;
  }

  void _showTripActionsBottomSheet(Trip trip, int passengerCount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text(trip.title.isNotEmpty ? trip.title : 'تفاصيل الرحلة', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: _logoBlue)),
              const SizedBox(height: 12),

              AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.people_alt_outlined, color: _logoBlue),
                      title: const Text('إدارة الركاب والحجوزات', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _logoBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Text('$passengerCount', style: const TextStyle(color: _logoBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DriverBookingsScreen(tripId: trip.id)));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.mode_edit_outline_rounded, color: Colors.orange),
                      title: const Text('تعديل تفاصيل الرحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => EditTripScreen(tripId: trip.id))).then((_) => _loadTrips());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.share_outlined, color: _logoTeal),
                      title: const Text('مشاركة بيانات الرحلة للعامة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      onTap: () { Navigator.pop(context); _shareTrip(trip); },
                    ),
                    if (trip.status == 'مكتملة' || trip.status == 'completed')
                      ListTile(
                        leading: const Icon(Icons.star_border_rounded, color: _logoGreen),
                        title: const Text('تقييم ركاب الرحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                        onTap: () { Navigator.pop(context); _rateTrip(trip); },
                      ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                      title: const Text('إلغاء وحذف الرحلة نهائياً', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      onTap: () { Navigator.pop(context); _deleteTrip(trip.id); },
                    ),
                  ],
                ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الإلغاء وحذف الرحلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
        content: const Text('هل أنت متأكد تماماً من رغبتك في إلغاء وحذف هذه الرحلة؟ لا يمكن التراجع عن هذا الإجراء وسيتم تنبيه الركاب.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، احذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إلغاء الرحلة بنجاح من نظام رحلة', style: TextStyle(fontFamily: 'Cairo'))));
      _loadTrips();
    }
  }

  void _shareTrip(Trip trip) {
    final message = '''
🚗 رحلة جديدة عبر تطبيق رحلة من ${trip.origin} إلى ${trip.destination}
🕒 وقت الانطلاق المحدد: ${trip.time}
💺 عدد المقاعد المتاحة: ${trip.availableSeats}
📌 للحجز الفوري، حمل التطبيق وتواصل مع الكابتن: ${trip.driverName}
''';
    Share.share(message);
  }

  void _rateTrip(Trip trip) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(tripId: trip.id, targetUserId: trip.driverId, userType: 'سائق')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: const Text('إدارة رحلاتي المجدولة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: _backgroundColor,
          foregroundColor: _logoBlue,
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 26, color: _logoBlue),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen())).then((_) => _loadTrips());
              },
            ),
          ],
        ),
        body: SafeArea(
          child: _tripsFuture == null
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)))
              : FutureBuilder<List<Trip>>(
            future: _tripsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)));
              }

              if (snapshot.hasError) {
                return Center(child: Text('حدث خطأ في تحميل البيانات: ${snapshot.error}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)));
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_filled_outlined, size: 64, color: _logoBlue.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      const Text('لا يوجد لديك أي رحلات مجدولة حالياً كابتن', style: TextStyle(fontFamily: 'Cairo', color: Colors.black45, fontSize: 13)),
                    ],
                  ),
                );
              }

              final trips = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return FutureBuilder<int>(
                    future: _getPassengerCount(trip.id),
                    builder: (context, countSnapshot) {
                      final passengerCount = countSnapshot.data ?? 0;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 14),
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
                                    const Icon(Icons.airline_seat_recline_normal_rounded, size: 18, color: _logoTeal),
                                    const SizedBox(width: 4),
                                    Text('عدد ركاب الرحلة: $passengerCount', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _showTripActionsBottomSheet(trip, passengerCount),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(color: _logoBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      children: const [
                                        Text('خيارات التحكم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _logoBlue, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 4),
                                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _logoBlue),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}