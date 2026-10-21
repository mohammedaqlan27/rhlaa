// lib/screens/all_screens_launcher.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/trip_provider.dart';

// النماذج (Models)
import '../models/trip.dart';
import '../models/notification_model.dart';
import '../models/booking_model.dart';
import '../models/gov_fee_rule.dart';
import '../models/agency.dart';
import '../models/agency_transaction.dart';
import '../models/app_user.dart';
import '../models/rating_model.dart';
import '../models/vehicle.dart';

// الشاشات الرئيسية (Screens Root)
import 'auth_wrapper.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'available_trips_screen.dart';
import 'create_trip_screen.dart';
import 'edit_trip_screen.dart';
import 'manage_trip_screen.dart';
import 'driver_trips_screen.dart';
import 'edit_profile_screen.dart';
import 'gov_dashboard_screen.dart';
import 'help_center_screen.dart';
import 'loading_screen.dart';
import 'my_bookings_screen.dart';
import 'notification_detail_screen.dart';
import 'notification_screen.dart';
import 'notification_settings_screen.dart';
import 'onboarding_screen.dart';
import 'payment_confirmation_screen.dart';
import 'payment_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';
import 'rating_screen.dart';
import 'settings_screen.dart';
import 'trip_details_screen.dart';
import 'trip_history_screen.dart';
import 'trip_search_screen.dart';
import 'user_ratings_screen.dart';
import 'vehicle_screen.dart';
import 'vehicle_selection_screen.dart';

// شاشات الإدارة (Admin)
import 'admin/admin_dashboard_screen.dart';
import 'admin/agencies_list_screen.dart';
import 'admin/agency_detail_screen.dart';
import 'admin/agency_form_screen.dart';

// شاشات المكاتب (Agency)
import 'agency/agency_bookings_management_screen.dart';
import 'agency/agency_home_screen.dart';
import 'agency/agency_location_edit_screen.dart';
import 'agency/agency_settings_screen.dart';
import 'agency/agency_transactions_screen.dart';
import 'agency/agency_wallet_screen.dart';

// شاشات السائق (Driver)
import 'driver/driver_bookings_screen.dart';
import 'driver/driver_calendar_screen.dart';
import 'driver/driver_home_screen.dart';

// شاشات الركاب (Passenger)
import 'passenger/passenger_calendar_screen.dart';
import 'passenger/passenger_home_screen.dart';
import 'passenger/passenger_home_wrapper.dart';

/// AllScreensLauncher (محدث وشامل لجميع مسارات المشروع الفرعية)
class AllScreensLauncher extends StatelessWidget {
  const AllScreensLauncher({super.key});

  static const List<String> _screenNames = [
    // الجذرية
    'AuthWrapper',
    'AuthScreen',
    'Onboarding',
    'Home',
    'AvailableTrips',
    'CreateTrip',
    'EditTrip',
    'ManageTrip',
    'DriverTrips',
    'EditProfile',
    'GovDashboard',
    'HelpCenter',
    'Loading',
    'MyBookings',
    'Notification',
    'NotificationDetail',
    'NotificationSettings',
    'Payment',
    'PaymentConfirmation',
    'Privacy',
    'Profile',
    'Rating',
    'Settings',
    'TripDetails',
    'TripHistory',
    'TripSearch',
    'UserRatings',
    'Vehicle',
    'VehicleSelection',
    // Admin
    'AdminDashboard',
    'AgenciesList',
    'AgencyDetail',
    'AgencyForm',
    // Agency
    'AgencyBookingsManagement',
    'AgencyHome',
    'AgencyLocationEdit',
    'AgencySettings',
    'AgencyTransactions',
    'AgencyWallet',
    // Driver
    'DriverBookings',
    'DriverCalendar',
    'DriverHome',
    // Passenger
    'PassengerCalendar',
    'PassengerHome',
    'PassengerHomeWrapper',
    // المعاينات (Previews)
    'BookingPreview',
    'GovFeeRulePreview',
    'AgencyPreview',
    'AgencyTransactionPreview',
    'AppUserPreview',
    'RatingPreview',
    'VehiclePreview',
  ];

