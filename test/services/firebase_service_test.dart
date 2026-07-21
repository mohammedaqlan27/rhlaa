import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rhlaa/services/firestore_service.dart';

void main() {
  // تعريف المتغيرات التي سنستخدمها
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService firestoreService;

  setUp(() {
    // 1. إنشاء نسخة وهمية من Firestore
    fakeFirestore = FakeFirebaseFirestore();

    // 2. تهيئة الخدمة وتمرير النسخة الوهمية لها
    // ملاحظة: إذا استمر الخطأ تحت 'firestore:'، تأكد من تعديل ملف FirestoreService الأصلي
    firestoreService = FirestoreService(firestore: fakeFirestore);
  });

  group('FirestoreService Tests - اختبارات خدمة Firestore', () {

    test('يجب إضافة مستند بنجاح وإرجاع الـ ID', () async {
      final data = {'name': 'Test Item', 'value': 100};

      final docId = await firestoreService.addDocument(
        collectionPath: 'test_collection',
        data: data,
      );

      // التأكد أن الـ ID ليس فارغاً
      expect(docId, isNotEmpty);

      // التأكد أن البيانات حُفظت فعلاً في القاعدة الوهمية
      final doc = await fakeFirestore.collection('test_collection').doc(docId).get();
      expect(doc.data()?['name'], 'Test Item');
      expect(doc.data()?['value'], 100);
    });

    test('يجب تحديث مستند موجود بنجاح', () async {
      // إضافة مستند يدوي أولاً
      final docRef = await fakeFirestore.collection('items').add({'name': 'Old'});

      // تحديثه عبر الخدمة
      await firestoreService.updateDocument(
        collectionPath: 'items',
        docId: docRef.id,
        data: {'name': 'New'},
      );

      // التأكد من التحديث
      final doc = await fakeFirestore.collection('items').doc(docRef.id).get();
      expect(doc.data()?['name'], 'New');
    });

    test('يجب جلب مستند واحد وتحويله للموديل المطلوب', () async {
      final docRef = await fakeFirestore.collection('users').add({'name': 'Ali'});

      // جلب المستند واستخدام دالة تحويل بسيطة (fromDoc)
      final result = await firestoreService.getDocument(
        collectionPath: 'users',
        docId: docRef.id,
        fromDoc: (doc) => doc.data()?['name'] as String,
      );

      expect(result, 'Ali');
    });

    test('يجب أن يعمل الـ Stream بشكل صحيح عند إضافة بيانات جديدة', () async {
      final collectionPath = 'items';

      // بدء الاستماع للـ Stream
      final stream = firestoreService.collectionStream(
        collectionPath: collectionPath,
        fromDoc: (doc) => doc.data()?['name'] as String,
      );

      // إضافة عنصر جديد في القاعدة الوهمية
      await fakeFirestore.collection(collectionPath).add({'name': 'Item 1'});

      // التوقع: الـ Stream يجب أن يبعث قائمة تحتوي على 'Item 1'
      expect(stream, emits(contains('Item 1')));
    });
  });
}

extension on Object? {
  void operator [](String other) {}
}