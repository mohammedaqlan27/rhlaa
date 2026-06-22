// lib/pages_tester.dart
//
// صفحة اختبارية لتشغيل الشاشات والخدمات محليًا أثناء التطوير.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// نماذج
import 'models/trip.dart';
import 'models/booking_model.dart';
import 'models/app_user.dart';
import 'models/notification_model.dart';
import 'models/rating_model.dart';
import 'models/vehicle.dart';

// حالة المصادقة
import 'state/auth_state.dart';

// شاشات أساسية
import 'screens/auth_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/passenger_home_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/create_trip_screen.dart';
import 'screens/available_trips_screen.dart';
import 'screens/trip_details_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/driver_bookings_screen.dart';
import 'screens/driver_trips_screen.dart';
import 'screens/driver_calendar_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_trip_screen.dart';

// الشاشات الجديدة
import 'screens/manage_trip_screen.dart';
import 'screens/passenger_calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/trip_search_screen.dart';
import 'screens/user_ratings_screen.dart';
import 'screens/vehicle_selection_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/payment_confirmation_screen.dart';
import 'screens/vehicle_screen.dart';

// خدمات
import 'services/booking_service.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/trip_service.dart';
import 'services/rating_service.dart';
import 'services/firebase_service.dart';
import 'services/user_service.dart';
import 'services/auth_service.dart';
import 'utils/trip_exporter.dart' as exporter_service; // أدوات مساعدة / Exporter
import 'utils/app_localizations.dart';
import 'utils/constants.dart';

// ويدجت
import 'widgets/trip_card.dart';
import 'widgets/payment_deeplink_widget.dart';
import 'widgets/custom_button.dart';
import 'widgets/custom_text_field.dart';
import 'widgets/loading_indicator.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        Provider<BookingService>(create: (_) => BookingService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        // نستخدم هنا مزوّد PaymentService واحد فقط (المحاكاة إن وُجد)
        Provider<PaymentService>(create: (_) {
          final svc = PaymentService();
          // محاولة ضبط محاكاة المزود إن كانت متاحة في المشروع
          try {
            // MockProviderAdapter قد لا يكون معرفًا في مشروعك؛ هذا السطر محاط بمحاولة للحماية
            svc.providerAdapter = MockProviderAdapter(failureRate: 0.1, minDelayMs: 400, maxDelayMs: 1200);
          } catch (_) {}
          return svc;
        }),
        Provider<TripService>(create: (_) => TripService()),
        Provider<RatingService>(create: (_) => RatingService()),
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        Provider<UserService>(create: (_) => UserService()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const PagesTesterApp(),
    ),
  );
}

class PagesTesterApp extends StatelessWidget {
  const PagesTesterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pages Tester',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primaryColor: const Color(0xFF6A0DAD), // بنفسجي
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A0DAD),
          primary: const Color(0xFF6A0DAD),
          secondary: const Color(0xFF5DADE2), // أزرق فاتح
        ),
        fontFamily: 'Cairo',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        // استخدم CardThemeData بدلاً من CardTheme لتوافق ThemeData
        cardTheme: const CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6A0DAD),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: const TestSelector(),
    );
  }
}

class TestSelector extends StatelessWidget {
  const TestSelector({Key? key}) : super(key: key);

