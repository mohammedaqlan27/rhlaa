// lib/services/user_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'users';

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
      // تأكد أن createdAt يتم تعيينه من السيرفر عند الإنشاء
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

      // حماية الحقول الأساسية من التغيير العشوائي
      data.remove('id');
      data.remove('uid');
      data.remove('createdAt');

      // إزالة القيم null لتجنب مسح الحقول الموجودة
      data.removeWhere((k, v) => v == null);

      await _firestore.collection(_collection).doc(user.id).update(data);
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserProfile error: $e\n$st');
      return false;
    }
  }

  /// تحديث حقول معينة فقط (مثل تحديث رقم الهاتف فقط)
  Future<bool> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (uid.isEmpty) return false;
    try {
      // تنظيف البيانات من القيم الفارغة قبل الإرسال لضمان عدم مسح بيانات موجودة
      fields.removeWhere((k, v) => v == null);

      if (fields.isEmpty) return true;

      // تحويل بعض الحقول لأنواع مناسبة إن لزم (مثال childrenCount -> int)
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

  /// حفظ رابط الوثيقة في حقل Firestore المناسب بناءً على النوع
  ///
  /// قواعد الحفظ:
  /// - 'profile' -> profilePictureUrl (حقل منفصل)
  /// - أي نوع آخر -> يحفظ داخل خريطة 'documents' كمفتاح type
  /// مثال: documents.identity_card = url
  Future<bool> saveDocumentUrl(String uid, String type, String url) async {
    try {
      if (uid.isEmpty) throw Exception('UID فارغ');

      final userRef = _firestore.collection(_collection).doc(uid);

      // أنواع خاصة تتطلب حقول منفصلة
      if (type == 'profile') {
        await userRef.update({'profilePictureUrl': url});
        return true;
      }

      // لباقي الأنواع نخزن الرابط داخل خريطة documents
      // نستخدم transaction أو update مع merge لضمان عدم فقدان روابط أخرى
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) {
          // إذا لم يوجد المستخدم، ننشئ مستندًا بسيطًا مع documents
          tx.set(userRef, {
            'documents': {type: url},
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }

        final data = snap.data() as Map<String, dynamic>? ?? {};
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

  /// دالة مدمجة: رفع الملف ثم تحديث الرابط في Firestore مباشرة
  Future<bool> uploadAndSaveDocument(File file, String uid, String type, {String? extension}) async {
    final url = await uploadDocument(file, uid, type, extension: extension);
    if (url != null) {
      return await saveDocumentUrl(uid, type, url);
    }
    return false;
  }

  /// حذف وثيقة من Storage (مثلاً عند رغبة المستخدم في تغيير صورته)
  Future<bool> deleteDocument(String uid, String type, {String? extension}) async {
    try {
      final ext = extension ?? 'jpg';
      final ref = _storage.ref().child('documents/$uid/$type.$ext');
      await ref.delete();

      // إزالة الرابط من خريطة documents أو من profilePictureUrl
      final userRef = _firestore.collection(_collection).doc(uid);
      if (type == 'profile') {
        await userRef.update({'profilePictureUrl': FieldValue.delete()});
      } else {
        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(userRef);
          if (!snap.exists) return;
          final data = snap.data() as Map<String, dynamic>? ?? {};
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

  /// التحقق من وجود وثيقة مرفوعة مسبقاً
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
