// test/user_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rhlaa/services/user_service.dart';
import 'package:rhlaa/models/app_user.dart';

void main() {
  group('UserService basic tests', () {
    late MockFirestoreInstance firestore;
    late MockFirebaseStorage storage;
    late UserService service;

    setUp(() {
      firestore = MockFirestoreInstance();
      storage = MockFirebaseStorage();
      service = UserService(firestore: firestore, storage: storage);
    });

    test('createOrSetUser should create user document', () async {
      final user = AppUser(
        id: 'u1',
        name: 'Mohammed',
        nickname: 'Mo',
        email: 'mo@example.com',
        userType: 'driver',
        averageRating: 0.0,
        ratingCount: 0,
      );

      final result = await service.createOrSetUser(user);
      expect(result, true);

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.exists, true);
      expect(doc.data()?['name'], 'Mohammed');
      expect(doc.data()?['userType'], 'driver');
    });

    test('updateUserFields should update childrenCount as int', () async {
      await firestore.collection('users').doc('u2').set({
        'name': 'Ali',
        'childrenCount': 0,
      });

      final result = await service.updateUserFields('u2', {'childrenCount': '3'});
      expect(result, true);

      final doc = await firestore.collection('users').doc('u2').get();
      expect(doc.data()?['childrenCount'], 3);
    });

    test('saveDocumentUrl should add url to documents map', () async {
      await firestore.collection('users').doc('u3').set({'name': 'Sara'});

      final result = await service.saveDocumentUrl('u3', 'identity_card', 'http://fakeurl');
      expect(result, true);

      final doc = await firestore.collection('users').doc('u3').get();
      final docs = doc.data()?['documents'] as Map<String, dynamic>;
      expect(docs['identity_card'], 'http://fakeurl');
    });

    test('saveDocumentUrl with type profile should update profilePictureUrl', () async {
      await firestore.collection('users').doc('u4').set({'name': 'Khaled'});

      final result = await service.saveDocumentUrl('u4', 'profile', 'http://profileurl');
      expect(result, true);

      final doc = await firestore.collection('users').doc('u4').get();
      expect(doc.data()?['profilePictureUrl'], 'http://profileurl');
    });
  });
}
