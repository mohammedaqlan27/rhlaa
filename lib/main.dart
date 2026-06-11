// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// استخدم ملف الثيم الموحد (AppColors / AppThemeFactory)
import 'theme/app_colors.dart';

// نماذج (قد تُستخدم في بعض الشاشات الاختبارية)
import 'models/trip.dart';
import 'models/booking_model.dart';
import 'models/app_user.dart';
import 'models/notification_model.dart';
import 'models/rating_model.dart';
import 'models/vehicle.dart';

// حالة المصادقة
import 'state/auth_state.dart';

// شاشات رئيسية ومساعدة
import 'screens/auth_wrapper.dart';
import 'screens/auth_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/passenger_home_screen.dart' hide Trip;
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
import 'screens/calendar_screen.dart' show CalendarScreen;
import 'screens/driver_calendar_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_trip_screen.dart';
import 'screens/manage_trip_screen.dart';
import 'screens/passenger_bookings_screen.dart' show PassengerBookingsScreen;
import 'screens/passenger_calendar_screen.dart' show PassengerCalendarScreen;
import 'screens/profile_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/trip_search_screen.dart';
import 'screens/user_ratings_screen.dart';
import 'screens/vehicle_selection_screen.dart';
import 'screens/payment_confirmation_screen.dart';
import 'screens/vehicle_screen.dart';

// خدمات وويدجت مساعدة (يمكن تفعيل Providers لها لاحقًا)
import 'services/booking_service.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/trip_service.dart';
import 'services/rating_service.dart';
import 'services/firebase_service.dart';
import 'services/user_service.dart';
import 'services/auth_service.dart';
import 'utils/trip_exporter.dart' as exporter_service;
import 'utils/app_localizations.dart';
import 'utils/constants.dart' hide AppTheme;
import 'widgets/trip_card.dart';
import 'widgets/payment_deeplink_widget.dart';
import 'widgets/custom_button.dart';
import 'widgets/custom_text_field.dart';
import 'widgets/loading_indicator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // التقاط الأخطاء غير المعالجة لعرضها في الـ console أثناء التطوير
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // في بيئة الإنتاج يمكنك إرسال التفاصيل إلى خدمة تتبع الأخطاء هنا
  };

  runApp(
    MultiProvider(
      providers: [
        // مزود حالة المصادقة متاح في كل التطبيق
        ChangeNotifierProvider<AuthState>(
          create: (_) => AuthState(),
        ),

        // أمثلة على Providers للخدمات (معلّقة/قابلة للتفعيل لاحقًا)
        // Provider<BookingService>(create: (_) => BookingService()),
        // Provider<TripService>(create: (_) => TripService()),
        // Provider<NotificationService>(create: (_) => NotificationService()),
      ],
      child: const MyApp(),
    ),
  );
}

/// MyApp: نقطة الدخول للتطبيق مع ثيم مركزي ودعم RTL واللغات
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // مسارات مساعدة (ملاحظة: لا تتضمن '/' لأننا نستخدم home)
  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/auth': (_) => const AuthScreen(),
      '/home': (_) => const HomeScreen(),
      '/passenger_home': (_) => const PassengerHomeScreen(),
      '/driver_home': (_) => const DriverHomeScreen(),
      '/create_trip': (_) => const CreateTripScreen(),
      '/available_trips': (_) => const AvailableTripsScreen(destination: ''),
      '/trip_details': (_) => TripDetailsScreen(trip: Trip(id: 'mock', title: 'Mock Trip')),
      '/my_bookings': (_) => const MyBookingsScreen(),
      '/notifications': (_) => const NotificationScreen(),
      '/payment_confirmation': (_) => const PaymentConfirmationScreen(
        bookingId: 'mock-booking-id',
        transactionId: 'mock-transaction-id',
        amount: 0.0,
        paymentMethod: 'mock',
      ),
      // أضف مسارات إضافية حسب الحاجة
    };
  }

  @override
  Widget build(BuildContext context) {
    // استخدم Theme مركزي من AppThemeFactory الموجود في theme/app_colors.dart
    return MaterialApp(
      title: 'Rhlaa App',
      debugShowCheckedModeBanner: false,
      theme: AppThemeFactory.light(),
      // دعم اللغات والـ RTL
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate, // إن كان لديك ملف app_localizations
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      // مسارات مساعدة (بدون '/')
      routes: _buildRoutes(),
      // نقطة دخول التطبيق: AuthWrapper يتولى التوجيه حسب حالة المصادقة
      home: const AuthWrapper(),
      // إجبار اتجاه النص إلى RTL للتطبيق العربي
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
