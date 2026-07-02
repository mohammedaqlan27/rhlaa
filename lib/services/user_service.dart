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
      // نستخدم AppUser.fromDocument لضمان معالجة الأنواع (double, int, bool)
      return doc.exists ? AppUser.fromDocument(doc) : null;
    } catch (e, st) {
      debugPrint('UserService.getUserById error: $e\n$st');
      return null;
    }
  }

  /// تحديث الملف الشخصي بالكامل بناءً على الموديل
  Future<bool> updateUserProfile(AppUser user) async {
    try {
      if (user.id.isEmpty) {
        debugPrint('UserService.updateUserProfile error: user.id is empty');
        return false;
      }

      // نستخدم toMap() التي قمنا بتجهيزها لتطابق Firestore
      final data = user.toMap();

      // حماية الحقول الأساسية من التغيير العشوائي
      data.remove('id'); // المعرف الخاص بالمستند
      data.remove('uid'); // المعرف الفريد
      data.remove('createdAt'); // تاريخ الإنشاء لا يتغير

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
      // استخراج الامتداد بشكل صحيح
      final ext = extension ?? file.path.split('.').last;
      // تنظيم المسار بشكل احترافي: documents/uid/نوع_الوثيقة.الامتداد
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
  Future<bool> saveDocumentUrl(String uid, String type, String url) async {
    try {
      if (uid.isEmpty) throw Exception('UID فارغ');

      // خريطة لربط نوع الملف المرفوع باسم الحقل الفعلي في Firestore
      final fieldMap = {
        'identity_card': 'identityCardUrl', // بطاقة الهوية
        'profile': 'profilePictureUrl',     // صورة الملف الشخصي
        'license': 'drivingLicenseNumber',  // رخصة القيادة (أو حقل مخصص للرابط)
      };

      final fieldName = fieldMap[type] ?? type;
      await _firestore.collection(_collection).doc(uid).update({fieldName: url});
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