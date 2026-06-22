import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'users';

  Future<AppUser?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      return doc.exists ? AppUser.fromDocument(doc) : null;
    } catch (e, st) {
      debugPrint('UserService.getUserById error: $e\n$st');
      return null;
    }
  }

  Future<bool> updateUserProfile(AppUser user) async {
    try {
      if (user.id.isEmpty) { // تم التعديل لتتوافق مع كونها String دائم في الموديل الجديد
        debugPrint('UserService.updateUserProfile error: user.id is empty');
        return false;
      }

      final data = Map<String, dynamic>.from(user.toMap());
      data.remove('id');

      final normalized = _normalizeMapKeysToCamelCase(data);
      normalized.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));

      if (normalized.isEmpty) return true;

      await _firestore.collection(_collection).doc(user.id).set(normalized, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserProfile error: $e\n$st');
      return false;
    }
  }

  Future<bool> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (uid.isEmpty) return false;
    try {
      final normalized = _normalizeMapKeysToCamelCase(fields);
      normalized.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));
      if (normalized.isEmpty) return true;
      await _firestore.collection(_collection).doc(uid).set(normalized, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.updateUserFields error: $e\n$st');
      return false;
    }
  }

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

  Future<bool> saveDocumentUrl(String uid, String type, String url) async {
    try {
      if (uid.isEmpty) throw Exception('UID فارغ');

      final fieldMap = {
        'id': 'idLivePhotoUrl',
        'license': 'licenseImageUrl',
        'vehicle': 'vehicleImageUrl',
      };

      final fieldName = fieldMap[type] ?? type;
      await _firestore.collection(_collection).doc(uid).set({fieldName: url}, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('UserService.saveDocumentUrl error: $e\n$st');
      return false;
    }
  }

  Future<bool> uploadAndSaveDocument(File file, String uid, String type, {String? extension}) async {
    final url = await uploadDocument(file, uid, type, extension: extension);
    return url != null ? await saveDocumentUrl(uid, type, url) : false;
  }

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