  Trip _sampleTrip() {
    final now = DateTime.now();
    return Trip(
      id: 'testTrip',
      title: 'رحلة تجريبية',
      description: 'رحلة من صنعاء إلى تعز',
      driverId: 'driver123',
      driverName: 'محمد',
      tripCategory: 'داخلية',
      origin: 'صنعاء',
      destination: 'تعز',
      vehicleType: 'باص',
      vehicleId: 'veh123',
      totalSeats: 4,
      availableSeats: 2,
      seatStatus: [true, false, false, true],
      departureTime: now,
      date: now,
      time: '08:30',
      flexibleWindow: '',
      status: 'مفعّلة',
      price: 1500.0,
      driverRating: 4.5,
      carPlateNumber: '1234',
      carOwnerOfficialName: 'محمد السائق',
      createdAt: Timestamp.fromDate(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _sampleTrip();

    return Scaffold(
      appBar: AppBar(title: const Text('اختبار الصفحات')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Auth Wrapper (توجيه تلقائي)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthWrapper())),
          ),
          ListTile(
            title: const Text('صفحة تسجيل الدخول'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
          ),
          ListTile(
            title: const Text('الصفحة الرئيسية (توجيه حسب الدور)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
          ),
          ListTile(
            title: const Text('صفحة الراكب'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerHomeScreen())),
          ),
          ListTile(
            title: const Text('صفحة السائق'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverHomeScreen())),
          ),
          ListTile(
            title: const Text('إنشاء رحلة جديدة'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen())),
          ),
          ListTile(
            title: const Text('الرحلات المتاحة'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableTripsScreen(destination: 'صنعاء'))),
          ),
          ListTile(
            title: const Text('تفاصيل الرحلة (كائن Trip تجريبي)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))),
          ),

          ListTile(
            title: const Text('عرض بطاقة الرحلة (TripCard)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('معاينة بطاقة الرحلة')),
              body: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TripCard(trip: trip, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
                }),
              ),
            ))),
          ),
          ListTile(
            title: const Text('شاشة الدفع (PaymentScreen)'),
            subtitle: const Text('اختبار بدون bookingId'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(tripId: trip.id ?? '', seatNumber: 1, bookingId: ''))),
          ),
          ListTile(
            title: const Text('حجوزاتي (راكب)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen ())),
          ),
          ListTile(
            title: const Text('إدارة الرحلات (سائق)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageTripScreen())),
          ),
          ListTile(
            title: const Text('سجل الرحلات (Trip History)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryScreen())),
          ),
          ListTile(
            title: const Text('بحث عن الرحلات (Trip Search)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripSearchScreen())),
          ),
          // تم تعديل هذا البند ليستخدم صفحة بديلة بسيطة إذا كانت CalendarScreen غير متاحة
          ListTile(
            title: const Text('تقويم الرحلات (عام)'),
            onTap: () {
              // إذا كانت CalendarScreen معرفة في مشروعك وتريد استخدامها، استبدل المحتوى التالي بـ:
              // Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
              // أما إن لم تكن متاحة أو تسبب مشاكل، نعرض شاشة بديلة مؤقتة:
              Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('تقويم الرحلات')),
                body: const Center(child: Text('شاشة التقويم غير متاحة حالياً في Pages Tester')),
              )));
            },
          ),
          ListTile(
            title: const Text('تقويم الراكب'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerCalendarScreen())),
          ),
          ListTile(
            title: const Text('تقويم السائق'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverCalendarScreen())),
          ),
          ListTile(
            title: const Text('التقييمات لمستخدم (User Ratings)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserRatingsScreen(userId: 'driver123'))),
          ),
          ListTile(
            title: const Text('اختيار المركبة (Vehicle Selection)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleSelectionScreen())),
          ),
          ListTile(
            title: const Text('إدارة رحلات السائق (قائمة)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverTripsScreen())),
          ),
          ListTile(
            title: const Text('الملف الشخصي'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          ListTile(
            title: const Text('تعديل الملف الشخصي'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          ListTile(
            title: const Text('تعديل رحلة (مثال)'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditTripScreen(tripId: trip.id ?? ''))),
          ),
          ListTile(
            title: const Text('تصدير الرحلات إلى Excel (TripExporter)'),
            subtitle: const Text('يحفظ ملف في مجلد مؤقت داخل التطبيق'),
            onTap: () async {
              final trips = [trip];
              try {
                await exporter_service.TripExporter.exportToExcel(context, trips);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل التصدير: $e')));
              }
            },
          ),
          ListTile(
            title: const Text('اختبار BookingService.createBooking (محاكاة)'),
            subtitle: const Text('ينفّذ createBooking مع بيانات تجريبية ويعرض نتيجة'),
            onTap: () async {
              final bookingService = Provider.of<BookingService>(context, listen: false);
              final user = 'testPassengerId';
              final tripId = trip.id ?? 'testTrip';
              final result = await bookingService.createBooking(
                tripId: tripId,
                passengerId: user,
                seatsToBook: 1,
                tripPricePerSeat: trip.price ?? 0.0,
                isFamilyBooking: false,
                childrenCount: 0,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result == null ? '✅ createBooking نجح (محاكاة)' : '❌ createBooking فشل: $result')));
            },
          ),
          ListTile(
            title: const Text('اختبار NotificationService.sendNotification (محاكاة)'),
            subtitle: const Text('ينشئ إشعارًا تجريبيًا في مجموعة notifications'),
            onTap: () async {
              try {
                await NotificationService().sendNotification(
                  userId: 'testPassengerId',
                  title: 'اختبار إشعار',
                  body: 'هذه رسالة اختبار من Pages Tester',
                  type: 'test',
                  metadata: {'source': 'PagesTester'},
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال إشعار تجريبي')));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل إرسال الإشعار: $e')));
              }
            },
          ),
          const Divider(),
          // اختبارات خدمات المستخدم والمصادقة
          ListTile(
            title: const Text('اختبار UserService.getUserById'),
            subtitle: const Text('يعرض اسم المستخدم إن وجد'),
            onTap: () async {
              final userService = Provider.of<UserService>(context, listen: false);
              final uid = 'testPassengerId';
              final appUser = await userService.getUserById(uid);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appUser != null ? '✅ وجد المستخدم: ${appUser.nickname ?? appUser.email}' : '❌ لم يتم العثور على مستخدم بالمعرف $uid')));
            },
          ),
          ListTile(
            title: const Text('اختبار Deep Link / QR للدفع'),
            subtitle: const Text('يعرض QR و URI لاختبار تطبيقات التحويل'),
            onTap: () {
              final paymentService = Provider.of<PaymentService>(context, listen: false);
              final bookingId = 'testBooking123';
              final amount = 12000.0;
              final paymentMethod = 'yemenpay';
              final callbackUrl = 'myapp://payment-callback';
              final schemeHost = 'yemenpay://pay';
              Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('اختبار Deep Link / QR')),
                body: SingleChildScrollView(
                  child: PaymentDeepLinkWidget(
                    bookingId: bookingId,
                    amount: amount,
                    paymentMethod: paymentMethod,
                    callbackUrl: callbackUrl,
                    schemeHost: schemeHost,
                    paymentService: paymentService,
                  ),
                ),
              )));
            },
          ),
          ListTile(
            title: const Text('اختبار AuthService.getCurrentUser / signOut'),
            subtitle: const Text('يعرض حالة المستخدم الحالي ثم يقوم بتسجيل الخروج'),
            onTap: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final current = authService.getCurrentUser();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(current != null ? 'مستخدم مسجل: ${current.email}' : 'لا يوجد مستخدم مسجل')));
              // تسجيل الخروج (اختياري)
              try {
                await authService.signOut();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تسجيل الخروج')));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل تسجيل الخروج: $e')));
              }
            },
          ),
          const SizedBox(height: 40), // ضع هنا عناصر الاختبار كما كانت لديك
        ],
      ),
    );
  }
}
