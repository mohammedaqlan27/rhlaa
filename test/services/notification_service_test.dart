import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rhlaa/services/notification_service.dart';

// تم إضافة HttpsCallableResult هنا ليتم توليد نسخة وهمية منه
@GenerateMocks([FirebaseFunctions, HttpsCallable, HttpsCallableResult])
import 'notification_service_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult; // تعريف النتيجة الوهمية
  late NotificationService notificationService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult(); // تهيئة النتيجة الوهمية

    // إعداد الـ Mock ليعيد الـ callable الخاص بـ sendNotificationToUser
    when(mockFunctions.httpsCallable('sendNotificationToUser'))
        .thenReturn(mockCallable);

    // إعداد النتيجة الوهمية لتعيد بيانات (يمكنك تغييرها حسب الحاجة)
    when(mockResult.data).thenReturn({'status': 'success'});

    // إعداد الـ callable ليعيد النتيجة الوهمية بدلاً من HttpsCallableResult(null)
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);

    // حقن الاعتمادات (Dependency Injection)
    notificationService = NotificationService(
      firestore: fakeFirestore,
      functions: mockFunctions,
    );
  });

  group('NotificationService Tests', () {

    test('sendNotification يجب أن يحفظ الإشعار في Firestore ويستدعي الـ Function', () async {
      await notificationService.sendNotification(
        userId: 'user123',
        title: 'تجربة',
        body: 'نص الاختبار',
        sendPush: true,
      );

      // التأكد من الحفظ في Firestore الوهمي
      final snapshot = await fakeFirestore.collection('notifications').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['title'], 'تجربة');

      // التحقق من استدعاء Cloud Function (التي ستوجه للإيموليتر في الخدمة الأصلية)
      verify(mockCallable.call(any)).called(1);
    });

    test('getUnreadCount يجب أن يعيد عدد الإشعارات غير المقروءة', () async {
      final coll = fakeFirestore.collection('notifications');
      await coll.add({'userId': 'u1', 'isRead': false});
      await coll.add({'userId': 'u1', 'isRead': false});
      await coll.add({'userId': 'u1', 'isRead': true});

      final count = await notificationService.getUnreadCount('u1');
      expect(count, 2);
    });

    test('markAsRead يجب أن يغير حالة الإشعار إلى مقروء', () async {
      final docRef = await fakeFirestore.collection('notifications').add({
        'userId': 'u1',
        'isRead': false,
      });

      await notificationService.markAsRead(docRef.id);

      final doc = await docRef.get();
      expect(doc.data()?['isRead'], isTrue);
    });

    test('scheduleNotification يجب أن يحفظ في collection المجدولة', () async {
      await notificationService.scheduleNotification(
        userId: 'u1',
        title: 'تذكير',
        body: 'نص التذكير',
        sendAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final snapshot = await fakeFirestore.collection('scheduled_notifications').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['title'], 'تذكير');
    });

    test('sendBookingPendingPaymentReminder يجب أن يرسل الإشعار الصحيح', () async {
      await notificationService.sendBookingPendingPaymentReminder(
        userId: 'u1',
        bookingId: 'B123',
        sendPush: false,
      );

      final snapshot = await fakeFirestore.collection('notifications').get();
      expect(snapshot.docs.first.data()['type'], 'pending_payment');
      expect(snapshot.docs.first.data()['metadata']['bookingId'], 'B123');
    });
  });
}