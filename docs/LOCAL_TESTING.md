🧪 LOCAL TESTING GUIDE
دليل الاختبار المحلي لمنصة رحلاء (RHLAA)
📖 مقدمة
تم إنشاء بيئة اختبار محلية (Local Development Environment) لمنصة رحلاء بهدف:

اختبار النظام دون التأثير على البيانات الحقيقية.
تطوير الميزات الجديدة بأمان.
اختبار قواعد الحماية (Firestore Rules).
اختبار الخدمات (Services).
التحقق من منطق الأعمال (Business Logic).
اختبار الحجوزات والمدفوعات والإشعارات.
تسريع دورة التطوير.
تعتمد المنصة على Firebase Emulator Suite كبيئة اختبار محلية رئيسية.

🎯 أهداف بيئة الاختبار المحلية
توفر بيئة الاختبار إمكانية:

✅ اختبار الرحلات.

✅ اختبار الحجوزات.

✅ اختبار المدفوعات.

✅ اختبار الإشعارات.

✅ اختبار Firestore Rules.

✅ اختبار Authentication.

✅ اختبار صلاحيات المستخدمين.

✅ اختبار العمولات.

✅ اختبار الرسوم الحكومية.

✅ اختبار توليد ملفات PDF.

✅ اختبار الخدمات قبل النشر.

🛠 المتطلبات الأساسية
قبل تشغيل بيئة الاختبار تأكد من وجود:

Flutter
flutter --version
Firebase CLI
firebase --version
Java Runtime
java --version
Firebase Emulator يعتمد على Java.

FlutterFire CLI
flutterfire --version
🏗 بنية الاختبار المحلية
┌─────────────────────────┐
│     Flutter App         │
└───────────┬─────────────┘
│
▼

┌─────────────────────────┐
│ Firebase Emulator Suite │
└───────────┬─────────────┘
│
│
┌──────────┼──────────┐
▼          ▼          ▼

Auth    Firestore   Storage
Emulator Emulator   Emulator

            │
            ▼

     Local Test Data
🔥 Firebase Emulator Suite
تعتمد منصة رحلاء على:

Authentication Emulator
Firestore Emulator
Storage Emulator
Functions Emulator
Hosting Emulator
Pub/Sub Emulator
Cloud Tasks Emulator
📦 تثبيت المحاكيات
تسجيل الدخول:

firebase login
تهيئة المشروع:

firebase init emulators
اختيار الخدمات:

Firestore
Authentication
Storage
Functions
Hosting
PubSub
🚀 تشغيل المحاكيات
تشغيل جميع المحاكيات:

firebase emulators:start
تشغيل خدمة محددة:

firebase emulators:start --only firestore
تشغيل Firestore و Authentication:

firebase emulators:start --only firestore,auth
🌐 منافذ التشغيل الافتراضية
الخدمة	المنفذ
Emulator UI	4002
Firestore	8080
Authentication	9099
Storage	9199
Functions	5002
Hosting	5000
Pub/Sub	8085
🖥 واجهة Emulator UI
بعد تشغيل المحاكيات:

http://127.0.0.1:4002
يمكن من خلالها:

مراقبة البيانات.
إنشاء مستخدمين.
مراجعة قواعد Firestore.
تنفيذ عمليات الاختبار.
🔌 ربط Flutter بالمحاكي
داخل main.dart:

await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform,
);

FirebaseFirestore.instance.useFirestoreEmulator(
'localhost',
8080,
);

await FirebaseAuth.instance.useAuthEmulator(
'localhost',
9099,
);
✅ اختبارات Authentication
تم اختبار:

إنشاء حساب
Register User
تسجيل الدخول
Login User
تسجيل الخروج
Logout User
التحقق من الأدوار
Passenger
Driver
Agency
Admin
Security
✅ اختبارات المستخدمين
تم اختبار:

Create User
Update User
Profile Editing
Document Upload
تم التحقق من:

Identity Cards
Driver Licenses
Vehicle Documents
✅ اختبارات المركبات
تم اختبار:

Add Vehicle
Update Vehicle
Delete Vehicle
Vehicle Ownership
Vehicle Verification
✅ اختبارات الرحلات
تم اختبار:

