// lib/screens/driver_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../widgets/app_card.dart';
import '../widgets/trip_card.dart';
import '../widgets/custom_button.dart';

import '../models/trip.dart';
import '../providers/vehicle_provider.dart';
import 'notification_screen.dart';
import 'user_ratings_screen.dart';
import 'create_trip_screen.dart';
import 'trip_details_screen.dart';
import 'vehicle_screen.dart';
import 'edit_profile_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String? userId;
  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicleData;
  bool _isRefreshing = false;

  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF4F7FA);

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<VehicleProvider>().fetchDriverVehicles(userId!);
      });
    }
  }

  Stream<List<Trip>> _driverTripsStream() {
    final uid = userId;
    if (uid == null || uid.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList());
  }

  Future<void> _refreshAll() async {
    setState(() => _isRefreshing = true);
    if (userId != null) {
      await context.read<VehicleProvider>().fetchDriverVehicles(userId!);
    }
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _isRefreshing = false);
  }

  Future<void> _goToCreateTrip() async {
    final uid = userId;
    if (uid == null) return;

    try {
      final vehicleProvider = context.read<VehicleProvider>();
      final selected = vehicleProvider.selectedVehicle;
      if (selected != null) {
        final plate = selected.plateNumber.trim();
        final owner = selected.vehicleOwner.trim();
        if (plate.isEmpty || owner.isEmpty) {
          _showSnack('🚨 بيانات المركبة المختارة ناقصة: تأكد من وجود رقم اللوحة واسم المالك');
          return;
        }
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'plate_number': plate,
          'vehicle_owner': owner,
          'carPlateNumber': plate,
          'vehicleOwner': owner,
        }, SetOptions(merge: true));
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen()));
        return;
      }

      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      final plateNumber = (data['plate_number'] as String?)?.trim() ?? (data['carPlateNumber'] as String?)?.trim() ?? '';
      final vehicleOwner = (data['vehicle_owner'] as String?)?.trim() ?? (data['vehicleOwner'] as String?)?.trim() ?? '';

      if (plateNumber.isEmpty || vehicleOwner.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 يرجى تحديث ملفك الشخصي: رقم اللوحة واسم مالك المركبة مطلوبان لإضافة رحلة',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen()));
    } catch (e, st) {
      debugPrint('goToCreateTrip error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ حدث خطأ أثناء التحقق من بيانات مركبتك', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontFamily: 'Cairo'))));
  }

  Widget _buildDriverCard() {
    final uid = userId;
    if (uid == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('تعذر تحميل بيانات السائق أو لم يتم تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(color: _logoBlue, backgroundColor: _logoBlue.withOpacity(0.1)),
          );
        }

        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('بيانات السائق غير متوفرة حالياً في قاعدة البيانات', style: TextStyle(fontFamily: 'Cairo')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = (data['nickname'] as String?) ?? 'سائق رحلاء المتميز';
        final rating = (data['average_rating'] as num?)?.toDouble() ?? 5.0;
        final plateNumber = (data['plate_number'] as String?) ?? (data['carPlateNumber'] as String?) ?? 'غير محددة';
        final vehicleOwner = (data['vehicle_owner'] as String?) ?? (data['vehicleOwner'] as String?) ?? 'غير محدد';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [_logoBlue, _logoTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: _logoBlue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '🧑‍✈️ كابتن: $name',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white, fontFamily: 'Cairo'),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('اللوحة: $plateNumber', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontFamily: 'Cairo')),
                    ),
                    const Icon(Icons.assignment_ind_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('المالك: $vehicleOwner', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontFamily: 'Cairo')),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Colors.white24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CustomButton(
                      onPressed: () {
                        if (uid.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: uid)));
                        }
                      },
                      text: 'تقييماتي',
                      icon: Icons.rate_review_outlined,
                      backgroundColor: Colors.white,
                      textColor: _logoBlue,
                      compact: true,
                    ),
                    const SizedBox(width: 8),
                    CustomButton(
                      onPressed: () => Navigator.pushNamed(context, '/calendar'),
                      text: 'جدول التقويم',
                      icon: Icons.calendar_month_outlined,
                      backgroundColor: _logoGreen,
                      textColor: Colors.white,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehiclesSection() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        final vehicles = vehicleProvider.vehicles;
        final isLoading = vehicleProvider.isLoading;

        if (isLoading) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(color: _logoTeal, backgroundColor: _logoTeal.withOpacity(0.1)),
          );
        }

        return AppCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مركباتي المسجلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 28, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('لم تقم بإضافة مركبات بعد. أضف مركبة لتسهيل إنشاء الرحلات.', style: TextStyle(color: Colors.grey.shade700, fontFamily: 'Cairo')),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleScreen())).then((_) {
                          if (userId != null) context.read<VehicleProvider>().fetchDriverVehicles(userId!);
                        }),
                        icon: const Icon(Icons.add),
                        label: const Text('أضف مركبة'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: vehicles.map((v) {
                    final id = v.id;
                    final plate = v.plateNumber.isNotEmpty ? v.plateNumber : '—';
                    final owner = v.vehicleOwner;
                    final type = v.vehicleType ?? '';
                    final capacity = v.maxCapacity.toString();

                    final selected = _selectedVehicleId == id;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedVehicleId = null;
                            _selectedVehicleData = null;
                            vehicleProvider.selectVehicleById(null);
                          } else {
                            _selectedVehicleId = id;
                            _selectedVehicleData = {
                              'id': v.id,
                              'plateNumber': v.plateNumber,
                              'vehicleOwner': v.vehicleOwner,
                              'vehicleType': v.vehicleType,
                              'maxCapacity': v.maxCapacity,
                            };
                            vehicleProvider.selectVehicleById(id);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? _logoTeal.withOpacity(0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? _logoTeal : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: _logoBlue.withOpacity(0.12),
                              child: const Icon(Icons.directions_car, color: Colors.black54),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$type • $plate', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('المالك: $owner • المقاعد: $capacity', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleScreen(vehicleId: id))).then((value) {
                                  if (userId != null) context.read<VehicleProvider>().fetchDriverVehicles(userId!);
                                });
                              },
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'تعديل المركبة',
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleScreen())).then((_) {
                      if (userId != null) context.read<VehicleProvider>().fetchDriverVehicles(userId!);
                    }),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('إضافة مركبة جديدة'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripList() {
    return SizedBox(
      height: 420,
      child: StreamBuilder<List<Trip>>(
        stream: _driverTripsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _logoBlue));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'لم تقم بإنشاء أي رحلات كسائق حتى الآن.',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final trips = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final trip = trips[index];
              return TripCard(
                trip: trip,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
                },
                showPrice: true,
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('الرجاء تسجيل الدخول أولاً لعرض لوحة التحكم الخاص بك', style: TextStyle(fontFamily: 'Cairo'))),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('لوحة تحكم السائق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_active_outlined, color: _logoBlue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: _logoGreen, size: 26),
            tooltip: 'إنشاء رحلة جديدة',
            onPressed: _goToCreateTrip,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: _logoTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDriverCard(),
                const SizedBox(height: 6),
                _buildVehiclesSection(),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 18, color: _logoBlue),
                      const SizedBox(width: 6),
                      const Text(
                        'رحلاتي المضافة حالياً',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const Spacer(),
                      if (_selectedVehicleData != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: _logoTeal.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_car, size: 16, color: Colors.black54),
                              const SizedBox(width: 6),
                              Text('المركبة المختارة', style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _buildTripList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleScreen()));
          } else if (i == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home, color: _logoBlue), label: 'لوحة'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car, color: _logoTeal), label: 'مركباتي'),
          BottomNavigationBarItem(icon: Icon(Icons.person, color: _logoGreen), label: 'ملفي'),
        ],
      ),
    );
  }
}
