// lib/utils/trip_exporter.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trip.dart';

class TripExporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة تصدير PDF قريباً')),
    );
  }

  /// تصدير قائمة الرحلات إلى ملف Excel وحفظه في مجلد مؤقت
  static Future<void> exportToExcel(BuildContext context, List<Trip> trips) async {
    if (trips.isEmpty) {
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
      sheet.getRangeByIndex(1, 1).setText('رقم الرحلة');
      sheet.getRangeByIndex(1, 2).setText('الوجهة');
      sheet.getRangeByIndex(1, 3).setText('التاريخ');
      sheet.getRangeByIndex(1, 4).setText('الوقت');
      sheet.getRangeByIndex(1, 5).setText('السعر');

      final DateFormat dateFmt = DateFormat('yyyy-MM-dd');

      for (int i = 0; i < trips.length; i++) {
        final trip = trips[i];

        final String tripId = trip.id ?? '-';
        final String origin = (trip.origin ?? '').isNotEmpty ? trip.origin : '';
        final String destination = (trip.destination ?? '').isNotEmpty ? trip.destination : '';
        final String route = (origin.isNotEmpty || destination.isNotEmpty) ? '$origin → $destination' : '-';

        // تاريخ آمن: نتحقق من date ثم departureTime ثم createdAt داخل نموذج Trip
        String dateText = '-';
        DateTime? dt;
        if (trip.date != null) dt = trip.date;
        else if (trip.departureTime != null) dt = trip.departureTime;
        if (dt != null) {
          try {
            dateText = dateFmt.format(dt);
          } catch (_) {
            dateText = dt.toIso8601String();
          }
        }

        // وقت الرحلة: استخدم الحقل time إن كان غير فارغ وإلا حاول استخراج من departureTime
        String timeText = '-';
        if ((trip.time ?? '').isNotEmpty) {
          timeText = trip.time;
        } else if (trip.departureTime != null) {
          try {
            timeText = DateFormat('HH:mm').format(trip.departureTime!);
          } catch (_) {
            timeText = '-';
          }
        }

        // سعر آمن
        final double price = (trip.price.isFinite) ? trip.price : 0.0;

        sheet.getRangeByIndex(i + 2, 1).setText(tripId);
        sheet.getRangeByIndex(i + 2, 2).setText(route);
        sheet.getRangeByIndex(i + 2, 3).setText(dateText);
        sheet.getRangeByIndex(i + 2, 4).setText(timeText);
        sheet.getRangeByIndex(i + 2, 5).setNumber(price);
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تصدير البيانات بنجاح: $filePath')),
      );
    } catch (e, st) {
      debugPrint('TripExporter.exportToExcel error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في التصدير: $e')),
      );
    }
  }
}