Create Trip
Update Trip
Trip Status Change
Driver Validation
اختبار:

Internal Trips
External Trips
✅ اختبارات الحجوزات
تم اختبار:

Create Booking
Confirm Booking
Cancel Booking
تم اختبار:

Seat Reservation
Seat Release
Booking Expiration
✅ اختبارات المقاعد
تم اختبار منطق:

seatStatus
القيم:

true  = Available

false = Reserved
تم التحقق من:

Available Seats Count
Automatic Seat Management
✅ اختبارات المدفوعات
تم اختبار:

Sandbox Payments
Wallet Payments
QR Payments
Deep Links
تم اختبار:

Payment Success
Payment Failure
Retry Scenarios
Transaction Verification
✅ اختبارات العمولات
تم اختبار:

Application Commission
Agency Commission
Driver Net Amount
التحقق من:

CommissionService
✅ اختبارات الرسوم الحكومية
تم اختبار:

Distance Based Fees

Route Matching

GovFeesService
التحقق من:

Fee Calculation

Trip Fee Assignment
✅ اختبارات الإشعارات
تم اختبار:

Create Notification

Receive Notification

Mark As Read

Notification Queries
أنواع الإشعارات المختبرة:

Booking Notifications

Payment Notifications

Rating Notifications

General Notifications
✅ اختبارات PDF
تم اختبار:

Generate Manifest

Passenger List

Driver Details

Vehicle Details
تم التحقق من:

Storage Upload

PDF URL Generation

Manifest Storage Path
✅ اختبارات قواعد Firestore
تم اختبار:

Users Rules

Trips Rules

Bookings Rules

Payments Rules

Ratings Rules

Notifications Rules

Agencies Rules
تم التحقق من:

Role Validation

Ownership Validation

Protected Fields

Payment Restrictions
✅ اختبارات صلاحيات المستخدمين
تم اختبار:

Passenger
Allowed Actions

Denied Actions
Driver
Trip Ownership

Vehicle Ownership

Booking Permissions
Agency
Agency Data Access

Agency Transactions
Admin
Full Access Validation
Security
Read Access Validation
✅ اختبارات الخدمات
تم اختبار الخدمات التالية:

AuthService

UserService

TripService

BookingService

VehicleService

PaymentService

NotificationService

RatingService

AgenciesService

GovFeesService

CommissionService

PdfService
⚠️ أبرز المشاكل التي تمت معالجتها
خلال التطوير تم التعامل مع:

Firebase
Authentication Issues

Firestore Rules Issues

Storage Permissions Issues
قاعدة البيانات
Field Naming Conflicts

camelCase

snake_case Compatibility
الحجز
Seat Management

Booking Conflicts

Reservation Conflicts
المدفوعات
Payment Confirmation

Payment State Management

Transaction Tracking
الإشعارات
Notification Delivery

Read Status Management

Notification Ownership
Git & Repository
Merge Conflicts

Branch Management

Repository Maintenance
📊 نتائج الاختبارات
تم التحقق بنجاح من:

Authentication Flow

User Management Flow

Vehicle Flow

Trip Flow

Booking Flow

Payment Flow

Notification Flow

Commission Flow

Government Fee Flow

PDF Generation Flow

Security Rules Flow

Firebase Emulator Flow
🔍 أدوات التحقق المستخدمة
Firebase Emulator Suite

Flutter Debug Mode

Flutter Analyze

Firestore Emulator UI

Firebase Console

GitHub Repository Verification
🚀 أفضل ممارسات الاختبار
قبل كل Push أو Release:

flutter analyze
ثم:

flutter test
ثم:

firebase emulators:start
ثم تنفيذ السيناريوهات الأساسية:

Register

Login

Create Vehicle

Create Trip

Book Trip

Pay

Generate Manifest

Receive Notification
📌 الخلاصة
تعتمد منصة رحلاء على بيئة اختبار محلية متكاملة مبنية على Firebase Emulator Suite، وتم استخدامها لاختبار معظم مكونات النظام التشغيلية والأمنية والمالية قبل النشر، مما ساهم في رفع استقرار النظام وتحسين جودة البرمجيات وتقليل المخاطر التشغيلية أثناء التطوير