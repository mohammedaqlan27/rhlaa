// lib/services/pdf_service.dart
//
// خدمة توليد ورفع ملفات PDF الخاصة بكشوف الركاب (manifests).
// - تولد PDF مفصّل لرحلة واحدة (تضم بيانات الرحلة، قائمة الركاب إن وُجدت، govFee، إلخ).
// - ترفع الملف إلى Firebase Storage وتحدّث وثيقة الرحلة بحقل manifestUrl.
// - توفر دوال لحذف الـ manifest أو إعادة توليده.
//
// متطلبات في pubspec.yaml:
//   firebase_storage: ^x.x.x
//   pdf: ^3.x.x
//   path_provider: ^x.x.x

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/trip.dart';

class PdfService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  final String _tripsCollection = 'trips';
  final String _bookingsCollection = 'bookings';
  final String _manifestsFolder = 'manifests';

  PdfService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// توليد بايتس PDF لكشف الركاب لرحلة واحدة (لا يرفع الملف).
  /// يعيد Uint8List أو يرمي استثناء عند الفشل.
  Future<Uint8List> buildManifestPdfBytes(String tripId) async {
    // جلب بيانات الرحلة
    final tripDoc = await _firestore.collection(_tripsCollection).doc(tripId).get();
    if (!tripDoc.exists) throw Exception('Trip not found: $tripId');
    final trip = Trip.fromDocument(tripDoc);

    // جلب الحجوزات المرتبطة بالرحلة (confirmed أو bookingStatus)
    Query bookingsQuery = _firestore.collection(_bookingsCollection).where('tripId', isEqualTo: tripId);

    // بعض المشاريع تستخدم bookingStatus أو status
    // نحاول جلب الحجوزات المؤكدة أولاً
    final snapConfirmed = await bookingsQuery.where('bookingStatus', isEqualTo: 'confirmed').orderBy('createdAt', descending: false).get();
    QuerySnapshot bookingsSnap;
    if (snapConfirmed.docs.isNotEmpty) {
      bookingsSnap = snapConfirmed;
    } else {
      // احتياطي: بعض المستندات قد تستخدم 'status' أو 'paymentStatus'
      final snapAlt = await bookingsQuery.where('status', isEqualTo: 'confirmed').orderBy('createdAt', descending: false).get();
      bookingsSnap = snapAlt;
    }

    final bookings = bookingsSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    // توليد PDF
    final pw.Document pdfDoc = pw.Document();
    final DateFormat dateFmt = DateFormat('yyyy-MM-dd');
    final DateFormat timeFmt = DateFormat('HH:mm');

    final title = (trip.title != null && trip.title!.isNotEmpty) ? trip.title! : 'كشف ركاب الرحلة ${trip.id}';
    final tripDate = trip.date ?? trip.departureTime;
    final dateText = tripDate != null ? dateFmt.format(tripDate) : '-';
    final timeText = tripDate != null ? timeFmt.format(tripDate) : (trip.time != null && trip.time!.isNotEmpty ? trip.time! : '-');

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                title,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('من: ${trip.origin ?? '-'}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('إلى: ${trip.destination ?? '-'}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('التاريخ: $dateText', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('الوقت: $timeText', style: pw.TextStyle(fontSize: 12)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('السائق: ${trip.driverName ?? '-'}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('رقم المركبة: ${trip.carPlateNumber ?? '-'}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('السعر: ${trip.price?.toStringAsFixed(2) ?? '-'}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('govFee: ${(trip.govFeeAmount ?? 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12)),
                ]),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('قائمة الركاب', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            // جدول الركاب
            pw.Table.fromTextArray(
              headers: ['#', 'اسم الراكب', 'هاتف', 'مقعد', 'مبلغ مدفوع', 'ملاحظات'],
              data: List<List<String>>.generate(bookings.length, (i) {
                final b = bookings[i];
                final passengerName = (b['passengerName'] ?? b['passengerNickname'] ?? b['name'] ?? '')?.toString() ?? '';
                final phone = (b['passengerPhone'] ?? b['phone'] ?? '')?.toString() ?? '';
                // seat: قد يكون seatIndexes أو seatNumber أو seat
                String seat = '-';
                if (b['seatNumber'] != null) seat = b['seatNumber'].toString();
                else if (b['seatIndexes'] is List && (b['seatIndexes'] as List).isNotEmpty) {
                  final idxList = List.from(b['seatIndexes']);
                  seat = idxList.map((e) => e.toString()).join(',');
                }
                final paid = ((b['amountPaid'] ?? b['amount'] ?? 0).toString());
                final notes = (b['notes'] ?? '')?.toString() ?? '';
                return ['${i + 1}', passengerName, phone, seat, paid, notes];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
              cellHeight: 20,
              columnWidths: {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(0.8),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(2),
              },
            ),

            pw.SizedBox(height: 12),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('إجمالي الركاب: ${bookings.length}', style: pw.TextStyle(fontSize: 12)),
                pw.Text('المقاعد المتاحة: ${trip.availableSeats ?? '-'}', style: pw.TextStyle(fontSize: 12)),
              ])
            ]),

            pw.SizedBox(height: 18),
            pw.Text('ملاحظات إضافية:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(trip.description != null && trip.description!.isNotEmpty ? trip.description! : '-', style: pw.TextStyle(fontSize: 11)),
          ];
        },
      ),
    );

    final Uint8List pdfBytes = await pdfDoc.save();
    return pdfBytes;
  }

  /// توليد PDF ورفع الملف إلى Firebase Storage وتحديث وثيقة الرحلة.
  /// يعيد رابط التحميل (download URL) عند النجاح، أو null عند الفشل.
  Future<String?> generateManifestForTrip(String tripId, {bool attachToTrip = true}) async {
    File? localFile;
    try {
      final Uint8List pdfBytes = await buildManifestPdfBytes(tripId);

      // حفظ PDF مؤقتاً (اختياري، مفيد للتصحيح على الأجهزة المحلية)
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String localPath = '${tempDir.path}/manifest_${tripId}_$timestamp.pdf';
      localFile = File(localPath);
      await localFile.writeAsBytes(pdfBytes, flush: true);

      // رفع الملف إلى Firebase Storage
      final storagePath = '$_manifestsFolder/$tripId/manifest_$timestamp.pdf';
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // تحديث وثيقة الرحلة بحقل manifestUrl ومسار التخزين ووقت الإنشاء
      if (attachToTrip) {
        await _firestore.collection(_tripsCollection).doc(tripId).update({
          'manifestUrl': downloadUrl,
          'manifestStoragePath': storagePath,
          'manifestGeneratedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // حذف الملف المحلي المؤقت إن وُجد
      try {
        if (localFile.existsSync()) await localFile.delete();
      } catch (_) {}

      return downloadUrl;
    } catch (e, st) {
      debugPrint('PdfService.generateManifestForTrip error: $e\n$st');
      // حاول حذف الملف المحلي عند الفشل
      try {
        if (localFile != null && await localFile.exists()) await localFile.delete();
      } catch (_) {}
      return null;
    }
  }

  /// توليد ورفع manifests لعدة رحلات (متسلسل). يعيد خريطة tripId -> manifestUrl (null عند الفشل).
  Future<Map<String, String?>> generateAndAttachManifestForTrips(List<String> tripIds) async {
    final Map<String, String?> results = {};
    for (final id in tripIds) {
      final url = await generateManifestForTrip(id, attachToTrip: true);
      results[id] = url;
    }
    return results;
  }

  /// حذف ملف الـ manifest من التخزين وتحديث وثيقة الرحلة لإزالة الحقول
  Future<bool> deleteManifest(String tripId) async {
    try {
      final docRef = _firestore.collection(_tripsCollection).doc(tripId);
      final doc = await docRef.get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final storagePath = (data['manifestStoragePath'] as String?) ?? (data['manifest_path'] as String?);

      if (storagePath != null && storagePath.isNotEmpty) {
        final ref = _storage.ref().child(storagePath);
        try {
          await ref.delete();
        } catch (e) {
          // قد يكون الملف غير موجود؛ لا نوقف العملية بسبب ذلك
          debugPrint('PdfService.deleteManifest: storage delete error: $e');
        }
      }

      await docRef.update({
        'manifestUrl': FieldValue.delete(),
        'manifestStoragePath': FieldValue.delete(),
        'manifestGeneratedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, st) {
      debugPrint('PdfService.deleteManifest error: $e\n$st');
      return false;
    }
  }
}
