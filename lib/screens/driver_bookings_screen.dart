// lib/screens/driver_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/booking_model.dart';
import '../models/app_user.dart';

class DriverBookingsScreen extends StatefulWidget {
  final String tripId;

  const DriverBookingsScreen({super.key, required this.tripId});

  @override
  State<DriverBookingsScreen> createState() => _DriverBookingsScreenState();
}

class _DriverBookingsScreenState extends State<DriverBookingsScreen> {
  // ألوان هوية رحلاء البصرية
  final Color _logoBlue = const Color(0xFF1E70B8);
  final Color _logoTeal = const Color(0xFF17A5A3);
  final Color _logoGreen = const Color(0xFF4EBF64);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  String _selectedFilter = 'الكل';

  // متغيرات الإعدادات الجديدة
  bool _autoAccept = false;
  String _acceptPreference = 'الكل'; // 'الكل', 'عائلات', 'أفراد'
  bool _isUpdatingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadTripSettings();
  }

  // جلب إعدادات القبول الحالية من مستند الرحلة
  Future<void> _loadTripSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('trips').doc(widget.tripId).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _autoAccept = data?['autoAccept'] ?? false;
          _acceptPreference = data?['acceptPreference'] ?? 'الكل';
        });
      }
    } catch (e) {
      debugPrint('Error loading trip settings: $e');
    }
  }

  // تحديث إعدادات القبول في Firestore
  Future<void> _updateTripSettings(bool auto, String pref) async {
    setState(() => _isUpdatingSettings = true);
    try {
      await FirebaseFirestore.instance.collection('trips').doc(widget.tripId).update({
        'autoAccept': auto,
        'acceptPreference': pref,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تحديث إعدادات القبول بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingSettings = false);
    }
  }

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    } catch (_) {}
    return DateTime.now();
  }

  Future<List<Map<String, dynamic>>> _fetchBookingsWithTripInfo(String tripId) async {
    final firestore = FirebaseFirestore.instance;
    final tripDoc = await firestore.collection('trips').doc(tripId).get();
    final tripData = tripDoc.data();

    final tripTitle = tripData?['title'] ?? tripData?['tripTitle'] ?? 'رحلة غير معروفة';
    final tripDestination = tripData?['destination'] ?? tripData?['to'] ?? '';

    QuerySnapshot bookingSnapshot;
    try {
      bookingSnapshot = await firestore.collection('bookings').where('tripId', isEqualTo: tripId).get();
      if (bookingSnapshot.docs.isEmpty) {
        bookingSnapshot = await firestore.collection('bookings').where('trip_id', isEqualTo: tripId).get();
      }
    } catch (e) {
      return [];
    }

    final bookings = <Map<String, dynamic>>[];
    for (final doc in bookingSnapshot.docs) {
      try {
        final booking = Booking.fromDocument(doc);
        String passengerName = 'راكب غير معروف';
        String passengerPhone = 'لا يوجد رقم';

        if (booking.passengerId.isNotEmpty) {
          final userDoc = await firestore.collection('users').doc(booking.passengerId).get();
          if (userDoc.exists) {
            final appUser = AppUser.fromDocument(userDoc);
            passengerName = appUser.nickname ?? passengerName;
            passengerPhone = appUser.mobileNumber ?? passengerPhone;
          }
        }

        bookings.add({
          'booking': booking,
          'passengerName': passengerName,
          'passengerPhone': passengerPhone,
          'tripTitle': tripTitle,
          'tripDestination': tripDestination,
        });
      } catch (_) {}
    }
    return bookings;
  }

  // --- واجهة إعدادات القبول التلقائي (الجديدة) ---
  Widget _buildSettingsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _logoBlue.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: _logoBlue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: _logoTeal),
                  const SizedBox(width: 8),
                  const Text('القبول التلقائي للركاب',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Switch.adaptive(
                value: _autoAccept,
                activeColor: _logoGreen,
                onChanged: (val) {
                  setState(() => _autoAccept = val);
                  _updateTripSettings(val, _acceptPreference);
                },
              ),
            ],
          ),
          if (_autoAccept) ...[
            const Divider(height: 24),
            const Text('تفضيل نوع الركاب للقبول الآلي:',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['الكل', 'أفراد', 'عائلات'].map((type) {
                bool isSelected = _acceptPreference == type;
                return GestureDetector(
                  onTap: () {
                    setState(() => _acceptPreference = type);
                    _updateTripSettings(_autoAccept, type);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _logoBlue : _backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? _logoBlue : Colors.grey.shade300),
                    ),
                    child: Text(type,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                            color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔍 تصفية الحجوزات حسب الحالة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.clear_all, color: _logoBlue),
                title: const Text('عرض الكل', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () { setState(() => _selectedFilter = 'الكل'); Navigator.pop(context); },
              ),
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: _logoGreen),
                title: const Text('المؤكدة فقط', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () { setState(() => _selectedFilter = 'مؤكد'); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                title: const Text('المعلقة / قيد الانتظار', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () { setState(() => _selectedFilter = 'pending'); Navigator.pop(context); },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildBookingCard(Map<String, dynamic> data) {
    final booking = data['booking'] as Booking;
    final passengerName = data['passengerName'] as String;
    final passengerPhone = data['passengerPhone'] as String;
    final tripTitle = data['tripTitle'] as String;
    final tripDestination = data['tripDestination'] as String;

    final createdAtDt = _toDateTime(booking.createdAt);
    final createdAt = DateFormat('yyyy-MM-dd – hh:mm a', 'ar').format(createdAtDt);

    final status = (booking.bookingStatus ?? '').toLowerCase();
    final bool isConfirmed = status == 'مؤكد' || status == 'confirmed';

    if (_selectedFilter == 'مؤكد' && !isConfirmed) return const SizedBox.shrink();
    if (_selectedFilter == 'pending' && isConfirmed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🧑‍💼 $passengerName', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConfirmed ? _logoGreen.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isConfirmed ? 'مؤكد' : 'قيد الانتظار',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isConfirmed ? _logoGreen : Colors.orange.shade800, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_seat_outlined, size: 16, color: _logoTeal),
                const SizedBox(width: 6),
                Text('المقاعد المحجوزة: ${booking.bookedSeatsCount ?? 0}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_android_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('الهاتف: $passengerPhone', style: const TextStyle(fontSize: 13, color: Colors.black)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('وقت الطلب: $createdAt', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Divider(height: 20),
            Text('🛣️ $tripTitle ← $tripDestination', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _logoBlue, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('طلبات حجز الركاب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterBottomSheet,
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSettingsHeader(), // عرض لوحة الإعدادات في الأعلى
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchBookingsWithTripInfo(widget.tripId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _logoBlue));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('لا توجد أي طلبات حجز لهذه الرحلة حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  final bookings = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) => buildBookingCard(bookings[index]),
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