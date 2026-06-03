// lib/services/user_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'users';

  /// جلب بيانات مستخدم حسب المعرف
  Future<AppUser?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      return doc.exists ? AppUser.fromDocument(doc) : null;
    } catch (e, st) {
      debugPrint('UserService.getUserById error: $e\n$st');
      return null;
    }
  }

  /// تحديث بيانات المستخدم باستخدام AppUser.toMap
  /// يحافظ على الحقول الأخرى عبر merge: true
  Future<bool> updateUserProfile(AppUser user) async {
    try {
      if (user.id == null || user.id!.isEmpty) {
        debugPrint('UserService.updateUserProfile error: user.id is null or empty');
        return false;
      }

      final data = Map<String, dynamic>.from(user.toMap());
      data.remove('id');

      // تأكد من كتابة camelCase فقط: نطبّع المفاتيح
      final normalized = _normalizeMapKeysToCamelCase(data);

      // إزالة القيم الفارغة
      normalized.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));

      if (normalized.isEmpty) {
        // لا شيء للتحديث
        return true;
      }

      await _firestore.collection(_collection).doc(user.id).set(normalized, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserProfile error: $e\n$st');
      return false;
    }
  }

  /// تحديث حقول محددة للمستخدم بواسطة uid وخريطة من الحقول.
  /// تقوم هذه الدالة بتطبيع المفاتيح إلى camelCase، وإزالة القيم الفارغة، ثم الكتابة بدمج.
  Future<bool> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (uid.isEmpty) return false;
    try {
      final normalized = _normalizeMapKeysToCamelCase(fields);
      normalized.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));
      if (normalized.isEmpty) return true; // لا شيء للتحديث
      await _firestore.collection(_collection).doc(uid).set(normalized, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserFields error: $e\n$st');
      return false;
    }
  }

  /// رفع ملف إلى Firebase Storage وإرجاع رابط التحميل
  /// يدعم أنواع ملفات متعددة ويستخدم اسمًا واضحًا للمسار
  Future<String?> uploadDocument(File file, String uid, String type, {String? extension}) async {
    try {
      final ext = extension ?? file.path.split('.').last;
      final ref = _storage.ref().child('documents/$uid/$type.$ext');

      // putFile يعيد UploadTask؛ ننتظر اكتمال التحميل ونأخذ الـ TaskSnapshot
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e, st) {
      debugPrint('UserService.uploadDocument error: $e\n$st');
      return null;
    }
  }

  /// حفظ رابط الوثيقة في مستند المستخدم
  /// type يمكن أن يكون 'id', 'license', 'vehicle' أو أي نوع تعرفه في التطبيق
  Future<bool> saveDocumentUrl(String uid, String type, String url) async {
    try {
      if (uid.isEmpty) throw Exception('UID فارغ');

      final fieldMap = {
        'id': 'idLivePhotoUrl',
        'license': 'licenseImageUrl',
        'vehicle': 'vehicleImageUrl',
        // يمكنك إضافة أنواع أخرى هنا عند الحاجة
      };

      final fieldName = fieldMap[type] ?? type;

      // نكتب بصيغة camelCase (fieldName مفترض أن يكون camelCase أو اسم مخصص)
      await _firestore.collection(_collection).doc(uid).set({fieldName: url}, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.saveDocumentUrl error: $e\n$st');
      return false;
    }
  }

  /// رفع وحفظ الوثيقة في خطوة واحدة
  Future<bool> uploadAndSaveDocument(File file, String uid, String type, {String? extension}) async {
    final url = await uploadDocument(file, uid, type, extension: extension);
    return url != null ? await saveDocumentUrl(uid, type, url) : false;
  }

  /// حذف ملف من التخزين
  Future<bool> deleteDocument(String uid, String type, {String? extension}) async {
    try {
      final ext = extension ?? 'jpg';
      final ref = _storage.ref().child('documents/$uid/$type.$ext');
      await ref.delete();
      return true;
    } catch (e, st) {
      debugPrint('UserService.deleteDocument error: $e\n$st');
      return false;
    }
  }

  /// التحقق من وجود ملف في التخزين
  Future<bool> documentExists(String uid, String type, {String? extension}) async {
    try {
      final ext = extension ?? 'jpg';
      final ref = _storage.ref().child('documents/$uid/$type.$ext');
      await ref.getMetadata();
      return true;
    } catch (_) {
      // لا نطبع الاستثناء هنا لأن وجوده يعني غالبًا عدم وجود الملف
      return false;
    }
  }

  // =================== Helpers ===================

  /// يحول مفاتيح الخريطة من snake_case إلى camelCase تلقائياً إن وُجدت،
  /// ويترك المفاتيح التي تبدو بالفعل camelCase كما هي.
  Map<String, dynamic> _normalizeMapKeysToCamelCase(Map<String, dynamic> input) {
    final Map<String, dynamic> out = {};
    input.forEach((key, value) {
      if (key.contains('_')) {
        final parts = key.split('_');
        final camel = parts.first + parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
        out[camel] = value;
      } else {
        out[key] = value;
      }
    });
    return out;
  }
}
