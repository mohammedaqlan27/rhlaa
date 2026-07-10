// lib/utils/trip_exporter.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
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

  // Helper to check if context is still mounted (we can't access mounted from static)
  static bool mountedContext(BuildContext context) {
    try {
      return context.findRenderObject() != null;
    } catch (_) {
      return false;
    }
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

  /// تصدير إلى PDF: يولد جدولًا بسيطًا بكشف الرحلات ويحفظه في مجلد مؤقت
  /// يقبل عناصر من نوع Trip أو Map<String,dynamic> أو خليط منهما
  static Future<void> exportToPdf(BuildContext context, List<dynamic> items) async {
    if (items.isEmpty) {
      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد رحلات للتصدير إلى PDF')),
      );
      return;
    }

    try {
      final pw.Document doc = pw.Document();
      final DateFormat dateFmt = DateFormat('yyyy-MM-dd');
      final DateFormat timeFmt = DateFormat('HH:mm');

      // جدول الرؤوس
      final headers = [
        'رقم الرحلة',
        'العنوان',
        'الانطلاق → الوجهة',
        'التاريخ',
        'الوقت',
        'السعر',
        'حالة',
        'govFee',
        'agencyId',
        'ملاحظات'
      ];

      // صفوف البيانات
      final List<List<String>> rows = [];

      for (final item in items) {
        String id = '-';
        String title = '-';
        String route = '-';
        String dateText = '-';
        String timeText = '-';
        String priceText = '0';
        String status = '-';
        String govFeeText = '0';
        String agencyId = '-';
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

            priceText = _toDouble(item.price).toStringAsFixed(2);
            status = (_toString(item.status)).isNotEmpty ? _toString(item.status) : '-';
            govFeeText = _toDouble(item.govFeeAmount).toStringAsFixed(2);
            agencyId = (_toString(item.agencyId)).isNotEmpty ? _toString(item.agencyId) : '-';
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

            priceText = _toDouble(item['price'] ?? item['fare'] ?? item['cost']).toStringAsFixed(2);
            status = _toString(item['status'] ?? item['state'] ?? '-');
            govFeeText = _toDouble(item['govFeeAmount'] ?? item['govFee'] ?? 0).toStringAsFixed(2);
            agencyId = _toString(item['agencyId'] ?? '-');
            notes = _toString(item['notes'] ?? item['description'] ?? '');
          } else {
            notes = _toString(item);
          }
        } catch (e, st) {
          debugPrint('TripExporter.parse item (PDF) error: $e\n$st');
        }

        rows.add([
          id,
          title,
          route,
          dateText,
          timeText,
          priceText,
          status,
          govFeeText,
          agencyId,
          notes,
        ]);
      }

      // بناء صفحة PDF بسيطة مع جدول
      doc.addPage(
        pw.MultiPage(
          pageFormat: pw.PageFormat.a4,
          build: (pw.Context ctx) {
            return [
              pw.Header(level: 0, child: pw.Text('تقرير الرحلات', style: pw.TextStyle(fontSize: 18))),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 22,
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                  6: pw.FlexColumnWidth(1),
                  7: pw.FlexColumnWidth(1),
                  8: pw.FlexColumnWidth(1),
                  9: pw.FlexColumnWidth(2),
                },
              ),
            ];
          },
        ),
      );

      final Uint8List pdfBytes = await doc.save();

      // حفظ الملف في مجلد مؤقت
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '${tempDir.path}/trips_export_$timestamp.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تصدير PDF بنجاح: $filePath')),
      );
    } catch (e, st) {
      debugPrint('TripExporter.exportToPdf error: $e\n$st');
      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تصدير PDF: $e')),
      );
    }
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

      // رؤوس الأعمدة (مضافة govFee و agencyId)
      final headers = [
        'رقم الرحلة',
        'العنوان',
        'الانطلاق → الوجهة',
        'التاريخ',
        'الوقت',
        'السعر',
        'حالة',
        'govFee',
        'agencyId',
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
        double govFee = 0.0;
        String agencyId = '-';

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
            govFee = _toDouble(item.govFeeAmount);
            agencyId = (_toString(item.agencyId)).isNotEmpty ? _toString(item.agencyId) : '-';
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
            govFee = _toDouble(item['govFeeAmount'] ?? item['govFee'] ?? 0);
            agencyId = _toString(item['agencyId'] ?? '-');
          } else {
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
        sheet.getRangeByIndex(i + 2, 8).setNumber(govFee);
        sheet.getRangeByIndex(i + 2, 9).setText(agencyId);
        sheet.getRangeByIndex(i + 2, 10).setText(notes);
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

  /// تصدير إلى CSV وحفظه في مجلد مؤقت
  /// يقبل عناصر من نوع Trip أو Map<String,dynamic> أو خليط منهما
  static Future<void> exportToCsv(BuildContext context, List<dynamic> items) async {
    if (items.isEmpty) {
      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد رحلات للتصدير إلى CSV')),
      );
      return;
    }

    try {
      final DateFormat dateFmt = DateFormat('yyyy-MM-dd');
      final DateFormat timeFmt = DateFormat('HH:mm');

      // رؤوس CSV (مضافة govFee و agencyId)
      final headers = [
        'tripId',
        'title',
        'route',
        'date',
        'time',
        'price',
        'status',
        'govFee',
        'agencyId',
        'notes'
      ];

      final StringBuffer csv = StringBuffer();
      csv.writeln(headers.join(','));

      for (final item in items) {
        String id = '-';
        String title = '-';
        String route = '-';
        String dateText = '-';
        String timeText = '-';
        String priceText = '0';
        String status = '-';
        String govFeeText = '0';
        String agencyId = '-';
        String notes = '-';

        try {
          if (item is Trip) {
            id = item.id ?? '-';
            title = _escapeCsv(_toString(item.title));
            final origin = _toString(item.origin);
            final dest = _toString(item.destination);
            route = _escapeCsv((origin.isNotEmpty || dest.isNotEmpty) ? '$origin → $dest' : '-');

            final DateTime? dt = item.date ?? item.departureTime;
            if (dt != null) {
              dateText = dateFmt.format(dt);
              timeText = timeFmt.format(dt);
            } else {
              dateText = '-';
              timeText = (_toString(item.time)).isNotEmpty ? _toString(item.time) : '-';
            }

            priceText = _toDouble(item.price).toStringAsFixed(2);
            status = _escapeCsv(_toString(item.status));
            govFeeText = _toDouble(item.govFeeAmount).toStringAsFixed(2);
            agencyId = _escapeCsv(_toString(item.agencyId));
            notes = _escapeCsv(_toString(item.description));
          } else if (item is Map<String, dynamic>) {
            id = _toString(item['id'] ?? item['tripId'] ?? '-');
            title = _escapeCsv(_toString(item['title'] ?? item['tripTitle'] ?? '-'));

            final origin = _toString(item['origin'] ?? '');
            final dest = _toString(item['destination'] ?? '');
            route = _escapeCsv((origin.isNotEmpty || dest.isNotEmpty) ? '$origin → $dest' : '-');

            final rawDate = item['date'] ?? item['departureTime'] ?? item['createdAt'];
            if (rawDate != null) {
              final dt = _toDateTime(rawDate);
              dateText = dateFmt.format(dt);
              timeText = timeFmt.format(dt);
            } else {
              dateText = '-';
              timeText = _toString(item['time'] ?? '');
            }

            priceText = _toDouble(item['price'] ?? item['fare'] ?? item['cost']).toStringAsFixed(2);
            status = _escapeCsv(_toString(item['status'] ?? item['state'] ?? '-'));
            govFeeText = _toDouble(item['govFeeAmount'] ?? item['govFee'] ?? 0).toStringAsFixed(2);
            agencyId = _escapeCsv(_toString(item['agencyId'] ?? '-'));
            notes = _escapeCsv(_toString(item['notes'] ?? item['description'] ?? ''));
          } else {
            notes = _escapeCsv(_toString(item));
          }
        } catch (e, st) {
          debugPrint('TripExporter.parse item (CSV) error: $e\n$st');
        }

        final row = [
          _escapeCsv(id),
          title,
          route,
          dateText,
          timeText,
          priceText,
          status,
          govFeeText,
          agencyId,
          notes,
        ];
        csv.writeln(row.join(','));
      }

      // حفظ الملف في مجلد مؤقت
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '${tempDir.path}/trips_export_$timestamp.csv';
      final File file = File(filePath);
      await file.writeAsString(csv.toString(), flush: true);

      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تصدير CSV بنجاح: $filePath')),
      );
    } catch (e, st) {
      debugPrint('TripExporter.exportToCsv error: $e\n$st');
      if (!mountedContext(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تصدير CSV: $e')),
      );
    }
  }

  // Escape CSV fields that contain commas, quotes or newlines
  static String _escapeCsv(String input) {
    if (input.contains(',') || input.contains('"') || input.contains('\n')) {
      final escaped = input.replaceAll('"', '""');
      return '"$escaped"';
    }
    return input;
  }
}
