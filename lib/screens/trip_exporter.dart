// lib/screens/trip_exporter.dart
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_button.dart';
import '../utils/trip_exporter.dart' as exporter_service;

class TripExporterScreen extends StatefulWidget {
  final List<dynamic>? itemsToExport;
  final String? driverIdForFetch;

  const TripExporterScreen({super.key, this.itemsToExport, this.driverIdForFetch});

  @override
  State<TripExporterScreen> createState() => _TripExporterScreenState();
}

class _TripExporterScreenState extends State<TripExporterScreen> {
  bool _isLoading = false;
  String? _error;

  static const Color _logoBlue = Color(0xFF1E70B8);
  static const Color _logoTeal = Color(0xFF17A5A3);
  static const Color _baseBg = Color(0xFFF1F5F9);

  Future<void> _exportItems(List<dynamic> items) async {
    if (items.isEmpty) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final List<Trip> tripsFromItems = items.whereType<Trip>().toList();
      if (tripsFromItems.isNotEmpty && tripsFromItems.length == items.length) {
        await exporter_service.TripExporter.exportToExcel(context, tripsFromItems);
      } else {
        await exporter_service.TripExporter.exportToExcel(context, items);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم بدء عملية تصدير ملف الـ Excel', style: TextStyle(fontFamily: 'Cairo'))));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'فشل عملية التصدير: $e'; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportDriverTrips(String driverId) async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final List<Trip> trips = await exporter_service.TripExporter.fetchTrips(driverId);
      if (!mounted) return;

      if (trips.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد رحلات مسجلة ككابتن للتصدير', style: TextStyle(fontFamily: 'Cairo'))));
        return;
      }

      await exporter_service.TripExporter.exportToExcel(context, trips);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تصدير كشف رحلات السائق بنجاح', style: TextStyle(fontFamily: 'Cairo'))));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'حدث خطأ أثناء المزامنة: $e'; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.itemsToExport;
    final driverId = widget.driverIdForFetch;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _baseBg,
        appBar: AppBar(
          title: const Text('تصدير كشوفات البيانات', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: _baseBg,
          foregroundColor: _logoBlue,
          elevation: 0,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_logoBlue)),
                const SizedBox(height: 16),
                const Text('جاري معالجة وتوليد ملف كشوفات Excel...', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54)),
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.cloud_download_rounded, size: 56, color: _logoTeal),
                const SizedBox(height: 14),
                const Text(
                  'مركز تصدير التقارير الخارجية',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: _logoBlue),
                ),
                const SizedBox(height: 24),
                if (items != null && items.isNotEmpty) ...[
                  CustomButton(
                    onPressed: () => _exportItems(items),
                    text: 'تصدير الرحلات المحددة الحالية',
                    icon: Icons.grid_on_rounded,
                  ),
                  const SizedBox(height: 12),
                ],
                if (driverId != null && driverId.isNotEmpty) ...[
                  CustomButton(
                    onPressed: () => _exportDriverTrips(driverId),
                    text: 'تصدير سجل رحلات الكابتن بالكامل',
                    icon: Icons.analytics_rounded,
                    backgroundColor: _logoTeal,
                  ),
                ],
                if ((items == null || items.isEmpty) && (driverId == null || driverId.isEmpty))
                  const Text(
                    'لا توجد بيانات ممررة جاهزة للتصدير حالياً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black45),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}