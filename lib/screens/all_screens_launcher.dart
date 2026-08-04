// lib/screens/all_screens_launcher.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/trip_provider.dart';

// نماذج (تأكد أن هذه الملفات موجودة في مشروعك)
import '../models/trip.dart';
import '../models/notification_model.dart';
import '../models/booking_model.dart';
import '../models/gov_fee_rule.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';
import '../models/app_user.dart';
import '../models/rating_model.dart';
import '../models/vehicle.dart';

/// AllScreensLauncher (نسخة آمنة للتطوير)
/// هذه النسخة لا تستدعي منشئات شاشات فعلية قد تتطلب معاملات غير معروفة.
/// بدلاً من ذلك توفر معاينات (Preview) للكائنات الشائعة وتعرض شاشة نائبة
/// للشاشات الفعلية التي يجب فتحها عبر المسارات (routes) أو بعد تعديل _customBuilders.
class AllScreensLauncher extends StatelessWidget {
  const AllScreensLauncher({super.key});

  // قائمة أسماء الشاشات للعرض (آمنة)
  static const List<String> _screenNames = [
    'AuthWrapper',
    'AuthScreen',
    'Home',
    'AvailableTrips',
    'CreateTrip',
    'EditTrip',
    'ManageTrip',
    'DriverHome',
    'DriverTrips',
    'DriverBookings',
    'DriverCalendar',
    'PassengerHome',
    'PassengerCalendar',
    'MyBookings',
    'Notification',
    'NotificationDetail',
    'NotificationSettings',
    'Payment',
    'PaymentConfirmation',
    'Profile',
    'EditProfile',
    'Rating',
    'RatingPreview',
    'UserRatings',
    'TripSearch',
    'TripDetails',
    'TripExporter',
    'TripHistory',
    'Vehicle',
    'VehicleSelection',
    'AgenciesList',
    'AgencyDetail',
    'AgencyForm',
    'AgencyLocationEdit',
    'DebugTrips',
    'Loading',
    'Settings',
    // معاينات إضافية
    'BookingPreview',
    'GovFeeRulePreview',
    'AgencyPreview',
    'AgencyTransactionPreview',
    'AppUserPreview',
    'RatingPreview',
    'VehiclePreview',
  ];

