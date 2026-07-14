// test/trip_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:rhlaa/services/trip_service.dart';
import 'package:rhlaa/services/govfees_service.dart';
import 'package:rhlaa/models/trip.dart';

class FakeGovFeesService extends GovFeesService {
  @override
  Future<bool> computeAndSetGovFeeForTrip(String tripId) async => true;

  @override
  Future<double> calculateGovFee({String? origin, String? destination, double? distanceKm}) async => 5.0;

  @override
  Future<int> recomputeGovFeesForAllTrips({int limit = 500}) async => 1;
}

void main() {
  group('TripService basic tests', () {
    late FakeFirebaseFirestore firestore;
    late TripService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = TripService(firestore: firestore, govFeesService: FakeGovFeesService());
    });

    test('createTrip should insert trip document', () async {
      await firestore.collection('users').doc('driver1').set({
        'uid': 'driver1',
        'name': 'Driver One',
        'nickname': 'D1',
        'isDriver': true,
        'isIdVerified': true,
      });

      final trip = Trip(
        id: '',
        driverId: 'driver1',
        driverName: 'Driver One',
        origin: 'Sana\'a',
        destination: 'Taiz',
        totalSeats: 4,
        availableSeats: 4,
        seatStatus: List<bool>.filled(4, true),
        price: 100.0,
      );

      final tripId = await service.createTrip(trip);
      expect(tripId, isNotNull);

      final doc = await firestore.collection('trips').doc(tripId!).get();
      expect(doc.exists, true);
      expect(doc.data()?['driverId'], 'driver1');
      expect(doc.data()?['origin'], 'Sana\'a');
    });
  });
}
