import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  // المشيد الذي يسمح لنا بتمرير نسخة وهمية أثناء الاختبار
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // إضافة مستند (مثلاً إضافة رحلة جديدة)
  Future<String> addDocument({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    final docRef = await _firestore.collection(collectionPath).add(data);
    return docRef.id;
  }

  // تحديث مستند (مثلاً تعديل بيانات مستخدم)
  Future<void> updateDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collectionPath).doc(docId).update(data);
  }

  // جلب مستند واحد (مثلاً جلب بيانات رحلة معينة)
  Future<T?> getDocument<T>({
    required String collectionPath,
    required String docId,
    required T Function(DocumentSnapshot doc) fromDoc,
  }) async {
    final doc = await _firestore.collection(collectionPath).doc(docId).get();
    if (doc.exists) {
      return fromDoc(doc);
    }
    return null;
  }

  // جلب قائمة مستندات كـ Stream (للتحديث التلقائي في الواجهة)
  Stream<List<T>> collectionStream<T>({
    required String collectionPath,
    required T Function(DocumentSnapshot doc) fromDoc,
  }) {
    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => fromDoc(doc)).toList();
    });
  }
}