// lib/services/firebase_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة مساعدة للاستماع إلى مجموعة في Firestore وتحويلها إلى Stream من كائنات
/// - fromJson يتلقى خريطة تحتوي بيانات المستند بالإضافة إلى المفتاح `_id` الذي يحوي doc.id
/// - يدعم عوامل تصفية بسيطة (whereClauses)، ترتيب (orderBy) وحدّ النتائج (limit)
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// استمع إلى مجموعة وحوّل كل مستند عبر fromJson
  /// - path: مسار المجموعة (مثال: 'trips')
  /// - fromJson: دالة تحول Map<String,dynamic> إلى كائن من النوع T
  ///            ستتلقى الخريطة مع المفتاح `_id` الذي يحوي doc.id
  /// - whereClauses: قائمة شروط where بصيغة tuples: [ ['field','==', value], ... ]
  /// - orderBy: قائمة حقول للترتيب بصيغة tuples: [ ['field','asc'], ['other','desc'] ]
  /// - limit: حد عدد المستندات (اختياري)
  Stream<List<T>> listenToCollection<T>({
    required String path,
    required T Function(Map<String, dynamic> doc) fromJson,
    List<List<dynamic>>? whereClauses,
    List<List<String>>? orderBy,
    int? limit,
  }) {
    try {
      CollectionReference col = _firestore.collection(path);
      Query query = col;

      // تطبيق شروط where إن وُجدت
      if (whereClauses != null) {
        for (final clause in whereClauses) {
          if (clause.length >= 3) {
            final field = clause[0] as String;
            final op = clause[1] as String;
            final value = clause[2];
            switch (op) {
              case '==':
                query = query.where(field, isEqualTo: value);
                break;
              case '<':
                query = query.where(field, isLessThan: value);
                break;
              case '<=':
                query = query.where(field, isLessThanOrEqualTo: value);
                break;
              case '>':
                query = query.where(field, isGreaterThan: value);
                break;
              case '>=':
                query = query.where(field, isGreaterThanOrEqualTo: value);
                break;
              case 'array-contains':
                query = query.where(field, arrayContains: value);
                break;
              case 'in':
                query = query.where(field, whereIn: value);
                break;
              default:
                debugPrint('FirebaseService.listenToCollection: unsupported where op $op');
            }
          }
        }
      }

      // تطبيق ترتيب إن وُجد
      if (orderBy != null) {
        for (final ord in orderBy) {
          if (ord.isNotEmpty) {
            final field = ord[0];
            final dir = ord.length > 1 && ord[1].toLowerCase() == 'desc' ? false : true;
            query = query.orderBy(field, descending: !dir);
          }
        }
      }

      // تطبيق حدّ النتائج إن وُجد
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      return query.snapshots().handleError((error) {
        debugPrint('FirebaseService error on $path: $error');
      }).map((snapshot) {
        final List<T> list = [];
        for (final doc in snapshot.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            // أضف معرف المستند تحت المفتاح _id لتمكين fromJson من استخدامه
            data['_id'] = doc.id;
            final item = fromJson(data);
            list.add(item);
          } catch (e, st) {
            debugPrint('FirebaseService.parse doc error in $path: $e\n$st');
          }
        }
        return list;
      });
    } catch (e, st) {
      debugPrint('FirebaseService.listenToCollection fatal error for $path: $e\n$st');
      // إرجاع تيار فارغ بدل رمي استثناء قد يكسر الواجهات
      return Stream<List<T>>.value(<T>[]);
    }
  }
}
