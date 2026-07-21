// test/services/user_service_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rhlaa/services/user_service.dart';
import 'package:rhlaa/models/app_user.dart';

@GenerateMocks([
  FirebaseStorage,
  Reference,
  UploadTask,
  TaskSnapshot,
  FirebaseFirestore,
  CollectionReference<Map<String, dynamic>>,
  DocumentReference<Map<String, dynamic>>,
])
import 'user_service_test.mocks.dart';

void main() {
  group('UserService with FakeFirestore', ()
  {
    late FakeFirebaseFirestore fakeFs;
    late UserService service;

    setUp(() {
      fakeFs = FakeFirebaseFirestore();
      service = UserService(firestore: fakeFs);
    });

    test('getUserById returns AppUser when exists', () async {
      final uid = 'u1';
      await fakeFs.collection('users').doc(uid).set({
        'uid': uid,
        'name': 'Mohammed',
        'nickname': 'Mo',
        'email': 'm@example.com',
        'userType': 'passenger',
      });

      final user = await service.getUserById(uid);
      expect(user, isNotNull);
      expect(user?.id, uid);
      expect(user?.name, 'Mohammed');
    });

    test('getUserById returns null for empty uid', () async {
      final user = await service.getUserById('');
      expect(user, isNull);
    });

    test('createOrSetUser writes document and sets createdAt', () async {
      final u = AppUser(
        id: 'u2',
        uid: 'u2',
        name: 'A',
        nickname: 'B',
        email: 'a@b.com',
        userType: 'driver',
      );

      final ok = await service.createOrSetUser(u);
      expect(ok, isTrue);

      final doc = await fakeFs.collection('users').doc('u2').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'A');
      expect(doc.data()?['createdAt'], isNotNull);
    });

    test('updateUserProfile removes protected fields and updates', () async {
      final uid = 'u3';
      // create doc with createdAt so update doesn't remove it
      await fakeFs.collection('users').doc(uid).set({
        'uid': uid,
        'name': 'Old',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final u = AppUser(
        id: uid,
        uid: uid,
        name: 'NewName',
        nickname: 'NN',
        email: 'e@e.com',
        userType: 'passenger',
      );

      final ok = await service.updateUserProfile(u);
      expect(ok, isTrue);

      final doc = await fakeFs.collection('users').doc(uid).get();
      expect(doc.data()?['name'], 'NewName');
      expect(doc.data()?['createdAt'], isNotNull);
    });

    test('updateUserFields converts childrenCount and updates', () async {
      final uid = 'u4';
      await fakeFs.collection('users').doc(uid).set({'uid': uid});
      final ok = await service.updateUserFields(
          uid, {'childrenCount': '3', 'mobileNumber': '123'});
      expect(ok, isTrue);

      final doc = await fakeFs.collection('users').doc(uid).get();
      expect(doc.data()?['childrenCount'], 3);
      expect(doc.data()?['mobileNumber'], '123');
    });

    test('updateUserFields returns false when document not found', () async {
      final ok = await service.updateUserFields('no_such', {'name': 'X'});
      expect(ok, isFalse);
    });

    test(
        'saveDocumentUrl creates documents map when user doc missing', () async {
      final ok = await service.saveDocumentUrl(
          'new_u', 'idCard', 'https://url');
      expect(ok, isTrue);

      final doc = await fakeFs.collection('users').doc('new_u').get();
      expect(doc.exists, isTrue);
      final docs = doc.data()?['documents'] as Map<String, dynamic>;
      expect(docs['idCard'], 'https://url');
      expect(doc.data()?['createdAt'], isNotNull);
    });

    test('documentExists returns false when storage metadata throws', () async {
      final mockStorage = MockFirebaseStorage();
      final mockRef = MockReference();

      // إزالة () => وإزالة التحويلات
      when(mockStorage.ref()).thenReturn(mockRef);
      when(mockRef.child(any)).thenReturn(mockRef);
      when(mockRef.getMetadata()).thenThrow(Exception('not found'));

      final svc = UserService(firestore: fakeFs, storage: mockStorage);
      final exists = await svc.documentExists('u', 'idCard', extension: 'jpg');
      expect(exists, isFalse);
    });
  });

    group('UserService with mocked Firestore and Storage for failures', () {
      late MockFirebaseFirestore mockFs;
      late MockDocumentReference mockDocRef;
      late MockCollectionReference mockCollection;
      late UserService svcWithMockFs;

      setUp(() {
        mockFs = MockFirebaseFirestore();
        mockCollection = MockCollectionReference();
        mockDocRef = MockDocumentReference();

        // تصحيح: إزالة () => وإزالة التحويلات (Casting) غير الصحيحة
        when(mockFs.collection('users')).thenReturn(
            mockCollection as CollectionReference<Map<String, dynamic>>);
        when(mockCollection.doc(any)).thenReturn(mockDocRef);

        svcWithMockFs = UserService(firestore: mockFs);
      });

      test('createOrSetUser returns false when set throws', () async {
        // تصحيح السطر الذي سألت عنه:
        when(mockDocRef.set(any, any)).thenThrow(Exception('set failed'));

        final u = AppUser(id: 'x',
            uid: 'x',
            name: 'n',
            nickname: '',
            email: '',
            userType: 'passenger');
        final ok = await svcWithMockFs.createOrSetUser(u);
        expect(ok, isFalse);
      });

      test('updateUserFields returns false when update throws', () async {
        // تصحيح: إزالة () => و any()
        when(mockDocRef.update(any)).thenThrow(Exception('update failed'));
        final ok = await svcWithMockFs.updateUserFields('x', {'name': 'A'});
        expect(ok, isFalse);
      });

      test('saveDocumentUrl returns false when transaction throws', () async {
        // تصحيح: إزالة () => و any()
        when(mockFs.runTransaction(any)).thenThrow(Exception('tx failed'));
        final ok = await svcWithMockFs.saveDocumentUrl('u', 'id', 'url');
        expect(ok, isFalse);
      });
    });
    group('uploadDocument with mocked FirebaseStorage', () {
      late MockFirebaseStorage mockStorage;
      late MockReference mockRef;
      late MockUploadTask mockUploadTask;
      late MockTaskSnapshot mockSnapshot;
      late UserService svc;
      Directory? tmpDir;

      setUp(() {
        mockStorage = MockFirebaseStorage();
        mockRef = MockReference();
        mockUploadTask = MockUploadTask();
        mockSnapshot = MockTaskSnapshot();

        // إرجاع المرجع نفسه عند طلب ref() أو child() للسماح بالتسلسل (Chaining)
        when(mockStorage.ref()).thenReturn(mockRef);
        when(mockRef.child(any)).thenReturn(mockRef);

        // إعداد عملية الرفع
        when(mockRef.putFile(any)).thenReturn(mockUploadTask);

        // إعداد اكتمال المهمة (استخدام thenAnswer لأنها Future)
        when(mockUploadTask.whenComplete(any)).thenAnswer((
            _) async => mockSnapshot);

        when(mockSnapshot.ref).thenReturn(mockRef);

        // إعداد رابط التحميل
        when(mockRef.getDownloadURL()).thenAnswer((
            _) async => 'https://download.url/doc.jpg');

        svc = UserService(
            firestore: FakeFirebaseFirestore(), storage: mockStorage);
      });

      tearDown(() {
        if (tmpDir != null && tmpDir!.existsSync()) {
          try {
            tmpDir!.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      test('uploadDocument returns null when putFile throws', () async {
        tmpDir = Directory.systemTemp.createTempSync('user_service_test_');
        final tmpFile = File('${tmpDir!.path}/dummy.txt')
          ..writeAsStringSync('dummy content');

        // التصحيح هنا: إزالة () => وإزالة الأقواس من any
        when(mockRef.putFile(any)).thenThrow(Exception('upload failed'));

        final url = await svc.uploadDocument(
            tmpFile, 'u1', 'idCard', extension: 'txt');

        expect(url, isNull);
      });
    });
  }