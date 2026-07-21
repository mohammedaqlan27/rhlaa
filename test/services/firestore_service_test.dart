import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:rhlaa/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService firestoreService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    // الآن سيعمل هذا السطر لأننا أضفنا المشيد في ملف الخدمة
    firestoreService = FirestoreService(firestore: fakeFirestore);
  });

  group('FirestoreService Tests', () {
    test('يجب إضافة مستند بنجاح وإرجاع الـ ID', () async {
      final data = {'name': 'رحلة تجريبية', 'price': 100};
      final id = await firestoreService.addDocument(
        collectionPath: 'trips',
        data: data,
      );

      expect(id, isNotEmpty);
      final doc = await fakeFirestore.collection('trips').doc(id).get();
      expect(doc.data()?['name'], 'رحلة تجريبية');
    });

    test('يجب تحديث البيانات بنجاح', () async {
      final docRef = await fakeFirestore.collection('users').add({'name': 'قديم'});

      await firestoreService.updateDocument(
        collectionPath: 'users',
        docId: docRef.id,
        data: {'name': 'جديد'},
      );

      final updatedDoc = await fakeFirestore.collection('users').doc(docRef.id).get();
      expect(updatedDoc.data()?['name'], 'جديد');
    });
  });
}