  // خريطة لبناء شاشات معاينة آمنة فقط.
  // لا تستدعي هنا منشئات فعلية من مشروعك قد تتطلب معاملات غير متوافقة.
  static final Map<String, WidgetBuilder> _customBuilders = {
    'BookingPreview': (_) => BookingPreviewScreen(
      booking: Booking(
        id: 'b001',
        tripId: 't001',
        passengerId: 'u001',
        passengerNickname: 'محمد',
        driverId: 'd001',
        amountPaid: 1000.0,
        totalPrice: 1200.0,
        bookedSeatsCount: 1,
        isFamilyBooking: false,
        childrenCount: 0,
        bookingStatus: 'confirmed',
        paymentStatus: 'paid',
        paymentMethod: 'card',
        paymentIntentId: 'pi_123',
        transactionId: 'tx_123',
        paidAt: null,
        seatIndexes: [5],
        seatNumber: 5,
        reservedUntil: null,
        notes: 'ملاحظة تجريبية',
        canceledAt: null,
        updatedBy: 'system',
        createdAt: null,
        updatedAt: null,
        bookingService: 'default',
        pdfService: null,
      ),
    ),
    'GovFeeRulePreview': (_) => GovFeeRulePreviewScreen(
      rule: GovFeeRule(
        id: 'rule_001',
        origin: '*',
        destination: '*',
        exact: false,
        distanceBased: true,
        fixedAmount: 0.0,
        distanceTiers: [
          DistanceTier(minKm: 0.0, maxKm: 50.0, amount: 100.0),
          DistanceTier(minKm: 50.01, maxKm: 200.0, amount: 250.0),
          DistanceTier(minKm: 200.01, maxKm: double.infinity, amount: 500.0),
        ],
        priority: 10,
        isActive: true,
        createdAt: Timestamp.now(),
        updatedAt: null,
      ),
    ),
    'AgencyPreview': (_) => AgencyPreviewScreen(
      agency: Agency(
        id: 'agency001',
        agencyName: 'مكتب الرحلات التجريبي',
        managerName: 'أحمد علي',
        location: {'lat': 13.966, 'lng': 44.000},
        mobileNumber: '+967771234567',
        walletBalance: 25000.0,
        isActive: true,
        createdAt: Timestamp.now(),
        updatedAt: null,
      ),
    ),
    'AgencyTransactionPreview': (_) => AgencyTransactionPreviewScreen(
      transaction: AgencyTransaction(
        id: 'tx_agt_001',
        agencyId: 'agency001',
        amount: 5000.0,
        type: 'credit',
        reason: 'تحويل رصيد تجريبي',
        performedBy: 'system',
        createdAt: Timestamp.now(),
      ),
    ),
    'AppUserPreview': (_) => AppUserPreviewScreen(
      user: AppUser(
        id: 'u001',
        uid: 'u001',
        name: 'محمد صالح',
        nickname: 'محمد',
        email: 'mohammed@example.com',
        userType: 'passenger',
        profilePictureUrl: null,
        mobileNumber: '+967771234567',
        averageRating: 4.8,
        ratingCount: 25,
        createdAt: Timestamp.now(),
        updatedAt: null,
        familyStatus: true,
        childrenCount: 2,
        isIdVerified: false,
        idNumber: null,
        identityCardUrl: null,
        documents: null,
        isDriver: false,
        isActiveDriver: false,
        drivingLicenseNumber: null,
        driverNotes: null,
        plateNumber: null,
        carOwnerOfficialName: null,
        vehicleIds: const [],
        agencyName: null,
        agencyVerified: false,
        agencyVehicles: const [],
        walletBalance: 1500.0,
      ),
    ),
    'RatingPreview': (_) => RatingPreviewScreen(
      rating: Rating(
        id: 'r001',
        tripId: 't001',
        bookingId: 'b001',
        fromUserId: 'u001',
        toUserId: 'd001',
        driverId: 'd001',
        passengerId: 'u001',
        rating: 'excellent',
        score: 4.8,
        category: 'driver',
        note: 'سائق محترف وملتزم بالمواعيد',
        comment: 'كانت الرحلة مريحة وسريعة، أنصح به',
        tags: ['punctual', 'clean', 'friendly'],
        createdAt: Timestamp.now(),
        updatedAt: null,
      ),
    ),
    'VehiclePreview': (_) => VehiclePreviewScreen(
      vehicle: Vehicle(
        id: 'v001',
        plateNumber: 'AB-1234',
        vehicleOwner: 'u002',
        ownerId: 'u002',
        driverId: 'd001',
        driverName: 'سائق تجريبي',
        vehicleType: 'van',
        makeModelYear: 'Toyota Hiace 2018',
        color: 'White',
        maxCapacity: 14,
        licenseNumber: 'LIC-9876',
        isVerified: true,
        sGovernmentRegistered: true,
        notes: 'مركبة للاختبار',
        extra: {'ac': true},
        vehicleDocuments: ['reg.pdf'],
        insuranceExpiryDate: Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
        lastInspectionDate: '2025-01-01',
        carOwnerOfficialName: 'شركة النقل التجريبية',
        createdAt: Timestamp.now(),
        updatedAt: null,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final entries = _screenNames;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Launcher - جميع الواجهات (آمن)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل بيانات الرحلات',
            onPressed: () {
              try {
                final tripProvider = Provider.of<TripProvider>(context, listen: false);
                tripProvider.fetchAvailableTrips();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم طلب إعادة تحميل الرحلات')));
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TripProvider غير متاح')));
              }
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final title = entries[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                child: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onScreenTap(context, title),
            ),
          );
        },
      ),
    );
  }

  void _onScreenTap(BuildContext context, String screenName) {
    // إن وُجد builder مخصص للشاشة، استخدمه
    if (_customBuilders.containsKey(screenName)) {
      Navigator.push(context, MaterialPageRoute(builder: _customBuilders[screenName]!));
      return;
    }

    // حاول فتح route معروف إن وُجد
    final route = _guessRoute(screenName);
    if (route != null) {
      Navigator.pushNamed(context, route).catchError((err) {
        _showPlaceholder(context, screenName, 'فشل فتح المسار $route\n$err');
      });
      return;
    }

    // إن لم يكن هناك route أو builder، اعرض شاشة نائبة تشرح كيفية إضافة بيانات تجريبية
    _showPlaceholder(context, screenName, null);
  }

  String? _guessRoute(String screenName) {
    const map = {
      'Settings': '/settings',
      'Notification': '/notifications',
      'NotificationSettings': '/notification-settings',
      'DevLauncher': '/dev-launcher',
      'AuthWrapper': '/', // إن أردت
    };
    return map[screenName];
  }

  void _showPlaceholder(BuildContext context, String screenName, String? error) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('$screenName — شاشة تجريبية'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null) ...[
                  Text('ملاحظة خطأ:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(error, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                const Text('هذه شاشة نائبة لأن منشئ الشاشة قد يتطلب معاملات خاصة.'),
                const SizedBox(height: 8),
                const Text('ماذا تفعل الآن:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('- إن أردت فتح الشاشة مباشرة من المشغّل، افتح الملف lib/screens/all_screens_launcher.dart'),
                const SizedBox(height: 6),
                const Text('- أضف في الخريطة _customBuilders سطرًا يبني الشاشة مع معاملات تجريبية صحيحة.'),
                const SizedBox(height: 12),
                const Text('أمثلة لقيم تجريبية شائعة:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('- tripId: \'t001\''),
                const Text('- agencyId: \'agency001\''),
                const Text('- notificationId: \'n001\''),
                const Text('- bookingId: \'b001\''),
                const Text('- transactionId: \'tx_123\''),
                const Text('- amount: \'1000\''),
                const SizedBox(height: 12),
                const Text('ملاحظة:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('- بعد أي تعديل شغّل: flutter clean && flutter pub get && flutter run'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditHint(context, screenName);
              },
              child: const Text('كيف أعدل المشغّل؟'),
            ),
          ],
        );
      },
    );
  }

  void _showEditHint(BuildContext context, String screenName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تعديل AllScreensLauncher'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('خطوات سريعة لإضافة بيانات تجريبية لشاشة:'),
                SizedBox(height: 8),
                Text('1) افتح الملف: lib/screens/all_screens_launcher.dart'),
                SizedBox(height: 6),
                Text('2) أضف في _customBuilders سطرًا مثل:'),
                SizedBox(height: 6),
                Text("   'TripDetails': (_) => TripDetailsScreen(tripId: 't001'),"),
                SizedBox(height: 6),
                Text('أو إن كان المنشئ يحتاج كائن Trip:'),
                SizedBox(height: 6),
                Text("   'EditTrip': (_) => EditTripScreen(trip: Trip(id: 't001', origin: 'A', destination: 'B', totalSeats: 20)),"),
                SizedBox(height: 12),
                Text('3) احفظ ثم شغّل hot reload أو أعد تشغيل التطبيق.'),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        );
      },
    );
  }
}

