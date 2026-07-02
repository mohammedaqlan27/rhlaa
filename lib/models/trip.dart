import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String title;
  final String description;
  final String driverId;
  final String driverName;
  final String tripCategory;
  final String origin;
  final String destination;
  final String vehicleType;
  final String? vehicleId;

  final int totalSeats;
  final int availableSeats;
  final List<bool> seatStatus; // مصفوفة حالة المقاعد

  final DateTime? departureTime;
  final DateTime? date;
  final String time;
  final String flexibleWindow;

  final String status; // (active, cancelled, completed)
  final double price;
  final double driverRating;

  final String carPlateNumber;
  final String carOwnerOfficialName;

  final Timestamp? createdAt;

  Trip({
    required this.id,
    this.title = '',
    this.description = '',
    this.driverId = '',
    this.driverName = '',
    this.tripCategory = '',
    this.origin = '',
    this.destination = '',
    this.vehicleType = '',
    this.vehicleId,
    this.totalSeats = 0,
    this.availableSeats = 0,
    required this.seatStatus,
    this.departureTime,
    this.date,
    this.time = '',
    this.flexibleWindow = '',
    this.status = 'active',
    this.price = 0.0,
    this.driverRating = 0.0,
    this.carPlateNumber = '',
    this.carOwnerOfficialName = '',
    this.createdAt,
  });

  /// --- الإضافة الجديدة: معالجة البيانات القادمة من Provider ---
  factory Trip.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    int total = data['totalSeats'] ?? data['total_seats'] ?? 0;

    return Trip(
      id: doc.id,
      title: data['title'] ?? data['tripTitle'] ?? 'رحلة مجدولة',
      description: data['description'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? 'سائق رحلاء',
      tripCategory: data['tripCategory'] ?? '',
      origin: data['origin'] ?? 'غير محدد',
      destination: data['destination'] ?? 'غير محدد',
      vehicleType: data['vehicleType'] ?? 'سيارة سيدان',
      totalSeats: total,
      availableSeats: data['availableSeats'] ?? data['available_seats'] ?? 0,
      // معالجة ذكية للمقاعد لضمان عدم حدوث Crash
      seatStatus: data['seatStatus'] != null
          ? List<bool>.from(data['seatStatus'])
          : List<bool>.filled(total > 0 ? total : 4, true),
      departureTime: data['departureTime'] is Timestamp
          ? (data['departureTime'] as Timestamp).toDate()
          : (data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now()),
      status: data['status'] ?? 'active',
      price: (data['price'] ?? 0).toDouble(),
      carPlateNumber: data['carPlateNumber'] ?? '',
      carOwnerOfficialName: data['carOwnerOfficialName'] ?? '',
    );
  }

  /// تحويل النموذج إلى Map للكتابة إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'driverId': driverId,
      'driverName': driverName,
      'tripCategory': tripCategory,
      'origin': origin,
      'destination': destination,
      'vehicleType': vehicleType,
      'vehicleId': vehicleId,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'seatStatus': seatStatus,
      'departureTime': departureTime != null ? Timestamp.fromDate(departureTime!) : null,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'time': time,
      'flexibleWindow': flexibleWindow,
      'status': status,
      'price': price,
      'driverRating': driverRating,
      'carPlateNumber': carPlateNumber,
      'carOwnerOfficialName': carOwnerOfficialName,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  /// إنشاء نموذج من مستند Firestore (الطريقة القديمة - تم الإبقاء عليها لضمان التوافق)
  factory Trip.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String _s(List<String> keys, [String fallback = '']) {
      for (var k in keys) {
        if (data[k] != null && data[k].toString().isNotEmpty) return data[k].toString();
      }
      return fallback;
    }

    int _i(List<String> keys, [int fallback = 0]) {
      for (var k in keys) {
        var v = data[k];
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    double _d(List<String> keys, [double fallback = 0.0]) {
      for (var k in keys) {
        var v = data[k];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    DateTime? _dt(List<String> keys) {
      for (var k in keys) {
        var v = data[k];
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        if (v is String) return DateTime.tryParse(v);
      }
      return null;
    }

    List<bool> _lsB(String key, int total) {
      var v = data[key];
      if (v is List) {
        return v.map((e) => e is bool ? e : (e.toString().toLowerCase() == 'true')).toList();
      } else if (v is bool) {
        return List<bool>.filled(total > 0 ? total : 1, v);
      }
      return List<bool>.filled(total > 0 ? total : 0, true);
    }

    final totalSeatsCount = _i(['totalSeats', 'total_seats']);

    return Trip(
      id: doc.id,
      title: _s(['title']),
      description: _s(['description']),
      driverId: _s(['driverId', 'driver_id']),
      driverName: _s(['driverName', 'driver_name']),
      tripCategory: _s(['tripCategory', 'trip_category']),
      origin: _s(['origin']),
      destination: _s(['destination']),
      vehicleType: _s(['vehicleType', 'vehicle_type']),
      vehicleId: _s(['vehicleId', 'vehicle_id']),
      totalSeats: totalSeatsCount,
      availableSeats: _i(['availableSeats', 'available_seats']),
      seatStatus: _lsB('seatStatus', totalSeatsCount),
      departureTime: _dt(['departureTime', 'departure_time']),
      date: _dt(['date', 'trip_date']),
      time: _s(['time']),
      flexibleWindow: _s(['flexibleWindow', 'flexible_window']),
      status: _s(['status'], 'active'),
      price: _d(['price']),
      driverRating: _d(['driverRating', 'driver_rating']),
      carPlateNumber: _s(['carPlateNumber', 'plateNumber', 'car_plate_number']),
      carOwnerOfficialName: _s(['carOwnerOfficialName', 'car_owner_official_name']),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
    );
  }

  Trip copyWith({
    String? id,
    String? title,
    String? description,
    String? driverId,
    String? driverName,
    String? tripCategory,
    String? origin,
    String? destination,
    String? vehicleType,
    String? vehicleId,
    int? totalSeats,
    int? availableSeats,
    List<bool>? seatStatus,
    DateTime? departureTime,
    DateTime? date,
    String? time,
    String? flexibleWindow,
    String? status,
    double? price,
    double? driverRating,
    String? carPlateNumber,
    String? carOwnerOfficialName,
    Timestamp? createdAt,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      tripCategory: tripCategory ?? this.tripCategory,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleId: vehicleId ?? this.vehicleId,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      seatStatus: seatStatus ?? List<bool>.from(this.seatStatus),
      departureTime: departureTime ?? this.departureTime,
      date: date ?? this.date,
      time: time ?? this.time,
      flexibleWindow: flexibleWindow ?? this.flexibleWindow,
      status: status ?? this.status,
      price: price ?? this.price,
      driverRating: driverRating ?? this.driverRating,
      carPlateNumber: carPlateNumber ?? this.carPlateNumber,
      carOwnerOfficialName: carOwnerOfficialName ?? this.carOwnerOfficialName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Trip(ID: $id, From: $origin, To: $destination, Price: $price)';
}