import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/rating_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/agencies_provider.dart';
import 'providers/theme_provider.dart';
import 'state/auth_state.dart';
import 'providers/auth_provider.dart';

// Screens
import 'screens/all_screens_launcher.dart'; // تم إضافة ملف استعراض جميع الشاشات هنا
import 'screens/auth_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/home_screen.dart';
import 'screens/available_trips_screen.dart' hide TripProvider;
import 'screens/driver_trips_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/manage_trip_screen.dart';
import 'screens/create_trip_screen.dart';
import 'screens/admin/agencies_list_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trip_search_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/passenger/passenger_calendar_screen.dart';
import 'screens/edit_trip_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/driver/driver_calendar_screen.dart';
import 'screens/driver/driver_bookings_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/trip_details_screen.dart';
import 'screens/user_ratings_screen.dart';
import 'screens/vehicle_selection_screen.dart';
import 'screens/payment_confirmation_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/notification_detail_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/passenger/passenger_home_screen.dart';
import 'screens/agency/agency_home_screen.dart';
import 'screens/admin/agency_form_screen.dart';
import 'screens/admin/agency_detail_screen.dart';
import 'screens/agency/agency_location_edit_screen.dart';
import 'screens/agency/agency_settings_screen.dart';
import 'screens/agency/agency_wallet_screen.dart';
import 'screens/agency/agency_transactions_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/gov_dashboard_screen.dart';
import 'screens/help_center_screen.dart';
import 'screens/privacy_screen.dart';
// Wrapper for passenger home (AppScaffold)
import 'screens/passenger/passenger_home_wrapper.dart';

// Models
import 'models/trip.dart';
import 'models/notification_model.dart';
import 'models/payment.dart';

// Theme & utils
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔧 الاتصال بالمحاكي (Emulator) في بيئة التطوير
  const bool useEmulator = true;

  if (useEmulator) {
    const firestoreHost = '127.0.0.1';
    const firestorePort = 8080;
    const authHost = '127.0.0.1';
    const authPort = 9099;
    const functionsHost = '127.0.0.1';
    const functionsPort = 5002;

    try {
      FirebaseFirestore.instance.useFirestoreEmulator(firestoreHost, firestorePort);
      FirebaseAuth.instance.useAuthEmulator(authHost, authPort);
      FirebaseFunctions.instance.useFunctionsEmulator(functionsHost, functionsPort);
      debugPrint('⚙️ Connected to Firebase emulators');
    } catch (e, st) {
      debugPrint('⚠️ Failed to connect to emulators: $e\n$st');
    }
  }

  final themeProvider = await ThemeProvider.loadFromPrefs();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => RatingProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => AgenciesProvider()),
      ],
      child: const RootApp(),
    ),
  );
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  static _RootAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_RootAppState>()!;

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  Locale _locale = const Locale('ar');

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final seed = themeProvider.seedColor ?? AppColors.primary;

    return MaterialApp(
      title: 'رحلة (RHLLA)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seedColor: seed),
      darkTheme: AppTheme.dark(seedColor: seed),
      themeMode: themeProvider.mode,
      locale: _locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      // تم توجيه التطبيق مباشرة لعرض مشغل جميع الشاشات
      home: const AllScreensLauncher(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/auth': (_) => const AuthScreen(),
        '/createTrip': (_) => const CreateTripScreen(),
        '/driverHome': (_) => const DriverHomeScreen(),
        '/passengerHome': (_) => const PassengerHomeWrapper(),
        '/agencyHome': (_) => const AgencyHomeScreen(),
        '/vehicle': (context) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final userId = auth.currentUserId ?? "";
          return VehicleScreen(driverId: userId);
        },
        '/settings': (_) => const SettingsScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/driverTrips': (_) => const DriverTripsScreen(),
        '/driverBookings': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final tripId = args is String
              ? args
              : (args is Map && args['tripId'] is String ? args['tripId'] as String : '');
          return DriverBookingsScreen(tripId: tripId);
        },
        '/tripSearch': (_) => const TripSearchScreen(),
        '/myBookings': (_) => const MyBookingsScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/driverCalendar': (_) => const DriverCalendarScreen(),
        '/agency_settings': (_) => const AgencySettingsScreen(),
        '/editTrip': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final tripId = args is String
              ? args
              : (args is Map && args['tripId'] is String ? args['tripId'] as String : '');
          return EditTripScreen(tripId: tripId);
        },
        '/editProfile': (_) => const EditProfileScreen(),
        '/rating': (_) => const RatingScreen(),
        '/tripHistory': (_) => const TripHistoryScreen(),
        '/tripDetails': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final trip = args is Trip
              ? args
              : (args is Map && args['trip'] is Trip ? args['trip'] as Trip : null);
          if (trip != null) {
            return TripDetailsScreen(trip: trip);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل الرحلة')),
            body: const Center(child: Text('تفاصيل الرحلة غير متاحة')),
          );
        },
        '/userRatings': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final userId = args is String
              ? args
              : (args is Map && args['userId'] is String ? args['userId'] as String : '');
          return UserRatingsScreen(userId: userId);
        },
        '/vehicleSelection': (_) => const VehicleSelectionScreen(),
        '/paymentConfirmation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final transactionId = args is String
              ? args
              : (args is Map && args['transactionId'] is String
              ? args['transactionId'] as String
              : (args is Map && args['bookingId'] is String ? args['bookingId'] as String : ''));
          return PaymentConfirmationScreen(
            transactionId: transactionId,
            bookingId: '',
            amount: 0,
            paymentMethod: '',
          );
        },
        '/notificationSettings': (_) => const NotificationSettingsScreen(),
        '/notificationDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          try {
            if (args is AppNotification) {
              return NotificationDetailScreen(notification: args, notificationId: args.id);
            } else if (args is Map) {
              final id = args['notificationId'] is String
                  ? args['notificationId'] as String
                  : (args['id'] is String ? args['id'] as String : '');
              final title = args['title'] is String
                  ? args['title'] as String
                  : (args['notification'] is Map && args['notification']['title'] is String
                  ? args['notification']['title'] as String
                  : '');
              final body = args['body'] is String
                  ? args['body'] as String
                  : (args['notification'] is Map && args['notification']['body'] is String
                  ? args['notification']['body'] as String
                  : '');
              final userId = args['userId'] is String ? args['userId'] as String : '';
              final notification = AppNotification(id: id, userId: userId, title: title, body: body);
              return NotificationDetailScreen(notification: notification, notificationId: id);
            }
          } catch (_) {}
          final fallback = AppNotification(id: '', userId: '', title: '', body: '');
          return NotificationDetailScreen(notification: fallback, notificationId: '');
        },
        '/loading': (_) => const LoadingScreen(),
        '/payment': (_) => const PaymentScreen(),
        '/notifications': (_) => const NotificationScreen(),
        '/agenciesList': (_) => const AgenciesListScreen(),
        '/agency_wallet': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
          final id = args?['agencyId'] as String?;
          return AgencyWalletScreen(agencyId: id);
        },
        '/agency_transactions': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
          final id = args?['agencyId'] as String?;
          return AgencyTransactionsScreen(agencyId: id);
        },
        '/adminDashboard': (_) => const AdminDashboardScreen(),
        '/govDashboard': (_) => GovDashboardScreen(),
        '/helpCenter': (_) => const HelpCenterScreen(),
        '/privacy': (_) => const PrivacyScreen(),
      },
    );
  }
}