// lib/screens/agency/agency_bookings_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// استيراد نموذج الحجز ومخطط الأداء
import '../../models/booking_model.dart';
import '/widgets/agency/web/web_performance_chart.dart';

class AgencyBookingsManagementScreen extends StatefulWidget {
  const AgencyBookingsManagementScreen({super.key, required String agencyId});

  @override
  State<AgencyBookingsManagementScreen> createState() => _AgencyBookingsManagementScreenState();
}

class _AgencyBookingsManagementScreenState extends State<AgencyBookingsManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _cardBg = Color(0xFF181B20);

  String _selectedFilter = 'الكل';

  void _showSnack(String msg, {Color color = Colors.green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // دالة تأكيد إلغاء الحجز
  Future<bool> _confirmCancelBookingDialog(String bookingId) async {
    if (!mounted) return false;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('تأكيد إلغاء الحجز', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل تريد بالتأكيد إلغاء هذا الحجز؟ سيتم إعلام العميل بالحالة.', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('لا', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('نعم، إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final agencyId = _auth.currentUser?.uid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        appBar: AppBar(
          backgroundColor: _primaryBlue,
          title: const Text('إدارة الحجوزات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (val) => setState(() => _selectedFilter = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'الكل', child: Text('جميع الحجوزات', style: TextStyle(fontFamily: 'Cairo'))),
                const PopupMenuItem(value: 'مؤكد', child: Text('الحجوزات المؤكدة', style: TextStyle(fontFamily: 'Cairo'))),
                const PopupMenuItem(value: 'معلق', child: Text('الحجوزات المعلقة', style: TextStyle(fontFamily: 'Cairo'))),
                const PopupMenuItem(value: 'ملغي', child: Text('الحجوزات الملغية', style: TextStyle(fontFamily: 'Cairo'))),
              ],
              icon: const Icon(Icons.filter_list),
            ),
          ],
        ),
        body: agencyId == null
            ? const Center(child: Text('يرجى تسجيل الدخول أولاً', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')))
            : StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('bookings').where('agencyId', isEqualTo: agencyId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _accentTeal));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const SizedBox(
                    height: 220,
                    child: WebPerformanceChart(),
                  ),
                  const SizedBox(height: 40),
                  const Center(
                    child: Text('لا توجد حجوزات مسجلة حتى الآن', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  ),
                ],
              );
            }

            final docs = snapshot.data!.docs;

            // تصفية النتائج بناءً على الحالة المختارة مع حماية القيم الفارغة
            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return false;

              final status = (data['bookingStatus'] ?? data['status'] ?? 'pending').toString();
              if (_selectedFilter == 'الكل') return true;

              if (_selectedFilter == 'مؤكد' && (status == 'confirmed' || status == 'مؤكد')) return true;
              if (_selectedFilter == 'معلق' && (status == 'pending' || status == 'معلق')) return true;
              if (_selectedFilter == 'ملغي' && (status == 'cancelled' || status == 'ملغي')) return true;

              return status == _selectedFilter;
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 📊 إدراج مخطط الأداء الأسبوعي في الأعلى
                const SizedBox(
                  height: 220,
                  child: WebPerformanceChart(),
                ),
                const SizedBox(height: 16),

                // عنوان فرعي يوضح عدد الحجوزات الظاهرة حالياً
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'قائمة الحجوزات ($_selectedFilter)',
                        style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'العدد: ${filteredDocs.length}',
                        style: const TextStyle(color: _accentTeal, fontFamily: 'Cairo', fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // عرض الحجوزات أو رسالة عدم وجود مطابقة للفلتر
                if (filteredDocs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('لا توجد حجوزات تطابق الفلتر الحالي', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                    ),
                  )
                else
                  ...filteredDocs.map((doc) {
                    final booking = Booking.fromDocument(doc);

                    return Card(
                      color: _cardBg,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'رقم الحجز: #${doc.id.length >= 6 ? doc.id.substring(0, 6) : doc.id}',
                                  style: const TextStyle(color: _accentTeal, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    booking.bookingStatus,
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),
                            Text(
                              'الراكب: ${booking.passengerNickname.isNotEmpty ? booking.passengerNickname : "غير معروف"}',
                              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'معرف الرحلة: ${booking.tripId.length > 8 ? booking.tripId.substring(0, 8) : booking.tripId}',
                              style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'عدد المقاعد: ${booking.bookedSeatsCount} | الإجمالي: ${booking.totalPrice} ريال',
                              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                                  icon: const Icon(Icons.cancel, size: 16),
                                  label: const Text('إلغاء الحجز', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                  onPressed: () async {
                                    final confirmed = await _confirmCancelBookingDialog(doc.id);
                                    if (!confirmed) return;
                                    try {
                                      await _firestore.collection('bookings').doc(doc.id).update({
                                        'bookingStatus': 'cancelled',
                                        'updatedAt': FieldValue.serverTimestamp(),
                                      });
                                      _showSnack('تم إلغاء الحجز بنجاح', color: Colors.orange);
                                    } catch (e) {
                                      _showSnack('فشل إلغاء الحجز: $e', color: Colors.red);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: _accentTeal),
                                  icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                                  label: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white)),
                                  onPressed: () async {
                                    try {
                                      await _firestore.collection('bookings').doc(doc.id).update({
                                        'bookingStatus': 'confirmed',
                                        'updatedAt': FieldValue.serverTimestamp(),
                                      });
                                      _showSnack('تم تأكيد الحجز بنجاح');
                                    } catch (e) {
                                      _showSnack('فشل تأكيد الحجز: $e', color: Colors.red);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
