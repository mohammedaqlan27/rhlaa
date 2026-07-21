// test/test_setup.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> initTestFirebase() async {
  await Firebase.initializeApp();
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}

// اختياري: يمكنك استدعاء initTestFirebase() داخل كل ملف اختبار عبر setUpAll
