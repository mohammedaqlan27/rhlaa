// lib/services/pdf_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:url_launcher/url_launcher.dart'; // حزمة فتح الروابط
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

  // =============================================================
  // 1. دالة فتح رابط الكشف (جديد)
  // =============================================================
  Future<void> openManifestUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  // =============================================================
  // 2. توليد بايتس PDF احترافي لكشف الركاب
  // =============================================================
  Future<Uint8List> buildManifestPdfBytes(String tripId) async {
    // جلب البيانات
    final tripDoc = await _firestore.collection(_tripsCollection).doc(tripId).get();
    if (!tripDoc.exists) throw Exception('الرحلة غير موجودة: $tripId');
    final trip = Trip.fromDocument(tripDoc);

    final bookingsSnap = await _firestore
        .collection(_bookingsCollection)
        .where('tripId', isEqualTo: tripId)
        .where('bookingStatus', isEqualTo: 'confirmed')
        .orderBy('createdAt', descending: false)
        .get();

    final bookings = bookingsSnap.docs.map((d) => d.data()).toList();

    // تحميل الخطوط والصور (الهوية البصرية)
    pw.Font? arabicFont;
    try {
      final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
      arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Warning: Arabic font not found.');
    }

    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load("assets/images/logo.png");
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final pdfDoc = pw.Document();

    // بناء الصفحات
    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(25),
        header: (context) => _buildHeader(trip, logo, arabicFont),
        footer: (context) => _buildFooter(context, arabicFont),
        build: (context) => [
          _buildTripInfoBox(trip, arabicFont),
          pw.SizedBox(height: 20),
          _buildPassengersTable(bookings, arabicFont),
          pw.SizedBox(height: 20),
          _buildSummarySection(bookings, trip, arabicFont),
        ],
      ),
    );

    return await pdfDoc.save();
  }

  // =============================================================
  // 3. مكونات بناء الـ PDF (Widgets)
  // =============================================================

  pw.Widget _buildHeader(Trip trip, pw.MemoryImage? logo, pw.Font? font) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logo != null) pw.Image(logo, width: 50, height: 50) else pw.SizedBox(width: 50),
            pw.Column(
              children: [
                pw.Text('كشف ركاب الرحلة الرسمي',
                    style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.blue900)),
                pw.Text('تطبيق رحلة - منصة النقل الذكي',
                    style: pw.TextStyle(font: font, fontSize: 10, color: pdf.PdfColors.grey700)),
              ],
            ),
            pw.Container(
              width: 50,
              height: 50,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'https://rhlaa.com/verify/trip/${trip.id}',
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 1, color: pdf.PdfColors.blueAccent),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildTripInfoBox(Trip trip, pw.Font? font) {
    final style = pw.TextStyle(font: font, fontSize: 10);
    final boldStyle = pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: pdf.PdfColors.grey100,
        border: pw.Border.all(color: pdf.PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('من: ${trip.origin ?? '-'}', style: boldStyle),
              pw.Text('إلى: ${trip.destination ?? '-'}', style: boldStyle),
              pw.Text('رقم الرحلة: ${trip.id.substring(0, 8).toUpperCase()}', style: style),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('السائق: ${trip.driverName ?? '-'}', style: style),
              pw.Text('رقم المركبة: ${trip.carPlateNumber ?? '-'}', style: style),
              pw.Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(trip.date ?? DateTime.now())}', style: style),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPassengersTable(List<Map<String, dynamic>> bookings, pw.Font? font) {
    return pw.Table.fromTextArray(
      headers: ['#', 'اسم الراكب', 'رقم الهاتف', 'المقعد', 'المبلغ', 'ملاحظات'],
      data: List.generate(bookings.length, (index) {
        final b = bookings[index];
        return [
          '${index + 1}',
          b['passengerName'] ?? b['passengerNickname'] ?? '-',
          b['passengerPhone'] ?? '-',
          b['seatNumber']?.toString() ?? '-',
          '${b['amountPaid'] ?? 0}',
          b['notes'] ?? '',
        ];
      }),
      headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.white),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: pdf.PdfColors.blueGrey800),
      cellAlignment: pw.Alignment.center,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: pdf.PdfColors.grey300, width: .5)),
      ),
      oddRowDecoration: const pw.BoxDecoration(color: pdf.PdfColors.grey100),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(0.6),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  pw.Widget _buildFooter(pw.Context context, pw.Font? font) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8)),
            pw.Text('تم التوليد بواسطة تطبيق رحلة - ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(font: font, fontSize: 8, color: pdf.PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSummarySection(List bookings, Trip trip, pw.Font? font) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('إجمالي الركاب المؤكدين: ${bookings.length}',
              style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text('رسوم الخدمة (GovFee): ${(trip.govFeeAmount ?? 0.0).toStringAsFixed(2)}',
              style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }

  // =============================================================
  // 4. دوال الرفع والإدارة (Storage & Firestore)
  // =============================================================

  Future<String?> generateManifestForTrip(String tripId, {bool attachToTrip = true}) async {
    try {
      final Uint8List pdfBytes = await buildManifestPdfBytes(tripId);
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final storagePath = '$_manifestsFolder/$tripId/manifest_$timestamp.pdf';

      final ref = _storage.ref().child(storagePath);
      await ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
      final downloadUrl = await ref.getDownloadURL();

      if (attachToTrip) {
        await _firestore.collection(_tripsCollection).doc(tripId).update({
          'manifestUrl': downloadUrl,
          'manifestStoragePath': storagePath,
          'manifestGeneratedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return downloadUrl;
    } catch (e) {
      debugPrint('PdfService Error: $e');
      return null;
    }
  }

  Future<bool> deleteManifest(String tripId) async {
    try {
      final docRef = _firestore.collection(_tripsCollection).doc(tripId);
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final storagePath = doc.data()?['manifestStoragePath'] as String?;
      if (storagePath != null) {
        await _storage.ref().child(storagePath).delete();
      }

      await docRef.update({
        'manifestUrl': FieldValue.delete(),
        'manifestStoragePath': FieldValue.delete(),
        'manifestGeneratedAt': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}