import 'dart:async';
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
import 'screens/trip_details_view_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/driver_bookings_screen.dart';
import 'screens/driver_trips_screen.dart';
import 'screens/calendar_screen.dart' show CalendarScreen; // استورد فقط CalendarScreen إن كانت موجودة
import 'screens/driver_calendar_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_trip_screen.dart';

// الشاشات الجديدة
import 'screens/manage_trip_screen.dart';
import 'screens/passenger_bookings_screen.dart' show PassengerBookingsScreen;
import 'screens/passenger_calendar_screen.dart' show PassengerCalendarScreen;
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
void main() {
  runApp(MyApp());
}

/// نموذج صفحة اختبارية 1
class PageA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page A')),
      body: const Center(child: Text('Page A works')),
    );
  }
}

/// نموذج صفحة اختبارية 2 (تسبب استثناء أثناء البناء)
class PageB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    throw Exception('Build error in Page B');
  }
}

/// نموذج صفحة اختبارية 3 (تأخير طويل)
class PageC extends StatefulWidget {
  @override
  _PageCState createState() => _PageCState();
}
class _PageCState extends State<PageC> {
  @override
  void initState() {
    super.initState();
    // محاكاة عملية طويلة أو خطأ غير متزامن
    Future.delayed(const Duration(seconds: 5), () {
      // لا نفعل شيئًا؛ هذا يسبب تأخيرًا فقط
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page C')),
      body: const Center(child: Text('Page C loaded (may be slow)')),
    );
  }
}

/// هيكل بيانات صفحة للاختبار
class PageInfo {
  final String name;
  final WidgetBuilder builder;
  PageInfo({required this.name, required this.builder});
}

class MyApp extends StatelessWidget {
  final List<PageInfo> pages = [
    // صفحات اختبارية
    PageInfo(name: 'PageA', builder: (_) => PageA()),
    PageInfo(name: 'PageB', builder: (_) => PageB()),
    PageInfo(name: 'PageC', builder: (_) => PageC()),

    // ✅ شاشاتك الحقيقية
    PageInfo(name: 'AuthScreen', builder: (_) => AuthScreen()),
    PageInfo(name: 'LoadingScreen', builder: (_) => LoadingScreen()),
    PageInfo(name: 'HomeScreen', builder: (_) => HomeScreen()),
    PageInfo(name: 'PassengerHomeScreen', builder: (_) => PassengerHomeScreen()),
    PageInfo(name: 'DriverHomeScreen', builder: (_) => DriverHomeScreen()),
    PageInfo(name: 'CreateTripScreen', builder: (_) => CreateTripScreen()),
    PageInfo(name: 'MyBookingsScreen', builder: (_) => MyBookingsScreen()),
    PageInfo(name: 'RatingScreen', builder: (_) => RatingScreen()),
    PageInfo(name: 'NotificationScreen', builder: (_) => NotificationScreen()),
    PageInfo(name: 'DriverTripsScreen', builder: (_) => DriverTripsScreen()),
    PageInfo(name: 'DriverCalendarScreen', builder: (_) => DriverCalendarScreen()),
    PageInfo(name: 'EditProfileScreen', builder: (_) => EditProfileScreen()),
    PageInfo(name: 'ManageTripScreen', builder: (_) => ManageTripScreen()),
    PageInfo(name: 'PassengerBookingsScreen', builder: (_) => PassengerBookingsScreen()),
    PageInfo(name: 'PassengerCalendarScreen', builder: (_) => PassengerCalendarScreen()),
    PageInfo(name: 'ProfileScreen', builder: (_) => ProfileScreen()),
    PageInfo(name: 'TripHistoryScreen', builder: (_) => TripHistoryScreen()),
    PageInfo(name: 'TripSearchScreen', builder: (_) => TripSearchScreen()),
    PageInfo(name: 'VehicleSelectionScreen', builder: (_) => VehicleSelectionScreen()),
    PageInfo(name: 'AuthWrapper', builder: (_) => AuthWrapper()),
    PageInfo(name: 'VehicleScreen', builder: (_) => VehicleScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pages Tester',
      home: TestRunner(pages: pages),
    );
  }
}


class TestRunner extends StatefulWidget {
  final List<PageInfo> pages;
  const TestRunner({required this.pages});

  @override
  _TestRunnerState createState() => _TestRunnerState();
}

class _TestRunnerState extends State<TestRunner> {
  final Map<String, String> _results = {};
  bool _running = false;
  static const Duration pageTimeout = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pages Tester')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _running ? null : _runAllTests,
              child: Text(_running ? 'Running...' : 'Run tests for all pages'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: widget.pages.map((p) {
                  final status = _results[p.name] ?? 'Not tested';
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(status),
                    trailing: ElevatedButton(
                      onPressed: _running ? null : () => _runSingleTest(p),
                      child: const Text('Test'),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    for (final p in widget.pages) {
      await _runSingleTest(p);
      // فاصل صغير بين الاختبارات
      await Future.delayed(const Duration(milliseconds: 300));
    }
    setState(() => _running = false);
  }

  Future<void> _runSingleTest(PageInfo page) async {
    setState(() {
      _results[page.name] = 'Testing...';
    });

    // حفظ المعالج القديم للأخطاء لاستعادته لاحقًا
    final oldOnError = FlutterError.onError;
    final completer = Completer<void>();
    String? errorMessage;

    // مؤقت لالتقاط الأخطاء المتزامنة وغير المتزامنة
    FlutterError.onError = (FlutterErrorDetails details) {
      errorMessage = details.exceptionAsString();
      if (!completer.isCompleted) completer.complete();
    };

    // أيضًا نلتقط الأخطاء غير المتزامنة في المنطقة (zone)
    final zone = Zone.current;
    late ZoneSpecification zoneSpec;
    zoneSpec = ZoneSpecification(
      handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone, Object error, StackTrace stack) {
        errorMessage = error.toString();
        if (!completer.isCompleted) completer.complete();
      },
    );

    // نفتح الصفحة داخل منطقة جديدة حتى نلتقط الأخطاء غير المتزامنة
    await Zone.current.fork(specification: zoneSpec).run(() async {
      // نضغط على الصفحة (ننتقل إليها) ثم ننتظر إما خطأ أو مهلة
      try {
        // نستخدم push ثم ننتظر لعدد من الثواني لمعرفة إن ظهرت أخطاء
        Navigator.of(context).push(MaterialPageRoute(builder: page.builder));
      } catch (e) {
        errorMessage = e.toString();
        if (!completer.isCompleted) completer.complete();
      }

      // ننتظر إما إشارة خطأ أو انتهاء المهلة
      try {
        await Future.any([
          completer.future,
          Future.delayed(pageTimeout),
        ]);
      } catch (_) {}

      // بعد الانتظار: إذا لم يحدث خطأ نعتبر الصفحة ناجحة
      if (!completer.isCompleted) completer.complete();
    });

    // نحاول إغلاق الصفحة المفتوحة إن كانت لا تزال موجودة
    try {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (_) {}

    // استعادة معالج الأخطاء القديم
    FlutterError.onError = oldOnError;

    // تقرير النتيجة
    if (errorMessage != null) {
      setState(() {
        _results[page.name] = 'Error: $errorMessage';
      });
    } else {
      setState(() {
        _results[page.name] = 'Success';
      });
    }
  }
}
