// lib/screens/manage_trip_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip.dart';

class ManageTripScreen extends StatefulWidget {
  const ManageTripScreen({super.key});

  @override
  State<ManageTripScreen> createState() => _ManageTripScreenState();
}

class _ManageTripScreenState extends State<ManageTripScreen> {
  List<Trip> _myTrips = [];
  bool _isLoading = true;

  final List<String> _statusOptions = ['مفعّلة', 'في الطريق', 'تم الوصول', 'مكتملة', 'ملغاة'];

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
      debugPrint('ManageTripScreen._loadTrips error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTripStatus(String tripId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'status': newStatus,
      });
      await _loadTrips();
    } catch (e) {
      debugPrint('ManageTripScreen._updateTripStatus error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث حالة الرحلة')));
      }
    }
  }

  Future<void> _cancelTrip(String tripId) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'status': 'ملغاة',
      });
      await _loadTrips();
    } catch (e) {
      debugPrint('ManageTripScreen._cancelTrip error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إلغاء الرحلة')));
      }
    }
  }

  void _confirmCancel(String tripId) async {
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 الوجهة: ${trip.destination}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('🚗 نوع السيارة: ${trip.vehicleType.isNotEmpty ? trip.vehicleType : 'غير محدد'}'),
            Text('🕒 وقت الانطلاق: $formattedDate - ${trip.time}'),
            Text('🪑 المقاعد المتاحة: ${trip.availableSeats} من أصل ${trip.totalSeats}'),
            Text('🟢 الحالة الحالية: ${trip.status.isNotEmpty ? trip.status : 'مفعّلة'}'),
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<String>(
                  value: dropdownValue,
                  items: _statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                  onChanged: (newStatus) {
                    if (newStatus != null && trip.id != null) {
                      _updateTripStatus(trip.id!, newStatus);
                    }
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: trip.id == null ? null : () => _confirmCancel(trip.id!),
                  icon: const Icon(Icons.cancel),
                  label: const Text('إلغاء'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الرحلات'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrips,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _myTrips.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('لا توجد رحلات حالياً.', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _myTrips.length,
                      itemBuilder: (context, index) => _buildTripCard(_myTrips[index]),
                    ),
            ),
    );
  }
}
