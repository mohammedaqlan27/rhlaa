// lib/utils/trip_exporter.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trip.dart';

class TripExporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =================== Helpers ===================

  static DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static List<dynamic> _toList(dynamic v) {
    if (v == null) return <dynamic>[];
    if (v is List) return v;
    return <dynamic>[];
  }

  // =================== Public API ===================

  /// جلب الرحلات المرتبطة بالمستخدم (مثال: رحلات السائق)
  /// يعيد قائمة رحلات أو قائمة فارغة عند الخطأ
  static Future<List<Trip>> fetchTrips(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('trips')
          .where('driverId', isEqualTo: userId)
          .orderBy('departureTime')
          .get();

      return snapshot.docs.map((d) => Trip.fromDocument(d)).toList();
    } catch (e, st) {
      debugPrint('TripExporter.fetchTrips error: $e\n$st');
      return <Trip>[];
    }
  }

  /// (مؤقت) تصدير إلى PDF — احتفظت بالمكان المخصص للوظيفة
  static Future<void> exportToPdf(BuildContext context, List<Trip> trips) async {
    if (!mountedContext(context)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة تصدير PDF قريباً')),
    );
  }

  /// تصدير قائمة الرحلات إلى ملف Excel وحفظه في مجلد مؤقت
  /// يقبل عناصر من نوع Trip أو Map<String,dynamic> أو خليط منهما
  static Future<void> exportToExcel(BuildContext context, List<dynamic> items) async {
    if (items.isEmpty) {
      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد رحلات للتصدير')),
      );
      return;
    }

    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];

      // بعض إصدارات المكتبة قد لا تسمح بتعيين الاسم؛ نتعامل مع ذلك بهدوء
      try {
        sheet.name = 'الرحلات';
      } catch (_) {}

      // رؤوس الأعمدة
      final headers = [
        'رقم الرحلة',
        'العنوان',
        'الانطلاق → الوجهة',
        'التاريخ',
        'الوقت',
        'السعر',
        'حالة',
        'ملاحظات'
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet.getRangeByIndex(1, c + 1).setText(headers[c]);
      }

      final DateFormat dateFmt = DateFormat('yyyy-MM-dd');
      final DateFormat timeFmt = DateFormat('HH:mm');

      for (int i = 0; i < items.length; i++) {
        final item = items[i];

        String id = '-';
        String title = '-';
        String route = '-';
        String dateText = '-';
        String timeText = '-';
        double price = 0.0;
        String status = '-';
        String notes = '-';

        try {
          if (item is Trip) {
            id = item.id ?? '-';
            title = (_toString(item.title)).isNotEmpty ? _toString(item.title) : '-';
            final origin = _toString(item.origin);
            final dest = _toString(item.destination);
            route = (origin.isNotEmpty || dest.isNotEmpty) ? '$origin → $dest' : '-';

            final DateTime? dt = item.date ?? item.departureTime;
            if (dt != null) {
              dateText = dateFmt.format(dt);
              timeText = timeFmt.format(dt);
            } else {
              dateText = '-';
              timeText = (_toString(item.time)).isNotEmpty ? _toString(item.time) : '-';
            }

            price = _toDouble(item.price);
            status = (_toString(item.status)).isNotEmpty ? _toString(item.status) : '-';
            notes = (_toString(item.description)).isNotEmpty ? _toString(item.description) : '-';
          } else if (item is Map<String, dynamic>) {
            id = _toString(item['id'] ?? item['tripId'] ?? '-');
            title = _toString(item['title'] ?? item['tripTitle'] ?? '-');

            final origin = _toString(item['origin'] ?? '');
            final dest = _toString(item['destination'] ?? '');
            route = (origin.isNotEmpty || dest.isNotEmpty) ? '$origin → $dest' : '-';

            final rawDate = item['date'] ?? item['departureTime'] ?? item['createdAt'];
            if (rawDate != null) {
              final dt = _toDateTime(rawDate);
              dateText = dateFmt.format(dt);
              timeText = timeFmt.format(dt);
            } else {
              dateText = '-';
              timeText = _toString(item['time'] ?? '');
            }

            price = _toDouble(item['price'] ?? item['fare'] ?? item['cost']);
            status = _toString(item['status'] ?? item['state'] ?? '-');
            notes = _toString(item['notes'] ?? item['description'] ?? '');
          } else {
            // عنصر غير متوقع: نحاول تحويله إلى String وعرضه في العمود الملاحظات
            notes = _toString(item);
          }
        } catch (e, st) {
          debugPrint('TripExporter.parse item error at index $i: $e\n$st');
        }

        sheet.getRangeByIndex(i + 2, 1).setText(id);
        sheet.getRangeByIndex(i + 2, 2).setText(title);
        sheet.getRangeByIndex(i + 2, 3).setText(route);
        sheet.getRangeByIndex(i + 2, 4).setText(dateText);
        sheet.getRangeByIndex(i + 2, 5).setText(timeText);
        sheet.getRangeByIndex(i + 2, 6).setNumber(price);
        sheet.getRangeByIndex(i + 2, 7).setText(status);
        sheet.getRangeByIndex(i + 2, 8).setText(notes);
      }

      // حفظ المصنف إلى بايتات
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // احفظ الملف في مجلد مؤقت
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '${tempDir.path}/trips_export_$timestamp.xlsx';
      final File file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تصدير البيانات بنجاح: $filePath')),
      );
    } catch (e, st) {
      debugPrint('TripExporter.exportToExcel error: $e\n$st');
      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في التصدير: $e')),
      );
    }
  }

  // Helper to check if context is still mounted (we can't access mounted from static)
  static bool mountedContext(BuildContext context) {
    try {
      return context.findRenderObject() != null;
    } catch (_) {
      return false;
    }
  }
}
