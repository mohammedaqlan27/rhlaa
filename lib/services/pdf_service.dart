// lib/services/pdf_service.dart
//
// خدمة توليد ورفع ملفات PDF الخاصة بكشوف الركاب (manifests).
// - تولد PDF مفصّل لرحلة واحدة (تضم بيانات الرحلة، قائمة الركاب إن وُجدت، govFee، إلخ).
// - ترفع الملف إلى Firebase Storage وتحدّث وثيقة الرحلة بحقل manifestUrl.
// - توفر دوال لحذف الـ manifest أو إعادة توليده.
// متطلبات:
//   firebase_storage: ^x.x.x
//   pdf: ^3.x.x
//   path_provider: ^x.x.x
// تأكد من إضافة الحزم في pubspec.yaml ثم تشغيل flutter pub get.

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/trip.dart';

class PdfService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  final String _tripsCollection = 'trips';
  final String _bookingsCollection = 'bookings'; // إن كنت تحتفظ بحجوزات الركاب هنا
  final String _manifestsFolder = 'manifests';

  PdfService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// توليد PDF لكشف الركاب لرحلة واحدة، رفعه إلى Storage، وتحديث وثيقة الرحلة
  /// يعيد رابط التحميل (download URL) عند النجاح، أو null عند الفشل.
  Future<String?> generateManifestForTrip(String tripId, {bool attachToTrip = true}) async {
    try {
      // جلب بيانات الرحلة
      final tripDoc = await _firestore.collection(_tripsCollection).doc(tripId).get();
      if (!tripDoc.exists) {
        debugPrint('PdfService.generateManifestForTrip: Trip not found $tripId');
        return null;
      }
      final trip = Trip.fromDocument(tripDoc);

      // جلب الحجوزات المرتبطة بالرحلة (إن وُجدت) لترتيب الركاب في الكشوف
      final bookingsSnap = await _firestore
          .collection(_bookingsCollection)
          .where('tripId', isEqualTo: tripId)
          .where('status', isEqualTo: 'confirmed') // أو الحالة المناسبة
          .orderBy('createdAt', descending: false)
          .get();

      final bookings = bookingsSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

      // توليد PDF
      final pdf = pw.Document();
      final DateFormat dateFmt = DateFormat('yyyy-MM-dd');
      final DateFormat timeFmt = DateFormat('HH:mm');

      final title = trip.title.isNotEmpty ? trip.title : 'كشف ركاب الرحلة ${trip.id}';
      final tripDate = trip.date ?? trip.departureTime;
      final dateText = tripDate != null ? dateFmt.format(tripDate) : '-';
      final timeText = tripDate != null ? timeFmt.format(tripDate) : (trip.time.isNotEmpty ? trip.time : '-');

      // رأس الصفحة
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pw.PageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (pw.Context ctx) {
            return [
              pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('من: ${trip.origin}', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('إلى: ${trip.destination}', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('التاريخ: $dateText', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('الوقت: $timeText', style: pw.TextStyle(fontSize: 12)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('السائق: ${trip.driverName}', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('رقم المركبة: ${trip.carPlateNumber}', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('السعر: ${trip.price.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12)),
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
                  final passengerName = (b['passengerName'] ?? b['name'] ?? '') as String;
                  final phone = (b['passengerPhone'] ?? b['phone'] ?? '') as String;
                  final seat = (b['seatNumber']?.toString() ?? '-') as String;
                  final paid = ((b['amountPaid'] ?? b['amount'] ?? 0).toString());
                  final notes = (b['notes'] ?? '') as String;
                  return ['${i + 1}', passengerName, phone, seat, paid, notes];
                }),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
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
                  pw.Text('المقاعد المتاحة: ${trip.availableSeats}', style: pw.TextStyle(fontSize: 12)),
                ])
              ]),

              pw.SizedBox(height: 18),
              pw.Text('ملاحظات إضافية:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(trip.description.isNotEmpty ? trip.description : '-', style: pw.TextStyle(fontSize: 11)),
            ];
          },
        ),
      );

      // حفظ PDF مؤقتاً
      final Uint8List pdfBytes = await pdf.save();
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String localPath = '${tempDir.path}/manifest_${tripId}_$timestamp.pdf';
      final File localFile = File(localPath);
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

      // حذف الملف المحلي المؤقت إن رغبت
      try {
        if (await localFile.exists()) await localFile.delete();
      } catch (_) {}

      return downloadUrl;
    } catch (e, st) {
      debugPrint('PdfService.generateManifestForTrip error: $e\n$st');
      return null;
    }
  }

  /// توليد ورفع manifests لعدة رحلات (موازي أو متسلسل حسب الحاجة)
  /// يعيد خريطة tripId -> manifestUrl (null عند الفشل لكل رحلة)
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
      final storagePath = data['manifestStoragePath'] as String?;
      if (storagePath != null && storagePath.isNotEmpty) {
        final ref = _storage.ref().child(storagePath);
        await ref.delete();
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
