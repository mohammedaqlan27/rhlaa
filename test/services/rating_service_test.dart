import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rhlaa/models/rating_model.dart';
import 'package:rhlaa/services/rating_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late RatingService ratingService;

  const String tTripId = 'trip_001';
  const String tBookingId = 'booking_001';
  const String tFromUser = 'passenger_123';
  const String tToUser = 'driver_456';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    ratingService = RatingService(firestore: fakeFirestore);

    // تصحيح: إنشاء مستند المستخدم المستهدف بالتقييم لكي لا يفشل الـ update
    await fakeFirestore.collection('users').doc(tToUser).set({
      'name': 'Test Driver',
      'averageRating': 0.0,
      'ratingCount': 0,
    });
  });

  group('Rating Model Tests', () {
    test('يجب تحويل الموديل إلى Map بشكل صحيح (toMap)', () {
      final rating = Rating(
        id: 'r1',
        tripId: tTripId,
        bookingId: tBookingId,
        fromUserId: tFromUser,
        toUserId: tToUser,
        score: 4.5,
        rating: 'ممتاز',
      );

      final map = rating.toMap();
      expect(map['tripId'], tTripId);
      expect(map['score'], 4.5);
      expect(map.containsKey('createdAt'), true);
    });

    test('يجب إنشاء الموديل من DocumentSnapshot مع دعم الحقول البديلة', () async {
      await fakeFirestore.collection('ratings').doc('r1').set({
        'trip_id': tTripId,
        'rate_value': 3.5,
        'ratingLabel': 'جيد جداً',
      });

      final doc = await fakeFirestore.collection('ratings').doc('r1').get();
      final rating = Rating.fromDocument(doc);

      expect(rating.tripId, tTripId);
      expect(rating.score, 3.5);
      expect(rating.rating, 'جيد جداً');
    });
  });

  group('RatingService - addOrUpdateRating', () {
    test('يجب إضافة تقييم جديد وتحديث إحصائيات السائق بنجاح', () async {
      final success = await ratingService.addOrUpdateRating(
        tripId: tTripId,
        bookingId: tBookingId,
        fromUserId: tFromUser,
        toUserId: tToUser,
        score: 5.0,
        ratingLabel: 'Excellent',
      );

      expect(success, true);

      final userDoc = await fakeFirestore.collection('users').doc(tToUser).get();
      expect(userDoc.data()?['averageRating'], 5.0);
      expect(userDoc.data()?['ratingCount'], 1);
    });

    test('يجب تحديث التقييم الموجود إذا قام نفس المستخدم بالتقييم مرة أخرى لنفس الرحلة', () async {
      await ratingService.addOrUpdateRating(
        tripId: tTripId,
        bookingId: tBookingId,
        fromUserId: tFromUser,
        toUserId: tToUser,
        score: 5.0,
      );

      await ratingService.addOrUpdateRating(
        tripId: tTripId,
        bookingId: tBookingId,
        fromUserId: tFromUser,
        toUserId: tToUser,
        score: 1.0,
      );

      final ratings = await fakeFirestore.collection('ratings').get();
      expect(ratings.docs.length, 1);

      final userDoc = await fakeFirestore.collection('users').doc(tToUser).get();
      expect(userDoc.data()?['averageRating'], 1.0);
    });
  });

  group('RatingService - Stats Calculation', () {
    test('يجب حساب المتوسط الحسابي بدقة لعدة تقييمات', () async {
      await ratingService.addOrUpdateRating(
        tripId: 'T1', bookingId: 'B1', fromUserId: 'U1', toUserId: tToUser, score: 5.0,
      );
      await ratingService.addOrUpdateRating(
        tripId: 'T2', bookingId: 'B2', fromUserId: 'U2', toUserId: tToUser, score: 4.0,
      );

      final userDoc = await fakeFirestore.collection('users').doc(tToUser).get();
      expect(userDoc.data()?['averageRating'], 4.5);
      expect(userDoc.data()?['ratingCount'], 2);
    });
  });

  group('RatingService - Streams & Queries', () {
    test('getRatingsForUser: يجب جلب التقييمات مرتبة من الأحدث إلى الأقدم', () async {
      await ratingService.addOrUpdateRating(
        tripId: 'old', bookingId: 'b1', fromUserId: 'u1', toUserId: tToUser, score: 1.0,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      await ratingService.addOrUpdateRating(
        tripId: 'new', bookingId: 'b2', fromUserId: 'u2', toUserId: tToUser, score: 5.0,
      );

      final stream = ratingService.getRatingsForUser(tToUser);
      final list = await stream.first;

      expect(list.length, 2);
      expect(list.first.tripId, 'new');
      expect(list.last.tripId, 'old');
    });

    test('getAverageRatingFromUserDoc: يجب جلب القيمة مباشرة من مستند المستخدم', () async {
      await fakeFirestore.collection('users').doc(tToUser).set({
        'averageRating': 4.7,
        'ratingCount': 10,
      });

      final avg = await ratingService.getAverageRatingFromUserDoc(tToUser);
      expect(avg, 4.7);
    });
  });
}