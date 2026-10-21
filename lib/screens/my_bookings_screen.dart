// lib/screens/my_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../providers/booking_provider.dart';
import '../screens/rating_screen.dart';
import '../models/booking_model.dart';
import '../models/trip.dart';
import 'trip_details_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, Trip> _tripsCache = {};
  bool _isLoadingTrips = false;

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && mounted) {
        context.read<BookingProvider>().listenToUserBookings(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// جلب تفاصيل الرحلات المرتبطة بالحجوزات دفعة واحدة مع حماية ضد التكرار المستمر
  Future<void> _fetchTripsForBookings(List<Booking> bookings) async {
    if (_isLoadingTrips) return;

    final missingTripIds = bookings
        .map((b) => b.tripId)
        .where((id) => id.isNotEmpty && !_tripsCache.containsKey(id))
        .toSet();

    if (missingTripIds.isEmpty) return;

    if (mounted) setState(() => _isLoadingTrips = true);
    try {
      final chunks = _chunkList(missingTripIds.toList(), 10);
      for (final chunk in chunks) {
        final snap = await FirebaseFirestore.instance
            .collection('trips')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in snap.docs) {
          _tripsCache[doc.id] = Trip.fromDocument(doc);
        }
      }
    } catch (e) {
      debugPrint('Error fetching cached trips: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTrips = false);
    }
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
        body: Consumer<BookingProvider>(
          builder: (context, bookingProvider, child) {
            final bookings = bookingProvider.userBookings;

            // تشغيل الجلب فقط إذا وجدنا حجوزات جديدة غير مخزنة كاش
            if (bookings.isNotEmpty) {
              final hasMissing = bookings.any((b) => b.tripId.isNotEmpty && !_tripsCache.containsKey(b.tripId));
              if (hasMissing && !_isLoadingTrips) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fetchTripsForBookings(bookings);
                });
              }
            }

            return Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingsList(bookings, isPast: false),
                    _buildBookingsList(bookings, isPast: true),
                  ],
                ),
                if (bookingProvider.isLoading || _isLoadingTrips)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(color: _primaryBlue),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<Booking> allBookings, {required bool isPast}) {
    final filteredBookings = allBookings.where((booking) {
      final isDone = _isDoneStatus(booking.bookingStatus);
      return isPast ? isDone : !isDone;
    }).toList();

    if (filteredBookings.isEmpty) {
      return _buildEmptyState(isPast);
    }

    return RefreshIndicator(
      onRefresh: () async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && mounted) {
          context.read<BookingProvider>().listenToUserBookings(uid);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      },
      color: _primaryBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredBookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final booking = filteredBookings[index];
          final trip = _tripsCache[booking.tripId] ??
              Trip(
                id: booking.tripId,
                driverId: booking.driverId,
                driverName: 'جاري التحميل...',
                destination: 'غير محدد',
                departureTime: null,
                status: '',
              );
          return _buildModernBookingCard(booking, trip);
        },
      ),
    );
  }

  Widget _buildModernBookingCard(Booking booking, Trip trip) {
    final String driverName = (trip.driverName ?? '').trim().isEmpty ? 'غير معروف' : trip.driverName!;
    final String destination = (trip.destination ?? '').trim().isEmpty ? 'غير محدد' : trip.destination!;

    final String dateStr = trip.departureTime != null
        ? intl.DateFormat('yyyy-MM-dd | hh:mm a', 'ar').format(trip.departureTime!)
        : '-';

    final String bookingStatus = booking.bookingStatus;
    final int seatsCount = booking.bookedSeatsCount;

    Color statusColor = Colors.orange;
    final statusLower = bookingStatus.toLowerCase();
    if (statusLower.contains('مؤكد') || statusLower.contains('confirmed')) statusColor = Colors.green;
    if (statusLower.contains('ملغي') || statusLower.contains('cancel') || statusLower.contains('rejected')) {
      statusColor = Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
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
                    const Icon(Icons.directions_bus_outlined, color: _primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إلى $destination',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                _buildStatusBadge(bookingStatus, statusColor),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_pin, 'الكابتن', driverName),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow(Icons.calendar_today, 'التاريخ', dateStr)),
                    Expanded(child: _buildInfoRow(Icons.event_seat, 'المقاعد', '$seatsCount مقاعد')),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'التفاصيل',
                        icon: Icons.info_outline,
                        color: _primaryBlue,
                        onTap: () {
                          if (trip.id.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_isDoneStatus(bookingStatus))
                      Expanded(
                        child: _buildActionButton(
                          label: 'إلغاء',
                          icon: Icons.close_rounded,
                          color: Colors.redAccent,
                          onTap: () => _confirmAndCancel(context, booking),
                        ),
                      )
                    else if (statusLower.contains('مكتمل') || statusLower.contains('complete'))
                      Expanded(
                        child: _buildActionButton(
                          label: 'تقييم',
                          icon: Icons.star_border_rounded,
                          color: _accentTeal,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RatingScreen(
                                tripId: trip.id,
                                targetUserId: trip.driverId,
                                userType: 'سائق',
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'نسخ رقم الحجز',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: booking.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📋 تم نسخ رقم الحجز بنجاح', style: TextStyle(fontFamily: 'Cairo')),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 20, color: Colors.grey),
                    ),
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
    final display = status.isEmpty ? 'غير معروف' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(display, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
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
          Icon(isPast ? Icons.history_rounded : Icons.calendar_today_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isPast ? 'لا توجد رحلات سابقة مسجلة' : 'لا توجد حجوزات نشطة حالياً',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  bool _isDoneStatus(String? status) {
    final s = (status ?? '').toLowerCase();
    return s.contains('مكتمل') ||
        s.contains('complete') ||
        s.contains('ملغي') ||
        s.contains('cancel') ||
        s.contains('rejected');
  }

  Future<void> _confirmAndCancel(BuildContext context, Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الحجز؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final provider = context.read<BookingProvider>();
    final success = await provider.cancelUserBooking(booking.id, uid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✅ تم إلغاء الحجز بنجاح' : (provider.errorMessage ?? 'فشل إلغاء الحجز'),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}