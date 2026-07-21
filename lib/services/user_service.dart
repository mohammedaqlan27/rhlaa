// lib/services/user_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage? _providedStorage; // قد يكون null في الاختبارات
  final String _collection = 'users';

  // دعم حقن التبعيات للاختبارات والمحاكيات
  // ملاحظة: لا نستدعي FirebaseStorage.instance هنا مباشرةً
  UserService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _providedStorage = storage;

  // Getter كسلوك lazy للحصول على storage عند الحاجة فقط
  FirebaseStorage get _storage {
    return _providedStorage ?? FirebaseStorage.instance;
  }

  /// جلب بيانات المستخدم وتحويلها إلى كائن AppUser
  Future<AppUser?> getUserById(String uid) async {
    try {
      if (uid.isEmpty) return null;
      final doc = await _firestore.collection(_collection).doc(uid).get();
      return doc.exists ? AppUser.fromDocument(doc) : null;
    } catch (e, st) {
      debugPrint('UserService.getUserById error: $e\n$st');
      return null;
    }
  }

  /// إنشاء مستخدم جديد أو استبدال كامل للمستند (يستخدم toMap من AppUser)
  Future<bool> createOrSetUser(AppUser user) async {
    try {
      if (user.id.isEmpty) {
        debugPrint('UserService.createOrSetUser error: user.id is empty');
        return false;
      }
      final data = user.toMap();
      if (data['createdAt'] == null) data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_collection).doc(user.id).set(data, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.createOrSetUser error: $e\n$st');
      return false;
    }
  }

  /// تحديث الملف الشخصي بالكامل بناءً على الموديل (يحذف الحقول المحمية)
  Future<bool> updateUserProfile(AppUser user) async {
    try {
      if (user.id.isEmpty) {
        debugPrint('UserService.updateUserProfile error: user.id is empty');
        return false;
      }

      final data = user.toMap();
      data.remove('id');
      data.remove('uid');
      data.remove('createdAt');
      data.removeWhere((k, v) => v == null);

      await _firestore.collection(_collection).doc(user.id).update(data);
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserProfile error: $e\n$st');
      return false;
    }
  }

  /// تحديث حقول معينة فقط
  Future<bool> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (uid.isEmpty) return false;
    try {
      fields.removeWhere((k, v) => v == null);
      if (fields.isEmpty) return true;

      if (fields.containsKey('childrenCount')) {
        final v = fields['childrenCount'];
        if (v is String) {
          fields['childrenCount'] = int.tryParse(v) ?? 0;
        } else if (v is double) {
          fields['childrenCount'] = v.toInt();
        }
      }

      await _firestore.collection(_collection).doc(uid).update(fields);
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserFields error: $e\n$st');
      return false;
    }
  }

  /// رفع ملف إلى Firebase Storage
  Future<String?> uploadDocument(File file, String uid, String type, {String? extension}) async {
    try {
      final ext = extension ?? file.path.split('.').last;
      final ref = _storage.ref().child('documents/$uid/$type.$ext');

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('UserService.uploadDocument error: $e\n$st');
      return null;
    }
  }

  /// حفظ رابط الوثيقة في حقل Firestore المناسب
  Future<bool> saveDocumentUrl(String uid, String type, String url) async {
    try {
      if (uid.isEmpty) throw Exception('UID فارغ');

      final userRef = _firestore.collection(_collection).doc(uid);

      if (type == 'profile') {
        await userRef.update({'profilePictureUrl': url});
        return true;
      }

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) {
          tx.set(userRef, {
            'documents': {type: url},
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }

        final data = snap.data() ?? {};
        final Map<String, dynamic> docs = data['documents'] != null
            ? Map<String, dynamic>.from(data['documents'])
            : <String, dynamic>{};

        docs[type] = url;
        tx.update(userRef, {'documents': docs});
      });

      return true;
    } catch (e, st) {
      debugPrint('UserService.saveDocumentUrl error: $e\n$st');
      return false;
    }
  }

  Future<bool> uploadAndSaveDocument(File file, String uid, String type, {String? extension}) async {
    final url = await uploadDocument(file, uid, type, extension: extension);
    if (url != null) {
      return await saveDocumentUrl(uid, type, url);
    }
    return false;
  }

  Future<bool> deleteDocument(String uid, String type, {String? extension}) async {
    try {
      final ext = extension ?? 'jpg';
      final ref = _storage.ref().child('documents/$uid/$type.$ext');
      await ref.delete();

      final userRef = _firestore.collection(_collection).doc(uid);
      if (type == 'profile') {
        await userRef.update({'profilePictureUrl': FieldValue.delete()});
      } else {
        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(userRef);
          if (!snap.exists) return;
          final data = snap.data() ?? {};
          final Map<String, dynamic> docs = data['documents'] != null
              ? Map<String, dynamic>.from(data['documents'])
              : <String, dynamic>{};
          if (docs.containsKey(type)) {
            docs.remove(type);
            tx.update(userRef, {'documents': docs});
          }
        });
      }

      return true;
    } catch (e, st) {
      debugPrint('UserService.deleteDocument error: $e\n$st');
      return false;
    }
  }

  Future<bool> documentExists(String uid, String type, {String? extension}) async {
    try {
      final ext = extension ?? 'jpg';
      final ref = _storage.ref().child('documents/$uid/$type.$ext');
      await ref.getMetadata();
      return true;
    } catch (_) {
      return false;
    }
  }
}
