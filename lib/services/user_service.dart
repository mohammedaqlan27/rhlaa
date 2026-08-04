// lib/services/user_service.dart
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage? _providedStorage;
  final String _collection = 'users';

  UserService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _providedStorage = storage;

  FirebaseStorage get _storage => _providedStorage ?? FirebaseStorage.instance;

  // -------------------------
  // قراءة المستخدم (مرة واحدة)
  // -------------------------
  Future<AppUser?> getUserById(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      return doc.exists ? AppUser.fromDocument(doc) : null;
    } catch (e, st) {
      debugPrint('UserService.getUserById error: $e\n$st');
      return null;
    }
  }

  // -------------------------
  // Stream لمزامنة المستخدم تلقائياً
  // -------------------------
  Stream<AppUser?> userStream(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return _firestore.collection(_collection).doc(uid).snapshots().map((doc) {
      return doc.exists ? AppUser.fromDocument(doc) : null;
    }).handleError((e, st) {
      debugPrint('UserService.userStream error: $e\n$st');
    });
  }

  // -------------------------
  // إدارة توكنات الإشعارات (FCM Tokens)
  // -------------------------
  /// تقوم بحفظ التوكن في المجموعة الفرعية fcmTokens داخل مستند المستخدم
  Future<void> saveFcmToken(String uid, String token, String platform) async {
    if (uid.isEmpty || token.isEmpty) return;
    try {
      await _firestore
          .collection(_collection)
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'platform': platform,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('UserService.saveFcmToken error: $e');
    }
  }

  // -------------------------
  // إنشاء أو تعيين المستخدم
  // -------------------------
  Future<bool> createOrSetUser(AppUser user) async {
    try {
      if (user.id.isEmpty) {
        debugPrint('UserService.createOrSetUser error: user.id is empty');
        return false;
      }
      final data = user.toCreateMap();
      await _firestore.collection(_collection).doc(user.id).set(data, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.createOrSetUser error: $e\n$st');
      return false;
    }
  }

  // -------------------------
  // تحديث الملف الشخصي بالكامل
  // -------------------------
  Future<bool> updateUserProfile(AppUser user) async {
    try {
      if (user.id.isEmpty) {
        debugPrint('UserService.updateUserProfile error: user.id is empty');
        return false;
      }

      final data = user.toUpdateMap();
      data.removeWhere((k, v) => v == null);

      // حماية الحقول الأساسية والحساسة لضمان قبول الطلب من قبل Security Rules
      data.remove('id');
      data.remove('uid');
      data.remove('createdAt');
      data.remove('walletBalance'); // الرصيد لا يُعدل من طرف العميل

      await _firestore.collection(_collection).doc(user.id).update(data);
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserProfile error: $e\n$st');
      return false;
    }
  }

  // -------------------------
  // تحديث حقول محددة فقط
  // -------------------------
  Future<bool> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (uid.isEmpty) return false;
    try {
      fields.removeWhere((k, v) => v == null);
      if (fields.isEmpty) return true;

      // منع تعديل الحقول المحمية في التحديث الجزئي أيضاً
      fields.remove('uid');
      fields.remove('id');
      fields.remove('createdAt');
      fields.remove('walletBalance');

      // معالجة childrenCount لضمان التوافق مع Firestore (String)
      if (fields.containsKey('childrenCount')) {
        fields['childrenCount'] = fields['childrenCount'].toString();
      }

      fields['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_collection).doc(uid).update(fields);
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserFields error: $e\n$st');
      return false;
    }
  }

  // -------------------------
  // مساعدة لتنظيف الامتداد
  // -------------------------
  String _normalizeExtension(String? extension, String fallback) {
    if (extension == null || extension.trim().isEmpty) return fallback;
    final ext = extension.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
    return ext.isEmpty ? fallback : ext;
  }

  // -------------------------
  // رفع ملف إلى Firebase Storage
  // -------------------------
  Future<String?> uploadDocument(File file, String uid, String type,
      {String? extension, int maxRetries = 2}) async {
    if (uid.isEmpty) return null;
    try {
      final ext = _normalizeExtension(extension, file.path.split('.').last);
      final safeType = type.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final ref = _storage.ref().child('documents/$uid/$safeType.$ext');

      int attempt = 0;
      while (true) {
        try {
          final UploadTask uploadTask = ref.putFile(file);
          final TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
          final url = await snapshot.ref.getDownloadURL();
          return url;
        } catch (e) {
          attempt++;
          if (attempt > maxRetries) rethrow;
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    } catch (e, st) {
      debugPrint('UserService.uploadDocument error: $e\n$st');
      return null;
    }
  }

  // -------------------------
  // حفظ رابط الوثيقة في Firestore
  // -------------------------
  Future<bool> saveDocumentUrl(String uid, String type, String url) async {
    if (uid.isEmpty) return false;
    try {
      final userRef = _firestore.collection(_collection).doc(uid);

      if (type == 'profile') {
        await userRef.update({'profilePictureUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
        return true;
      }

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) {
          tx.set(userRef, {
            'documents': {type: url},
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }

        final data = snap.data() as Map<String, dynamic>? ?? {};
        final Map<String, dynamic> docs = data['documents'] != null
            ? Map<String, dynamic>.from(data['documents'])
            : <String, dynamic>{};

        docs[type] = url;
        tx.update(userRef, {'documents': docs, 'updatedAt': FieldValue.serverTimestamp()});
      });

      return true;
    } catch (e, st) {
      debugPrint('UserService.saveDocumentUrl error: $e\n$st');
      return false;
    }
  }

  // -------------------------
  // رفع وحفظ الوثيقة (تجميعي)
  // -------------------------
  Future<bool> uploadAndSaveDocument(File file, String uid, String type, {String? extension}) async {
    final url = await uploadDocument(file, uid, type, extension: extension);
    if (url != null) {
      return await saveDocumentUrl(uid, type, url);
    }
    return false;
  }

  // -------------------------
  // حذف ملف من Storage وتحديث Firestore
  // -------------------------
  Future<bool> deleteDocument(String uid, String type, {String? extension}) async {
    if (uid.isEmpty) return false;
    try {
      final ext = _normalizeExtension(extension, 'jpg');
      final safeType = type.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final ref = _storage.ref().child('documents/$uid/$safeType.$ext');

      try {
        await ref.delete();
      } catch (e) {
        debugPrint('UserService.deleteDocument: storage delete error: $e');
      }

      final userRef = _firestore.collection(_collection).doc(uid);
      if (type == 'profile') {
        await userRef.update({'profilePictureUrl': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()});
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
            tx.update(userRef, {'documents': docs, 'updatedAt': FieldValue.serverTimestamp()});
          }
        });
      }

      return true;
    } catch (e, st) {
      debugPrint('UserService.deleteDocument error: $e\n$st');
      return false;
    }
  }

  // -------------------------
  // التحقق من وجود الوثيقة
  // -------------------------
  Future<bool> documentExists(String uid, String type, {String? extension}) async {
    if (uid.isEmpty) return false;
    try {
      final ext = _normalizeExtension(extension, 'jpg');
      final safeType = type.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final ref = _storage.ref().child('documents/$uid/$safeType.$ext');
      await ref.getMetadata();
      return true;
    } catch (_) {
      return false;
    }
  }
}