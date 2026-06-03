// lib/screens/trip_history_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/trip_details_view_screen.dart';
import '../models/trip.dart';
import '../utils/trip_exporter.dart' as exporter_service;

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  Future<List<Trip>>? _tripsFuture;
  String? userId;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      // استدعاء دالة جلب الرحلات من ملف utils/trip_exporter.dart
      _tripsFuture = exporter_service.TripExporter.fetchTrips(userId!);
    } else {
      _tripsFuture = Future.value(<Trip>[]);
    }
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final dateText = trip.date != null
        ? '${trip.date!.year}-${trip.date!.month.toString().padLeft(2, '0')}-${trip.date!.day.toString().padLeft(2, '0')}'
        : (trip.departureTime != null
            ? '${trip.departureTime!.year}-${trip.departureTime!.month.toString().padLeft(2, '0')}-${trip.departureTime!.day.toString().padLeft(2, '0')}'
            : 'غير محدد');

    final title = (trip.title ?? '').isNotEmpty ? trip.title! : '${trip.origin} → ${trip.destination}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🚗 $title', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('📍 من: ${trip.origin}  →  إلى: ${trip.destination}'),
          Text('📅 التاريخ: $dateText'),
          Text('🕒 الوقت: ${trip.time ?? 'غير محدد'}'),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripDetailsViewScreen(tripData: trip.toMap()),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('عرض التفاصيل'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                // مكان لفتح شاشة التقييم أو أي إجراء آخر
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('تقييم'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _exportTrips(BuildContext context) async {
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ يجب تسجيل الدخول أولاً لتصدير الرحلات')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // جلب الرحلات من الخدمة ثم تصديرها
      final trips = await exporter_service.TripExporter.fetchTrips(userId!);
      if (!mounted) return;

      if (trips.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد رحلات لتصدير.')),
        );
      } else {
        // استدعاء دالة التصدير الموجودة في utils/trip_exporter.dart
        await exporter_service.TripExporter.exportToExcel(context, trips);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تصدير الملف بنجاح')),
        );
      }
    } catch (e, st) {
      debugPrint('TripHistoryScreen._exportTrips error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('❌ يجب تسجيل الدخول لعرض السجل')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('📜 سجل الرحلات'), backgroundColor: Colors.blue.shade900),
      body: FutureBuilder<List<Trip>>(
        future: _tripsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return const Center(child: Text('لا توجد رحلات في السجل.'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) => _buildTripCard(context, trips[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : () => _exportTrips(context),
                    icon: _isExporting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.table_chart),
                    label: Text(_isExporting ? 'جارٍ التصدير...' : '📤 تصدير إلى Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