/// ---------------------------
/// معاينات (Preview) بسيطة لكل نموذج
/// ---------------------------

class BookingPreviewScreen extends StatelessWidget {
  final Booking booking;

  const BookingPreviewScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة الحجز')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('معرف الحجز: ${booking.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('معرف الرحلة: ${booking.tripId}'),
            Text('معرف الراكب: ${booking.passengerId}'),
            Text('اسم الراكب: ${booking.passengerNickname}'),
            const SizedBox(height: 8),
            Text('عدد المقاعد المحجوزة: ${booking.bookedSeatsCount}'),
            Text('رقم المقعد (legacy): ${booking.seatNumber ?? '-'}'),
            const SizedBox(height: 8),
            Text('المبلغ المدفوع: ${booking.amountPaid}'),
            Text('السعر الكلي: ${booking.totalPrice}'),
            const SizedBox(height: 8),
            Text('حالة الحجز: ${booking.bookingStatus}'),
            Text('حالة الدفع: ${booking.paymentStatus}'),
            const SizedBox(height: 12),
            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
              const Text('ملاحظات:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(booking.notes!),
            ],
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
          ],
        ),
      ),
    );
  }
}

class GovFeeRulePreviewScreen extends StatelessWidget {
  final GovFeeRule rule;

  const GovFeeRulePreviewScreen({super.key, required this.rule});

