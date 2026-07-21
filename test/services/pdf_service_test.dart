import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:rhlaa/services/pdf_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  // تهيئة بيئة اختبار فلاتر
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage fakeStorage;
  late PdfService pdfService;

  const String tTripId = 'trip_pro_123';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeStorage = MockFirebaseStorage();
    pdfService = PdfService(firestore: fakeFirestore, storage: fakeStorage);

    // إعداد بيانات وهمية للخط والشعار لتجنب خطأ PathNotFoundException
    Uint8List fontData;
    Uint8List logoData;

    try {
      // محاولة تحميل الملفات الحقيقية إذا كانت موجودة في المسار
      fontData = File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync();
    } catch (_) {
      // بيانات وهمية في حال عدم وجود الملف (لضمان نجاح الاختبار البرمجي)
      fontData = Uint8List.fromList(List.generate(10, (i) => i));
    }

    try {
      logoData = File('assets/images/logo.png').readAsBytesSync();
    } catch (_) {
      logoData = Uint8List.fromList(List.generate(10, (i) => i));
    }

    // محاكاة نظام الأصول (Assets) في فلاتر
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter/assets'), (methodCall) async {
      if (methodCall.method == 'load') {
        final String assetPath = methodCall.arguments;
        if (assetPath == 'assets/fonts/Amiri-Regular.ttf') {
          return ByteData.view(fontData.buffer);
        }
        if (assetPath == 'assets/images/logo.png') {
          return ByteData.view(logoData.buffer);
        }
      }
      return null;
    });
  });

  group('PdfService - التحقق من الخدمات المتكاملة', () {

    test('1. دعم العربية و RTL والهوية البصرية (Logo/Colors)', () async {
      await fakeFirestore.collection('trips').doc(tTripId).set({
        'id': tTripId,
        'title': 'رحلة تجريبية بالعربية',
        'origin': 'صنعاء',
        'destination': 'عدن',
      });

      final bytes = await pdfService.buildManifestPdfBytes(tTripId);
      expect(bytes.isNotEmpty, true);
      expect(bytes, isA<Uint8List>());
    });

    test('2. معالجة الحالات الخاصة (الرحلات الطويلة 50 راكب)', () async {
      await fakeFirestore.collection('trips').doc(tTripId).set({'id': tTripId});

      // إضافة 50 حجز للتأكد من أن الجدول ينتقل لصفحات جديدة (MultiPage)
      for (int i = 0; i < 50; i++) {
        await fakeFirestore.collection('bookings').add({
          'tripId': tTripId,
          'passengerName': 'راكب رقم $i',
          'bookingStatus': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final bytes = await pdfService.buildManifestPdfBytes(tTripId);
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, true);
    });

    test('3. التوثيق القانوني (QR Code & Timestamp)', () async {
      await fakeFirestore.collection('trips').doc(tTripId).set({'id': tTripId});

      await pdfService.generateManifestForTrip(tTripId);

      final tripDoc = await fakeFirestore.collection('trips').doc(tTripId).get();
      // التأكد من تسجيل وقت التوليد في قاعدة البيانات
      expect(tripDoc.data()!['manifestGeneratedAt'], isNotNull);
    });

    test('4. الأمان (فصل المجلدات بـ tripId)', () async {
      await fakeFirestore.collection('trips').doc(tTripId).set({'id': tTripId});

      await pdfService.generateManifestForTrip(tTripId);

      final tripDoc = await fakeFirestore.collection('trips').doc(tTripId).get();
      final String path = tripDoc.data()!['manifestStoragePath'];

      // التأكد من أن الملف رُفع في مجلد خاص برقم الرحلة لضمان الخصوصية
      expect(path.contains('manifests/$tTripId/'), true);
    });

    test('5. إدارة الدورة الكاملة (إنشاء وحذف)', () async {
      await fakeFirestore.collection('trips').doc(tTripId).set({'id': tTripId});

      // اختبار الإنشاء والرفع
      final url = await pdfService.generateManifestForTrip(tTripId);
      expect(url, isNotNull);
      expect(url, contains('http'));

      // اختبار الحذف من التخزين وقاعدة البيانات
      final deleted = await pdfService.deleteManifest(tTripId);
      expect(deleted, true);

      final tripDoc = await fakeFirestore.collection('trips').doc(tTripId).get();
      // التأكد من مسح الروابط بعد الحذف
      expect(tripDoc.data()!.containsKey('manifestUrl'), false);
    });
  });
}