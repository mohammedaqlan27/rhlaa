import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
            }
          }
        }
      }

      if (orderBy != null) {
        for (final ord in orderBy) {
          if (ord.isNotEmpty) {
            final field = ord[0];
            final dir = ord.length > 1 && ord[1].toLowerCase() == 'desc' ? false : true;
            query = query.orderBy(field, descending: !dir);
          }
        }
      }

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
            data['_id'] = doc.id;
            data['id'] = doc.id; // نضمن وجود الحقلين لزيادة التوافق الاستباقي للموديلات
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
      return Stream<List<T>>.value(<T>[]);
    }
  }
}