  @override
  Widget build(BuildContext context) {
    final testDistances = [10.0, 60.0, 250.0];

    return Scaffold(
      appBar: AppBar(title: const Text('معاينة قاعدة الرسوم الحكومية')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('معرف القاعدة: ${rule.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Origin: ${rule.origin}'),
            Text('Destination: ${rule.destination}'),
            Text('Distance based: ${rule.distanceBased}'),
            Text('Fixed amount: ${rule.fixedAmount}'),
            Text('Active: ${rule.isActive}'),
            const SizedBox(height: 12),
            const Text('الشرائح:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...rule.distanceTiers.map((t) => Text('من ${t.minKm} كم إلى ${t.maxKm == double.infinity ? "∞" : t.maxKm} كم → ${t.amount}')),
            const SizedBox(height: 12),
            const Text('اختبار حساب الرسوم لمسافات مختلفة:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...testDistances.map((d) {
              final fee = rule.calculateFee(distanceKm: d, origin: rule.origin, destination: rule.destination);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text('مسافة ${d} كم → رسوم: ${fee != null ? fee.toString() : 'لا تنطبق القاعدة'}'),
              );
            }).toList(),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
          ],
        ),
      ),
    );
  }
}

class AgencyPreviewScreen extends StatelessWidget {
  final Agency agency;

  const AgencyPreviewScreen({super.key, required this.agency});

  @override
  Widget build(BuildContext context) {
    final loc = agency.location;
    String locText = '-';
    if (loc is Map) {
      final lat = loc['lat'] ?? loc['latitude'] ?? '-';
      final lng = loc['lng'] ?? loc['longitude'] ?? '-';
      locText = '$lat, $lng';
    } else if (loc is GeoPoint) {
      locText = '${loc.latitude}, ${loc.longitude}';
    } else if (loc != null) {
      locText = loc.toString();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('معاينة المكتب')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('معرف المكتب: ${agency.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('اسم المكتب: ${agency.agencyName}'),
            Text('مدير المكتب: ${agency.managerName}'),
            const SizedBox(height: 8),
            Text('الهاتف: ${agency.mobileNumber.isNotEmpty ? agency.mobileNumber : '-'}'),
            Text('الرصيد في المحفظة: ${agency.walletBalance}'),
            const SizedBox(height: 8),
            Text('الموقع: $locText'),
            const SizedBox(height: 8),
            Text('نشط: ${agency.isActive ? "نعم" : "لا"}'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
          ],
        ),
      ),
    );
  }
}

class AgencyTransactionPreviewScreen extends StatelessWidget {
  final AgencyTransaction transaction;

  const AgencyTransactionPreviewScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final created = transaction.createdAt.toDate();
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة معاملة المكتب')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('معرف المعاملة: ${transaction.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('معرف المكتب: ${transaction.agencyId}'),
            Text('المبلغ: ${transaction.amount}'),
            Text('النوع: ${transaction.type}'),
            const SizedBox(height: 8),
            if (transaction.reason != null) Text('السبب: ${transaction.reason}'),
            if (transaction.performedBy != null) Text('تم بواسطة: ${transaction.performedBy}'),
            const SizedBox(height: 8),
            Text('تاريخ الإنشاء: ${created.toLocal()}'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
          ],
        ),
      ),
    );
  }
}

