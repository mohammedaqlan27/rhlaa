🏗️ RHLAA Platform Architecture
معمارية منصة رحلاء
📖 مقدمة
تم تصميم منصة رحلاء (RHLAA) كنظام وطني متكامل لإدارة النقل البري والرحلات والحجوزات والمدفوعات والوكالات والرسوم الحكومية.

تم بناء النظام مع التركيز على:

القابلية للتوسع (Scalability)
سهولة الصيانة (Maintainability)
الأمان (Security)
الحوكمة (Governance)
تعدد الأدوار (Multi-Role Platform)
الفصل بين المسؤوليات (Separation of Concerns)
🎯 الأهداف المعمارية
تهدف المعمارية الحالية إلى:

فصل الواجهات عن منطق الأعمال.
توحيد الوصول إلى البيانات.
تنظيم الخدمات.
تسهيل الاختبارات.
دعم التوسع المستقبلي.
بناء منصة تشغيلية متكاملة.
🗺️ High Level Architecture
┌─────────────────────────────────────────────┐
│                RHLAA Platform                │
└─────────────────────────────────────────────┘
│
▼

┌─────────────────────────────────────────────┐
│             Presentation Layer              │
├─────────────────────────────────────────────┤
│                                               │
│ Passenger Screens                             │
│ Driver Screens                                │
│ Agency Screens                                │
│ Admin Screens                                 │
│ Shared Widgets                                │
│                                               │
└─────────────────────────────────────────────┘
│
▼

┌─────────────────────────────────────────────┐
│          State Management Layer             │
├─────────────────────────────────────────────┤
│                                               │
│ AuthProvider                                 │
│ UserProvider                                 │
│ TripProvider                                 │
│ BookingProvider                              │
│ VehicleProvider                              │
│ RatingProvider                               │
│ PaymentProvider                              │
│ AgenciesProvider                             │
│ ThemeProvider                                │
│                                               │
└─────────────────────────────────────────────┘
│
▼

┌─────────────────────────────────────────────┐
│              Services Layer                 │
├─────────────────────────────────────────────┤
│                                               │
│ AuthService                                  │
│ UserService                                  │
│ TripService                                  │
│ BookingService                               │
│ VehicleService                               │
│ RatingService                                │
│ NotificationService                          │
│ PaymentService                               │
│ CommissionService                            │
│ GovFeesService                               │
│ AgenciesService                              │
│ PdfService                                   │
│                                               │
└─────────────────────────────────────────────┘
│
▼

┌─────────────────────────────────────────────┐
│          Firebase Infrastructure            │
├─────────────────────────────────────────────┤
│                                               │
│ Firebase Authentication                      │
│ Cloud Firestore                              │
│ Firebase Storage                             │
│ Firebase Cloud Messaging (FCM)               │
│                                               │
└─────────────────────────────────────────────┘
│
▼

┌─────────────────────────────────────────────┐
│             Data Collections                │
├─────────────────────────────────────────────┤
│                                               │
│ users                                        │
│ vehicles                                     │
│ trips                                        │
│ bookings                                     │
│ payments                                     │
│ ratings                                      │
│ notifications                                │
│ agencies                                     │
│ agency_transactions                          │
│ gov_fees                                     │
│ user_notification_preferences                │
│                                               │
└─────────────────────────────────────────────┘
👥 Platform Roles

                     ┌──────────────┐
                     │    Admin     │
                     └──────┬───────┘
                            │
                            ▼

┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│ Passenger   │◄────►│    RHLAA    │◄────►│   Driver    │
└─────────────┘      │  Platform   │      └─────────────┘
└──────┬──────┘
│
▼

                     ┌──────────────┐
                     │   Agency     │
                     └──────────────┘
                            │
                            ▼

                     ┌──────────────┐
                     │   Security   │
                     └──────────────┘
🏢 الطبقات المعمارية
1. Presentation Layer
   تمثل جميع واجهات المستخدم.

تشمل:

Screens
Widgets
Dialogs
Forms
Dashboards
أمثلة:

AuthScreen
CreateTripScreen
TripDetailsScreen
PaymentScreen
ProfileScreen

Driver Home
Passenger Home
Agency Dashboard
Admin Dashboard
2. State Management Layer
   معتمدة على:

Provider
ChangeNotifier
AuthState
المسؤوليات:

إدارة الحالة.
إدارة البيانات المحلية.
تحديث الواجهات.
تنظيم تدفق البيانات.
3. Services Layer
   تمثل طبقة منطق الأعمال (Business Logic).

