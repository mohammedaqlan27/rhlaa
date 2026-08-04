// lib/screens/my_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../services/booking_service.dart';
import '../screens/rating_screen.dart';
import '../models/booking_model.dart';
import '../models/trip.dart';
import '../widgets/shared/app_card.dart';
import 'trip_details_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  late TabController _tabController;
  bool _isCancelling = false;

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bookingsFuture = _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _bookingsFuture = _fetchBookings();
    });
    await _bookingsFuture;
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final List<Map<String, dynamic>> allBookings = [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in snapshot.docs) {
        final booking = Booking.fromDocument(doc);
        final tripSnap = await FirebaseFirestore.instance.collection('trips').doc(booking.tripId).get();
        if (tripSnap.exists) {
          allBookings.add({
            'booking': booking,
            'trip': Trip.fromDocument(tripSnap),
            'raw': doc.data(),
          });
        }
      }
      return allBookings;
    } catch (e) {
      debugPrint('Error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'حجوزاتي',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryBlue,
          indicatorWeight: 3,
          labelColor: _primaryBlue,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'الرحلات القادمة'),
            Tab(text: 'الرحلات السابقة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(isPast: false),
          _buildBookingsList(isPast: true),
        ],
      ),
    );
  }

  Widget _buildBookingsList({required bool isPast}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: _primaryBlue,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryBlue));
          }

          final list = snapshot.data ?? [];
          final filteredList = list.where((item) {
            final status = (item['booking'] as Booking).bookingStatus.toLowerCase();
            final isDone = status.contains('مكتمل') || status.contains('complete') || status.contains('ملغي');
            return isPast ? isDone : !isDone;
          }).toList();

          if (filteredList.isEmpty) return _buildEmptyState(isPast);

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildModernBookingCard(filteredList[index]),
          );
        },
      ),
    );
  }

  Widget _buildModernBookingCard(Map<String, dynamic> data) {
    final Booking booking = data['booking'];
    final Trip trip = data['trip'];

    Color statusColor = Colors.orange;
    if (booking.bookingStatus.contains('مؤكد')) statusColor = Colors.green;
    if (booking.bookingStatus.contains('ملغي')) statusColor = Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: _primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إلى ${trip.destination}',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                _buildStatusBadge(booking.bookingStatus, statusColor),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_pin, 'الكابتن', trip.driverName),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow(Icons.calendar_today, 'التاريخ', trip.date as String)),
                    Expanded(child: _buildInfoRow(Icons.event_seat, 'المقاعد', '${booking.bookedSeatsCount} مقاعد')),
                  ],
                ),
                const Divider(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'التفاصيل',
                        icon: Icons.info_outline,
                        color: _primaryBlue,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isDone(booking.bookingStatus))
                      Expanded(
                        child: _buildActionButton(
                          label: 'إلغاء',
                          icon: Icons.close,
                          color: Colors.redAccent,
                          onTap: () => _confirmAndCancel(context, booking),
                        ),
                      )
                    else if (booking.bookingStatus.contains('مكتمل'))
                      Expanded(
                        child: _buildActionButton(
                          label: 'تقييم',
                          icon: Icons.star_border,
                          color: _accentTeal,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RatingScreen(tripId: trip.id, targetUserId: trip.driverId, userType: 'سائق'))),
                        ),
                      ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: booking.id));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 تم نسخ رقم الحجز')));
                      },
                      icon: const Icon(Icons.copy_all, size: 20, color: Colors.grey),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // تم تصحيح هذه الدالة بإضافة الأقواس المتعرجة {} لجعل البارامترات مسماة
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isPast) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isPast ? Icons.history : Icons.calendar_today, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            isPast ? 'لا توجد رحلات سابقة' : 'لا توجد حجوزات نشطة حالياً',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  bool isDone(String status) {
    final s = status.toLowerCase();
    return s.contains('مكتمل') || s.contains('complete') || s.contains('ملغي');
  }

  Future<void> _confirmAndCancel(BuildContext context, Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد أنك تريد إلغاء هذا الحجز؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final result = await BookingService().cancelBooking(bookingId: booking.id, passengerId: booking.passengerId);
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إلغاء الحجز بنجاح')));
        _refresh();
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}