  static final Map<String, WidgetBuilder> _customBuilders = {
    // الشاشات الجذرية
    'AuthWrapper': (_) => const AuthWrapper(),
    'AuthScreen': (_) => const AuthScreen(),
    'Onboarding': (_) => const OnboardingScreen(),
    'Home': (_) => const HomeScreen(),
    'AvailableTrips': (_) => const AvailableTripsScreen(destination: '',),
    'CreateTrip': (_) => const CreateTripScreen(),
    'EditTrip': (_) => const EditTripScreen(tripId: 't001'),
    'DriverTrips': (_) => const DriverTripsScreen(),
    'EditProfile': (_) => const EditProfileScreen(),
    'GovDashboard': (_) => GovDashboardScreen(),
    'HelpCenter': (_) => const HelpCenterScreen(),
    'Loading': (_) => const LoadingScreen(),
    'MyBookings': (_) => const MyBookingsScreen(),
    'Notification': (_) => const NotificationScreen(),
    'NotificationDetail': (_) => NotificationDetailScreen(
      notification: AppNotification(id: 'n001', userId: 'u001', title: 'إشعار تجريبي', body: 'محتوى الإشعار'),
      notificationId: 'n001',
    ),
    'NotificationSettings': (_) => const NotificationSettingsScreen(),
    'Payment': (_) => const PaymentScreen(),
    'PaymentConfirmation': (_) => const PaymentConfirmationScreen(
      transactionId: 'tx_123',
      bookingId: 'b001',
      amount: 1000.0,
      paymentMethod: 'cash',
    ),
    'Privacy': (_) => const PrivacyScreen(),
    'Profile': (_) => const ProfileScreen(),
    'Rating': (_) => const RatingScreen(),
    'Settings': (_) => const SettingsScreen(),
    'TripDetails': (_) => TripDetailsScreen(
      trip: Trip(
        id: 't001',
        origin: 'صنعاء',
        destination: 'عدن',
        departureTime: DateTime.now(), // استبدل Timestamp.now() بـ DateTime.now()
        totalSeats: 14,
        availableSeats: 10,
        price: 5000.0,
        driverId: 'd001',
        driverName: 'سائق تجريبي',
        status: 'active',
      ),
    ),
    'TripHistory': (_) => const TripHistoryScreen(),
    'TripSearch': (_) => const TripSearchScreen(),
    'UserRatings': (_) => const UserRatingsScreen(userId: 'u001'),
    'Vehicle': (_) => const VehicleScreen(driverId: 'd001'),
    'VehicleSelection': (_) => const VehicleSelectionScreen(),

    // مسارات Admin
    'AdminDashboard': (_) => const AdminDashboardScreen(),
    'AgenciesList': (_) => const AgenciesListScreen(),
    'AgencyDetail': (_) => const AgencyDetailScreen(agencyId: 'agency001'),
    'AgencyForm': (_) => const AgencyFormScreen(),

    // مسارات Agency
    'AgencyBookingsManagement': (_) => const AgencyBookingsManagementScreen(agencyId: 'agency001'),
    'AgencyHome': (_) => const AgencyHomeScreen(),
    'AgencyLocationEdit': (_) => const AgencyLocationEditScreen(agencyId: '',),
    'AgencySettings': (_) => const AgencySettingsScreen(),
    'AgencyTransactions': (_) => const AgencyTransactionsScreen(agencyId: 'agency001'),
    'AgencyWallet': (_) => const AgencyWalletScreen(agencyId: 'agency001'),

    // مسارات Driver
    'DriverBookings': (_) => const DriverBookingsScreen(tripId: 't001'),
    'DriverCalendar': (_) => const DriverCalendarScreen(),
    'DriverHome': (_) => const DriverHomeScreen(),

    // مسارات Passenger
    'PassengerCalendar': (_) => const PassengerCalendarScreen(),
    'PassengerHome': (_) => const PassengerHomeScreen(),
    'PassengerHomeWrapper': (_) => const PassengerHomeWrapper(),

    // معاينات النماذج (Models Previews)
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
        seatNumber: 5,
        notes: 'ملاحظة',
        createdAt: Timestamp.now(),
      ),
    ),
    'GovFeeRulePreview': (_) => GovFeeRulePreviewScreen(
      rule: GovFeeRule(
        id: 'rule_001',
        origin: '*',
        destination: '*',
        distanceBased: true,
        exact: true, // تمت الإضافة هنا
        distanceTiers: [
          DistanceTier(minKm: 0.0, maxKm: 50.0, amount: 100.0),
        ],
        priority: 10,
        isActive: true,
        createdAt: Timestamp.now(),
      ),
    ),
    'AgencyPreview': (_) => AgencyPreviewScreen(
      agency: Agency(
        id: 'agency001',
        agencyName: 'مكتب تجريبي',
        managerName: 'أحمد',
        location: {'lat': 15.3, 'lng': 44.2},
        mobileNumber: '+967770000000',
        walletBalance: 10000.0,
        isActive: true,
        createdAt: Timestamp.now(),
      ),
    ),
    'AgencyTransactionPreview': (_) => AgencyTransactionPreviewScreen(
      transaction: AgencyTransaction(
        id: 'tx_01',
        agencyId: 'agency001',
        amount: 500.0,
        type: 'credit',
        reason: 'إيداع',
        createdAt: Timestamp.now(),
      ),
    ),
    'AppUserPreview': (_) => AppUserPreviewScreen(
      user: AppUser(
        id: 'u001',
        uid: 'u001',
        name: 'محمد عقلان',
        nickname: 'محمد',
        email: 'test@example.com',
        userType: 'passenger',
        mobileNumber: '+967770000000',
        averageRating: 5.0,
        ratingCount: 10,
        createdAt: Timestamp.now(),
        walletBalance: 500.0,
      ),
    ),
    'RatingPreview': (_) => RatingPreviewScreen(
      rating: Rating(
        id: 'r001',
        tripId: 't001',
        bookingId: 'b001',
        fromUserId: 'u001',
        toUserId: 'd001',
        rating: 'excellent',
        score: 5.0,
        category: 'driver',
        comment: 'ممتاز جداً',
        createdAt: Timestamp.now(),
      ),
    ),
    'VehiclePreview': (_) => VehiclePreviewScreen(
      vehicle: Vehicle(
        id: 'v001',
        plateNumber: '1234',
        ownerId: 'u001',
        driverId: 'd001',
        driverName: 'سائق',
        vehicleType: 'bus',
        makeModelYear: '2020',
        color: 'White',
        maxCapacity: 14,
        isVerified: true,
        sGovernmentRegistered: true,
        createdAt: Timestamp.now(),
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشغل جميع شاشات المشروع'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _screenNames.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final title = _screenNames[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                if (_customBuilders.containsKey(title)) {
                  Navigator.push(context, MaterialPageRoute(builder: _customBuilders[title]!));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

// شاشات المعاينة الداخلية المساعدة للنماذج
class BookingPreviewScreen extends StatelessWidget {
  final Booking booking;
  const BookingPreviewScreen({super.key, required this.booking});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('معاينة الحجز')), body: Center(child: Text('معرف الحجز: ${booking.id}')));
}

