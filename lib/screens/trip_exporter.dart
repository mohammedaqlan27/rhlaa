// lib/screens/trip_exporter.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

// استورد ملف الخدمة مع alias بصيغة lower_case لتجنب تحذيرات linter
import '../utils/trip_exporter.dart' as exporter_service;

/// واجهة بسيطة لاستخدام خدمة التصدير (TripExporter) من utils.
/// توفر:
///  - زر لتصدير قائمة رحلات ممررة (قائمة عناصر Trip أو خريطة بيانات لكل رحلة)
///  - زر لتصدير رحلات السائق الحالي عبر استدعاء fetchTrips من الخدمة
class TripExporterScreen extends StatefulWidget {
  /// إذا أردت تمرير عناصر جاهزة للتصدير، مرّرها هنا (Trip أو Map)
  final List<dynamic>? itemsToExport;
  final String? driverIdForFetch; // إذا أردت زرًا لتحميل رحلات سائق محدد

  const TripExporterScreen({Key? key, this.itemsToExport, this.driverIdForFetch}) : super(key: key);

  @override
  State<TripExporterScreen> createState() => _TripExporterScreenState();
}

class _TripExporterScreenState extends State<TripExporterScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _exportItems(List<dynamic> items) async {
    if (items.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // بعض المشاريع تستخدم دالة التصدير لقبول List<Trip> فقط،
      // لذا نحاول تمرير قائمة Trip إن أمكن، وإلا نمرر العناصر كما هي.
      final List<Trip> tripsFromItems = items.whereType<Trip>().toList();
      if (tripsFromItems.isNotEmpty && tripsFromItems.length == items.length) {
        // كل العناصر هي Trip
        await exporter_service.TripExporter.exportToExcel(context, tripsFromItems);
      } else {
        // خلي الخدمة تتعامل مع عناصر Map أو Trip؛ نمرر القائمة كما هي
        await exporter_service.TripExporter.exportToExcel(context, items);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم بدء عملية التصدير')));
    } catch (e, st) {
      debugPrint('TripExporterScreen._exportItems error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'فشل التصدير: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ في التصدير: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportDriverTrips(String driverId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<Trip> trips = await exporter_service.TripExporter.fetchTrips(driverId);
      if (!mounted) return;

      if (trips.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد رحلات للتصدير لهذا السائق')));
        return;
      }

      await exporter_service.TripExporter.exportToExcel(context, trips);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم بدء تصدير رحلات السائق')));
    } catch (e, st) {
      debugPrint('TripExporterScreen._exportDriverTrips error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'فشل جلب/تصدير رحلات السائق: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل جلب/تصدير الرحلات: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Widget _buildExportButtons() {
    final items = widget.itemsToExport;
    final driverId = widget.driverIdForFetch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items != null && items.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _exportItems(items),
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download),
            label: Text(_isLoading ? 'جاري التصدير...' : 'تصدير العناصر الممررة'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        if (driverId != null && driverId.isNotEmpty) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _exportDriverTrips(driverId),
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_search),
            label: Text(_isLoading ? 'جاري التحميل والتصدير...' : 'تصدير رحلات السائق'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
        if ((items == null || items.isEmpty) && (driverId == null || driverId.isEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'لا توجد عناصر للتصدير. مرّر قائمة العناصر أو قدّم معرف السائق لعرض زر التصدير.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصدير الرحلات'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 12),
                      Text('جاري التحضير...', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  )
                : _buildExportButtons(),
          ),
        ),
      ),
    );
  }
}
