import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rhlaa/services/payment_service.dart';
import 'package:rhlaa/services/notification_service.dart';
import 'package:rhlaa/services/booking_service.dart';
import 'package:rhlaa/services/agencies_service.dart';

// تأكد من أن PaymentProviderAdapter و PaymentResult معرفان داخل ملف payment_service.dart أو قم باستيرادهما

// توليد النسخ الوهمية للخدمات التي تعتمد عليها خدمة الدفع
import 'booking_service_test.mocks.dart' show MockNotificationService;
@GenerateMocks([
  NotificationService,
  BookingService,
  AgenciesService,
  PaymentProviderAdapter,
])
import 'payment_service_test.mocks.dart' hide MockNotificationService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late MockNotificationService mockNotification;
  late MockBookingService mockBookingService;
  late MockAgenciesService mockAgencies;
  late MockPaymentProviderAdapter mockAdapter;
  late PaymentService paymentService;

  // بيانات ثابتة للاختبار 
  const String tBookingId = 'booking_123';
  const String tPassengerId = 'passenger_456';
  const String tDriverId = 'driver_789';
  const String tAgencyId = 'agency_001';
  const double tAmount = 1000.0;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    mockNotification = MockNotificationService();
    mockBookingService = MockBookingService();
    mockAgencies = MockAgenciesService();
    mockAdapter = MockPaymentProviderAdapter();

    paymentService = PaymentService(
      firestore: fakeFirestore,
      notificationService: mockNotification,
      bookingService: mockBookingService,
      agenciesService: mockAgencies,
    );

    // استبدال المحول الافتراضي بالمحول الوهمي للاختبار
    paymentService.providerAdapter = mockAdapter;

    // 1. إعداد بيانات الحجز في Firestore الوهمي
    await fakeFirestore.collection('bookings').doc(tBookingId).set({
      'tripId': 'trip_abc',
      'passengerId': tPassengerId,
      'driverId': tDriverId,
      'agencyId': tAgencyId,
      'totalPrice': tAmount,
      'bookingStatus': 'pending',
      'paymentStatus': 'unpaid',
    });

    // 2. إعداد بيانات الراكب (رصيد المحفظة 2000)
    await fakeFirestore.collection('users').doc(tPassengerId).set({
      'walletBalance': 2000.0,
      'nickname': 'Ahmed',
    });

    // 3. إعداد بيانات السائق والمكتب
    await fakeFirestore.collection('users').doc(tDriverId).set({'walletBalance': 0.0});
    await fakeFirestore.collection('agencies').doc(tAgencyId).set({'walletBalance': 0.0});
  });

  group('PaymentService Tests - اختبارات خدمة الدفع', () {

    test('الدفع عبر المحفظة (Wallet): يجب خصم الرصيد وتوزيع العمولات وتأكيد الحجز', () async {
      // إعداد التوقعات: تأكيد الحجز سيعيد null (نجاح)
      when(mockBookingService.confirmBookingAfterPayment(
        bookingId: anyNamed('bookingId'),
        paymentIntentId: anyNamed('paymentIntentId'),
        payerId: anyNamed('payerId'),
      )).thenAnswer((_) async => null);

      // تنفيذ الدفع
      final result = await paymentService.processPayment(
        bookingId: tBookingId,
        amount: tAmount,
        paymentMethod: 'wallet',
      );

      // التحقق من النتيجة
      expect(result.success, true);

      // التحقق من خصم الرصيد من الراكب (2000 - 1000 = 1000)
      final passengerDoc = await fakeFirestore.collection('users').doc(tPassengerId).get();
      expect(passengerDoc.data()?['walletBalance'], 1000.0);

      // التحقق من إنشاء سجل دفع في مجموعة payments
      final payments = await fakeFirestore.collection('payments').where('bookingId', isEqualTo: tBookingId).get();
      expect(payments.docs.length, 1);
      expect(payments.docs.first.data()['paymentMethod'], 'wallet');

      // التحقق من استدعاء تأكيد الحجز والإشعارات
      verify(mockBookingService.confirmBookingAfterPayment(
        bookingId: tBookingId,
        paymentIntentId: anyNamed('paymentIntentId'),
        payerId: tPassengerId,
      )).called(1);

      // التصحيح هنا: استخدام argThat مع contains للمعاملات المسماة
      verify(mockNotification.sendNotification(
        userId: tPassengerId,
        title: anyNamed('title'),
        body: anyNamed('body'),
        type: 'payment',
      )).called(1);
    });

    test('الدفع عبر مزود خارجي: يجب استدعاء المزود وتسجيل الدفع عند النجاح', () async {
      // إعداد محول الدفع الوهمي ليعيد نجاح
      when(mockAdapter.process(
        bookingId: anyNamed('bookingId'),
        amount: anyNamed('amount'),
        paymentMethod: anyNamed('paymentMethod'),
        currency: anyNamed('currency'),
      )).thenAnswer((_) async => PaymentResult(success: true, transactionId: 'ext_tx_111'));

      when(mockBookingService.confirmBookingAfterPayment(
        bookingId: anyNamed('bookingId'),
        paymentIntentId: anyNamed('paymentIntentId'),
        payerId: anyNamed('payerId'),
      )).thenAnswer((_) async => null);

      final result = await paymentService.processPayment(
        bookingId: tBookingId,
        amount: tAmount,
        paymentMethod: 'krimy_bank',
      );

      expect(result.success, true);
      expect(result.transactionId, 'ext_tx_111');

      // التأكد من تحديث حالة الحجز في Firestore
      final bookingDoc = await fakeFirestore.collection('bookings').doc(tBookingId).get();
      expect(bookingDoc.data()?['paymentStatus'], 'paid');
    });

    test('الاسترجاع (Refund): يجب إعادة الأموال للمحفظة وتحديث حالة الدفع', () async {
      // 1. إضافة سجل دفع سابق عبر المحفظة
      final String txId = 'wallet-tx-555';
      await fakeFirestore.collection('payments').add({
        'bookingId': tBookingId,
        'passengerId': tPassengerId,
        'driverId': tDriverId,
        'amount': tAmount,
        'paymentMethod': 'wallet',
        'transactionId': txId,
        'status': 'paid',
      });

      // 2. تنفيذ الاسترجاع
      final result = await paymentService.refundPayment(
        transactionId: txId,
        reason: 'إلغاء الرحلة',
      );

      expect(result.success, true);

      // 3. التحقق من عودة الرصيد للراكب (كان 2000، خصم منه 1000 في الحجز، ثم استرجع 1000 = 2000)
      final passengerDoc = await fakeFirestore.collection('users').doc(tPassengerId).get();
      expect(passengerDoc.data()?['walletBalance'], 2000.0);

      // 4. التحقق من تحديث حالة الحجز إلى refunded
      final bookingDoc = await fakeFirestore.collection('bookings').doc(tBookingId).get();
      expect(bookingDoc.data()?['paymentStatus'], 'refunded');
    });

    test('فشل الدفع: يجب ألا يتم خصم رصيد إذا كان المبلغ غير كافٍ', () async {
      // جعل رصيد الراكب أقل من مبلغ الحجز
      await fakeFirestore.collection('users').doc(tPassengerId).update({'walletBalance': 500.0});

      final result = await paymentService.processPayment(
        bookingId: tBookingId,
        amount: tAmount,
        paymentMethod: 'wallet',
      );

      expect(result.success, false);
      expect(result.message, contains('غير كافٍ'));

      // التأكد من أن الرصيد لم يتغير
      final passengerDoc = await fakeFirestore.collection('users').doc(tPassengerId).get();
      expect(passengerDoc.data()?['walletBalance'], 500.0);
    });

  });
}