class GovFeeRulePreviewScreen extends StatelessWidget {
  final GovFeeRule rule;
  const GovFeeRulePreviewScreen({super.key, required this.rule});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('معاينة رسوم الدولة')), body: Center(child: Text('قاعدة: ${rule.id}')));
}

class AgencyPreviewScreen extends StatelessWidget {
  final Agency agency;
  const AgencyPreviewScreen({super.key, required this.agency});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('معاينة المكتب')), body: Center(child: Text('المكتب: ${agency.agencyName}')));
}

class AgencyTransactionPreviewScreen extends StatelessWidget {
  final AgencyTransaction transaction;
  const AgencyTransactionPreviewScreen({super.key, required this.transaction});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('معاينة المعاملة')), body: Center(child: Text('المبلغ: ${transaction.amount}')));
}

class AppUserPreviewScreen extends StatelessWidget {
  final AppUser user;
  const AppUserPreviewScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('معاينة المستخدم')), body: Center(child: Text('الاسم: ${user.name}')));
}

class RatingPreviewScreen extends StatelessWidget {
  final Rating rating;
  const RatingPreviewScreen({super.key, required this.rating});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('معاينة التقييم')), body: Center(child: Text('التقييم: ${rating.score}')));
}

class VehiclePreviewScreen extends StatelessWidget {
  final Vehicle vehicle;
  const VehiclePreviewScreen({super.key, required this.vehicle});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('معاينة المركبة')), body: Center(child: Text('اللوحة: ${vehicle.plateNumber}')));
}