AuthService
تسجيل الدخول.
إنشاء الحساب.
إدارة الجلسات.
UserService
إدارة المستخدمين.
رفع الوثائق.
التحقق من الهوية.
VehicleService
إدارة المركبات.
TripService
إدارة الرحلات.
BookingService
إدارة الحجوزات.
إدارة المقاعد.
PaymentService
الدفع.
المحافظ.
التأكيد.
CommissionService
احتساب عمولات التطبيق.
GovFeesService
احتساب الرسوم الحكومية.
AgenciesService
إدارة الوكالات.
معاملات الوكالات.
NotificationService
الإشعارات.
PdfService
Generating Trip Manifest.
Passenger Lists.
Reports.
☁ Firebase Layer
Firebase Authentication
مسؤول عن:

Register
Login
Logout
Authentication
Role Identification
Cloud Firestore
قاعدة البيانات الرئيسية للنظام.

Firebase Storage
تخزين:

Identity Cards
Vehicle Documents
Driver Licenses
PDF Documents
Firebase Cloud Messaging
إدارة:

Push Notifications
Booking Notifications
Payment Notifications
Trip Notifications
🗄️ Data Collections
users
vehicles
trips
bookings
payments
ratings
notifications
agencies
agency_transactions
gov_fees
user_notification_preferences
🔗 Database Relationships

users
│
├──────────────┐
│              │
▼              ▼

vehicles       trips
│              │
│              ▼
│          bookings
│              │
│              ▼
│          payments
│
▼
ratings


agencies
│
├────────────► agency_transactions
│
└────────────► trips


trips
│
├────────────► gov_fees
│
└────────────► notifications

🚍 Core Business Flow

Passenger
│
▼
Search Trips
│
▼
Select Trip
│
▼
Create Booking
│
▼
Reserve Seats
│
▼
Payment Process
│
▼
Commission Calculation
│
▼
Government Fee Calculation
│
▼
Booking Confirmation
│
▼
Notification Dispatch
│
▼
Trip Manifest Generation
│
▼
Trip Execution
│
▼
Rating & Feedback

🚘 Create Trip Flow

Driver
│
▼

CreateTripScreen

│
▼

TripProvider

│
▼

TripService

│
▼

Driver Verification

│
▼

Firestore

🎫 Booking Flow

Passenger

│
▼

TripDetailsScreen

│
▼

BookingService

│
▼

Seat Availability Check

│
▼

Booking Creation

│
▼

Update Trip Seats

│
▼

Notification

💳 Payment Flow

Passenger

│
▼

PaymentScreen

│
▼

PaymentService

│
▼

CommissionService

│
▼

GovFeesService

│
▼

Create Payment Record

│
▼

Confirm Booking

│
▼

Notification

📄 PDF Manifest Flow

Driver

│
▼

PdfService

│
▼

Load Trip

│
▼

Load Passengers

│
▼

Generate PDF

│
▼

Upload To Storage

│
▼

Manifest URL

🔒 Security Architecture
تعتمد المنصة على:

Authentication
Authorization
Role Validation
Ownership Validation
Protected Fields
Payment Restrictions
Driver Verification
Agency Validation
Default Deny Policy
🛡 Governance Model
الأدوار المعتمدة:

Passenger
Driver
Agency
Security
Admin
نموذج الصلاحيات:

Role Based Access Control
(RBAC)
✅ Tested Workflows
تم اختبار:

Authentication Flow

Profile Flow

Vehicle Flow

Trip Flow

Booking Flow

Notification Flow

Payment Flow

Commission Flow

Government Fees Flow

PDF Generation Flow

Security Rules Flow

Firebase Emulator Flow
🚀 Future Architecture Roadmap
الهيكل الحالي:

Provider
│
▼
Services
│
▼
Firestore
الهيكل المستهدف مستقبلاً:

Presentation
│
▼
Providers
│
▼
Use Cases
│
▼
Repositories
│
▼
Services
│
▼
Firebase
📌 الخلاصة
تم تصميم منصة رحلاء كمنصة تشغيلية متكاملة لإدارة النقل البري والرحلات والمدفوعات والتوثيق والوكالات ضمن معمارية قابلة للتوسع تعتمد على Flutter و Firebase، وتستهدف التحول إلى منصة وطنية واسعة النطاق تدعم الجهات التشغيلية والإدارية والأمنية ضمن منظومة رقمية موحدة وآمنة.