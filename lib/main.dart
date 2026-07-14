// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/rating_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/agencies_provider.dart';
import 'state/auth_state.dart';

// Screens
import 'screens/auth_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/available_trips_screen.dart' hide TripProvider;
import 'screens/create_trip_screen.dart';
import 'screens/driver_bookings_screen.dart';
import 'screens/driver_calendar_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/driver_trips_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_trip_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/manage_trip_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/passenger_calendar_screen.dart';
import 'screens/passenger_home_screen.dart';
import 'screens/payment_confirmation_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/trip_details_screen.dart';
import 'screens/trip_exporter.dart';
import 'screens/trip_history_screen.dart';
import 'screens/trip_search_screen.dart';
import 'screens/user_ratings_screen.dart';
import 'screens/vehicle_screen.dart';
import 'screens/vehicle_selection_screen.dart';

// Agencies screens
import 'screens/agencies_list_screen.dart';
import 'screens/agency_form_screen.dart';
import 'screens/agency_detail_screen.dart';
import 'screens/agency_location_edit_screen.dart';

import 'models/trip.dart';
import 'utils/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => RatingProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => AgenciesProvider()), // Added AgenciesProvider
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        initialRoute: '/',
        routes: {
          '/': (context) => const TestMenuScreen(),
          '/agencies': (context) => const AgenciesListScreen(),
          '/agency_form': (context) => const AgencyFormScreen(),
          '/agency_detail': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            if (args is String) {
              return AgencyDetailScreen(agencyId: args);
            }
            return const AgenciesListScreen();
          },
          '/agency_edit_location': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            if (args is String) {
              return AgencyLocationEditScreen(agencyId: args);
            }
            return const AgenciesListScreen();
          },
        },
      ),
    );
  }
}

class TestMenuScreen extends StatelessWidget {
  const TestMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // بيانات تجريبية للرحلة
    final sampleTrip = Trip(
      id: 'trip123',
      title: 'رحلة تجريبية إلى صنعاء',
      seatStatus: [true, false, true, true],
      totalSeats: 4,
      availableSeats: 2,
      departureTime: DateTime.now().add(const Duration(days: 1)),
      driverId: 'driver001',
    );

    final Map<String, Widget> screens = {
      'AuthWrapper': const AuthWrapper(),
      'AuthScreen': const AuthScreen(),
      'AvailableTrips': const AvailableTripsScreen(destination: 'تعز'),
      'CreateTrip': const CreateTripScreen(),
      'DriverBookings': DriverBookingsScreen(tripId: 'trip123'),
      'DriverCalendar': const DriverCalendarScreen(),
      'DriverHome': const DriverHomeScreen(),
      'DriverTrips': const DriverTripsScreen(),
      'EditProfile': const EditProfileScreen(),
      'EditTrip': EditTripScreen(tripId: 'trip123'),
      'Home': const HomeScreen(),
      'Loading': const LoadingScreen(),
      'ManageTrip': ManageTripScreen(trip: sampleTrip),
      'MyBookings': const MyBookingsScreen(),
      'Notification': const NotificationScreen(),
      'PassengerCalendar': const PassengerCalendarScreen(),
      'PassengerHome': const PassengerHomeScreen(),
      'PaymentConfirmation': const PaymentConfirmationScreen(bookingId: '', transactionId: '', amount: 0, paymentMethod: ''),
      'Payment': const PaymentScreen(amount: "", bookingId: 'booking001', tripId: '', seatNumber: 1),
      'Profile': const ProfileScreen(),
      'Rating': const RatingScreen(),
      'TripDetails': TripDetailsScreen(trip: sampleTrip),
      'TripExporter': const TripExporterScreen(),
      'TripHistory': const TripHistoryScreen(),
      'TripSearch': const TripSearchScreen(),
      'UserRatings': const UserRatingsScreen(userId: 'user001'),
      'Vehicle': const VehicleScreen(),
      'VehicleSelection': const VehicleSelectionScreen(),
      // Agencies screens
      'AgenciesList': const AgenciesListScreen(),
      'AgencyForm': const AgencyFormScreen(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الاختبار')),
      body: ListView(
        children: screens.entries.map((entry) {
          return ListTile(
            title: Text(entry.key, style: const TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => entry.value),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
