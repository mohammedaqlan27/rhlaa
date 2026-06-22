// lib/screens/manage_trip_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';

class ManageTripScreen extends StatefulWidget {
  const ManageTripScreen({super.key});

  @override
  State<ManageTripScreen> createState() => _ManageTripScreenState();
}

class _ManageTripScreenState extends State<ManageTripScreen> {
  List<Trip> _myTrips = [];
  bool _isLoading = true;

  final List<String> _statusOptions = ['مفعّلة', 'في الطريق', 'تم الوصول', 'مكتملة', 'ملغاة'];

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _baseBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final trips = snapshot.docs.map((doc) => Trip.fromDocument(doc)).toList();

      if (!mounted) return;
      setState(() {
        _myTrips = trips;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTripStatus(String tripId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({'status': newStatus});
      await _loadTrips();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث حالة الرحلة', style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  Future<void> _cancelTrip(String tripId) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({'status': 'ملغاة'});
      await _loadTrips();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إلغاء الرحلة', style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  void _confirmCancel(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد إلغاء الرحلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذه الرحلة نهائياً؟ سيتأثر ركاب الحجز بهذا الإجراء.', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      await _cancelTrip(tripId);
    }
  }

  Widget _buildTripCard(Trip trip) {
    final departure = trip.departureTime;
    final formattedDate = departure != null
        ? '${departure.year}-${departure.month.toString().padLeft(2, '0')}-${departure.day.toString().padLeft(2, '0')}'
        : 'تاريخ غير محدد';

    final currentStatus = trip.status.isNotEmpty ? trip.status : 'مفعّلة';
    final dropdownValue = _statusOptions.contains(currentStatus) ? currentStatus : _statusOptions.first;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.room_rounded, color: _logoBlue, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text('الوجهة: ${trip.destination}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: _logoBlue)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('🚗 نوع المركبة: ${trip.vehicleType.isNotEmpty ? trip.vehicleType : 'غير محدد'}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          Text('🕒 موعد الانطلاق: $formattedDate - ${trip.time}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          Text('🪑 المقاعد الشاغرة: ${trip.availableSeats} من أصل ${trip.totalSeats}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          Row(
            children: [
              const Text('🟢 حالة الرحلة الحالية: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              Text(currentStatus, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: _logoTeal)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              // حقل اختيار الحالة بتصميم مبسط متناسق مع النيومورف
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300, width: 0.8)
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: dropdownValue,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                    items: _statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null && trip.id != null) {
                        _updateTripStatus(trip.id!, newStatus);
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              CustomButton(
                onPressed: trip.id == null || currentStatus == 'ملغاة' ? null : () => _confirmCancel(trip.id!),
                text: 'إلغاء الرحبة',
                width: 90,
                compact: true,
                backgroundColor: currentStatus == 'ملغاة' ? Colors.grey.shade400 : Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _baseBg,
        appBar: AppBar(
          title: const Text('لوحة إدارة رحلاتي', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: _baseBg,
          foregroundColor: _logoBlue,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _logoBlue),
              onPressed: _loadTrips,
              tooltip: 'تحديث البيانات',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)))
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: _myTrips.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_rounded, size: 60, color: _logoBlue.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('لا توجد لديك رحلات مجدولة حالياً كابتن.', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54)),
              ],
            ),
          )
              : ListView.builder(
            itemCount: _myTrips.length,
            itemBuilder: (context, index) => _buildTripCard(_myTrips[index]),
          ),
        ),
      ),
    );
  }
}