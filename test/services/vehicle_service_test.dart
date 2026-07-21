import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rhlaa/models/vehicle.dart'; // تأكد من تعديل المسار حسب مشروعك
import 'package:rhlaa/services/vehicle_service.dart'; // تأكد من تعديل المسار

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late VehicleService vehicleService;

  // بيانات تجريبية للاستخدام في الاختبارات
  const String tDriverId = 'driver_123';
  const String tVehicleId = 'vehicle_abc';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    vehicleService = VehicleService(firestore: fakeFirestore);
  });

  // دالة مساعدة لإنشاء كائن مركبة تجريبي
  Vehicle createSampleVehicle({String? id, String? owner}) {
    return Vehicle(
      id: id ?? '',
      plateNumber: '123-ABC',
      vehicleOwner: owner ?? tDriverId,
      vehicleType: 'sedan',
      makeModelYear: 'Toyota Camry 2022',
      color: 'White',
      maxCapacity: 4,
      isVerified: true,
    );
  }

  group('Vehicle Model Tests', () {
    test('يجب تحويل الموديل إلى Map بشكل صحيح (toMap)', () {
      final vehicle = createSampleVehicle();
      final map = vehicle.toMap();

      expect(map['plateNumber'], '123-ABC');
      expect(map['vehicleOwner'], tDriverId);
      expect(map['maxCapacity'], 4);
      expect(map.containsKey('createdAt'), true);
    });

    test('يجب إنشاء الموديل من DocumentSnapshot بشكل صحيح (fromDocument)', () async {
      // إضافة بيانات يدوية لمحاكاة مستند Firestore
      await fakeFirestore.collection('vehicles').doc(tVehicleId).set({
        'plate_number': '999-XYZ', // اختبار دعم snake_case
        'vehicle_owner': tDriverId,
        'capacity': 6, // اختبار دعم الحقول البديلة
        'isVerified': true,
      });

      final doc = await fakeFirestore.collection('vehicles').doc(tVehicleId).get();
      final vehicle = Vehicle.fromDocument(doc);

      expect(vehicle.id, tVehicleId);
      expect(vehicle.plateNumber, '999-XYZ');
      expect(vehicle.maxCapacity, 6);
      expect(vehicle.isVerified, true);
    });
  });

  group('VehicleService Tests', () {
    test('createVehicle: يجب إضافة مركبة جديدة وإعادة المعرف الخاص بها', () async {
      final vehicle = createSampleVehicle();

      final resultId = await vehicleService.createVehicle(vehicle);

      expect(resultId, isNotNull);
      final doc = await fakeFirestore.collection('vehicles').doc(resultId).get();
      expect(doc.exists, true);
      expect(doc.data()?['plateNumber'], '123-ABC');
    });

    test('getVehicleById: يجب جلب بيانات المركبة الصحيحة بواسطة المعرف', () async {
      final vehicle = createSampleVehicle();
      final id = await vehicleService.createVehicle(vehicle);

      final fetchedVehicle = await vehicleService.getVehicleById(id!);

      expect(fetchedVehicle, isNotNull);
      expect(fetchedVehicle!.id, id);
      expect(fetchedVehicle.plateNumber, '123-ABC');
    });

    test('getVehicleById: يجب أن يعيد null إذا كانت المركبة غير موجودة', () async {
      final fetchedVehicle = await vehicleService.getVehicleById('non_existent');
      expect(fetchedVehicle, isNull);
    });

    group('getDriverVehicles: اختبار منطق البحث المتعدد (Fallbacks)', () {
      test('يجب الجلب بواسطة حقل vehicleOwner (الحالة الأساسية)', () async {
        await fakeFirestore.collection('vehicles').add({'vehicleOwner': tDriverId, 'plateNumber': 'V1'});

        final list = await vehicleService.getDriverVehicles(tDriverId);

        expect(list.length, 1);
        expect(list.first.plateNumber, 'V1');
      });

      test('يجب الجلب بواسطة حقل ownerId (الاحتياطي الأول)', () async {
        await fakeFirestore.collection('vehicles').add({'ownerId': tDriverId, 'plateNumber': 'V2'});

        final list = await vehicleService.getDriverVehicles(tDriverId);

        expect(list.length, 1);
        expect(list.first.plateNumber, 'V2');
      });

      test('يجب الجلب بواسطة حقل driverId (الاحتياطي الثاني)', () async {
        await fakeFirestore.collection('vehicles').add({'driverId': tDriverId, 'plateNumber': 'V3'});

        final list = await vehicleService.getDriverVehicles(tDriverId);

        expect(list.length, 1);
        expect(list.first.plateNumber, 'V3');
      });
    });

    test('updateVehicle: يجب تحديث بيانات المركبة بنجاح', () async {
      // 1. إنشاء مركبة
      final id = await vehicleService.createVehicle(createSampleVehicle());

      // 2. تعديل البيانات
      final updatedVehicle = createSampleVehicle(id: id).copyWith(
        color: 'Black',
        plateNumber: 'NEW-111',
      );

      final success = await vehicleService.updateVehicle(id!, updatedVehicle);

      expect(success, true);
      final doc = await fakeFirestore.collection('vehicles').doc(id).get();
      expect(doc.data()?['color'], 'Black');
      expect(doc.data()?['plateNumber'], 'NEW-111');
      expect(doc.data()?.containsKey('updatedAt'), true);
    });

    test('deleteVehicle: يجب حذف المركبة من قاعدة البيانات', () async {
      // 1. إنشاء مركبة
      final id = await vehicleService.createVehicle(createSampleVehicle());

      // 2. الحذف
      final success = await vehicleService.deleteVehicle(id!);

      expect(success, true);
      final doc = await fakeFirestore.collection('vehicles').doc(id).get();
      expect(doc.exists, false);
    });
  });
}