class AppUserPreviewScreen extends StatelessWidget {
  final AppUser user;

  const AppUserPreviewScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة المستخدم')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('معرف المستند: ${user.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('UID: ${user.uid}'),
            Text('الاسم: ${user.name}'),
            Text('الاسم المستعار: ${user.nickname}'),
            Text('البريد: ${user.email}'),
            const SizedBox(height: 8),
            Text('نوع المستخدم: ${user.userType}'),
            Text('الهاتف: ${user.mobileNumber ?? '-'}'),
            const SizedBox(height: 8),
            Text('متوسط التقييم: ${user.averageRating} (${user.ratingCount} تقييم)'),
            const SizedBox(height: 8),
            Text('حالة الأسرة: ${user.familyStatus ? "نعم" : "لا"}'),
            Text('عدد الأطفال: ${user.childrenCount}'),
            const SizedBox(height: 8),
            Text('سائق: ${user.isDriver ? "نعم" : "لا"}'),
            if (user.isDriver) ...[
              const SizedBox(height: 6),
              Text('حالة السائق النشطة: ${user.isActiveDriver ? "نعم" : "لا"}'),
              Text('رخصة القيادة: ${user.drivingLicenseNumber ?? "-"}'),
              Text('لوحة السيارة: ${user.plateNumber ?? "-"}'),
            ],
            const SizedBox(height: 12),
            Text('الرصيد في المحفظة: ${user.walletBalance}'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
          ],
        ),
      ),
    );
  }
}

class RatingPreviewScreen extends StatelessWidget {
  final Rating rating;

  const RatingPreviewScreen({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final created = rating.createdAt?.toDate();
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة التقييم')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('معرف التقييم: ${rating.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('معرف الرحلة: ${rating.tripId}'),
            Text('معرف الحجز: ${rating.bookingId}'),
            Text('من المستخدم: ${rating.fromUserId}'),
            Text('إلى المستخدم: ${rating.toUserId}'),
            const SizedBox(height: 8),
            Text('التصنيف النصي: ${rating.rating.isNotEmpty ? rating.rating : '-'}'),
            Text('الدرجة الرقمية: ${rating.score}'),
            Text('الفئة: ${rating.category.isNotEmpty ? rating.category : '-'}'),
            const SizedBox(height: 8),
            if (rating.note != null && rating.note!.isNotEmpty) ...[
              const Text('ملاحظة قصيرة:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(rating.note!),
            ],
            if (rating.comment != null && rating.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('تعليق:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(rating.comment!),
            ],
            if (rating.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('وسوم:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: rating.tags.map((t) => Chip(label: Text(t))).toList()),
            ],
            const SizedBox(height: 12),
            if (created != null) Text('تاريخ الإنشاء: ${created.toLocal()}'),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
          ],
        ),
      ),
    );
  }
}

class VehiclePreviewScreen extends StatelessWidget {
  final Vehicle vehicle;

  const VehiclePreviewScreen({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة المركبة')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('معرف المركبة: ${vehicle.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('لوحة: ${vehicle.plateNumber}'),
            Text('المالك: ${vehicle.vehicleOwner}'),
            Text('السائق المرتبط: ${vehicle.driverName ?? '-'}'),
            const SizedBox(height: 8),
            Text('النوع: ${vehicle.vehicleType}'),
            Text('الموديل والسنة: ${vehicle.makeModelYear}'),
            Text('اللون: ${vehicle.color}'),
            Text('الطاقة الاستيعابية: ${vehicle.maxCapacity}'),
            const SizedBox(height: 8),
            Text('التحقق: ${vehicle.isVerified ? "نعم" : "لا"}'),
            Text('مسجل حكومياً: ${vehicle.sGovernmentRegistered ? "نعم" : "لا"}'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
          ],
        ),
      ),
    );
  }
}
