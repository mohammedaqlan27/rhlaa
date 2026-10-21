// lib/screens/trip_history_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/trip_details_screen.dart';
import '../models/trip.dart';
import '../utils/trip_exporter.dart' as exporter_service;

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  Future<List<Trip>>? _tripsFuture;
  String? userId;
  bool _isExporting = false;

  // لوحة الألوان الموحدة للتطبيق
  static const Color _primaryBlue = Color(0xFF1E70B8);
  static const Color _accentTeal = Color(0xFF17A5A3);
  static const Color _bgGrey = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    _loadData();
  }

  void _loadData() {
    if (userId != null) {
      _tripsFuture = exporter_service.TripExporter.fetchTrips(userId!);
    } else {
      _tripsFuture = Future.value(<Trip>[]);
    }
  }

  // تحسين تصميم بطاقة الرحلة (نقطة 3: تفاصيل الرحلة)
  Widget _buildTripCard(BuildContext context, Trip trip) {
    final dateText = trip.date != null
        ? '${trip.date!.year}-${trip.date!.month.toString().padLeft(2, '0')}-${trip.date!.day.toString().padLeft(2, '0')}'
        : 'تاريخ غير محدد';

    // تحديد لون الحالة (Micro-interaction)
    Color statusColor = _accentTeal;
    String statusLabel = trip.status.isNotEmpty ? trip.status : 'مكتملة';
    if (statusLabel.contains('ملغى') || statusLabel.contains('Cancelled')) {
      statusColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // الجزء العلوي: المسار والحالة
            Container(
              padding: const EdgeInsets.all(16),
              color: _primaryBlue.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${trip.origin} ➔ ${trip.destination}',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: _primaryBlue),
                    ),
                  ),
                  _buildStatusBadge(statusLabel, statusColor),
                ],
              ),
            ),
            // الجزء الأوسط: التفاصيل التقنية
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(Icons.calendar_today_outlined, 'التاريخ', dateText),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.access_time_rounded, 'وقت الانطلاق', trip.time ?? 'غير محدد'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.directions_car_filled_outlined, 'نوع المركبة', trip.vehicleType.isNotEmpty ? trip.vehicleType : 'خصوصي'),
                  const Divider(height: 30),
                  // الأزرار التفاعلية
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: 'تقييم',
                          icon: Icons.star_border_rounded,
                          color: _accentTeal,
                          onTap: () { /* فتح شاشة التقييم */ },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
      ],
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
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

  // دالة التصدير (تم الحفاظ عليها كما هي مع تحسين الـ UI)
  Future<void> _exportTrips(BuildContext context) async {
    if (userId == null) return;
    setState(() => _isExporting = true);
    try {
      final trips = await exporter_service.TripExporter.fetchTrips(userId!);
      if (mounted) {
        if (trips.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد رحلات لتصديرها')));
        } else {
          await exporter_service.TripExporter.exportToExcel(context, trips);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تصدير الملف بنجاح')));
        }
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
        title: const Text('سجل الرحلات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _textDark, fontSize: 18)),
      ),
      body: FutureBuilder<List<Trip>>(
        future: _tripsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryBlue));
          }

          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('سجل الرحلات فارغ حالياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(() => _loadData()),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    itemBuilder: (context, index) => _buildTripCard(context, trips[index]),
                  ),
                ),
              ),
              // زر التصدير الاحترافي في الأسفل
              _buildExportSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : () => _exportTrips(context),
        icon: _isExporting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.table_chart_outlined),
        label: Text(_isExporting ? 'جاري التصدير...' : 'تصدير السجل إلى Excel', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}