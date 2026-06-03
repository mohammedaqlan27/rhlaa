# rhlaa

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
##📘 مشروع rhlaa
مشروع Flutter لإدارة الرحلات والحجوزات بين السائقين والركاب، مع دعم الدفع، التقييمات، والإشعارات.

🗂️ هيكل الملفات
State
lib/state/auth_state.dart  
إدارة حالة المصادقة (تسجيل الدخول/الخروج، التسجيل، جلب دور المستخدم).

Screens
lib/screens/auth_screen.dart — واجهة تسجيل الدخول والتسجيل.

lib/screens/loading_screen.dart — شاشة تحميل عامة.

lib/screens/passenger_home_screen.dart — واجهة رئيسية للراكب.

lib/screens/driver_home_screen.dart — واجهة رئيسية للسائق.

lib/screens/create_trip_screen.dart — إنشاء رحلة جديدة.

lib/screens/available_trips_screen.dart — عرض الرحلات المتاحة مع فلترة.

lib/screens/trip_details_screen.dart — تفاصيل رحلة محددة مع إمكانية الحجز.

lib/screens/my_bookings_screen.dart — عرض وإدارة حجوزات المستخدم.

lib/screens/rating_screen.dart — تقييم السائق بعد إتمام الرحلة.

lib/screens/notification_screen.dart — عرض الإشعارات مع إمكانية وضع كمقروء أو حذف.

lib/screens/payment_screen.dart — تأكيد الدفع للحجز.

lib/screens/driver_bookings_screen.dart — إدارة حجوزات السائق (مع إصلاحات للتعامل مع Timestamp).

Widgets
lib/widgets/trip_card.dart — بطاقة عرض الرحلة (العنوان، الوجهة، المقاعد، السعر، السائق).

Services
lib/services/firebase_service.dart — خدمة عامة للاستماع إلى مجموعات Firestore.

lib/services/booking_service.dart — إدارة الحجوزات (إنشاء، إلغاء، جلب حجوزات السائق/الراكب).

lib/services/payment_service.dart — معالجة الدفع (محاكاة + تحديث حالة الدفع).

lib/services/notification_service.dart — إرسال واستقبال الإشعارات.

lib/services/trip_service.dart — إدارة الرحلات (إنشاء، تعديل، جلب).

lib/services/rating_service.dart — إدارة التقييمات (إضافة، جلب، فرز).

Models
lib/models/trip.dart — نموذج الرحلة.

lib/models/booking_model.dart — نموذج الحجز.

lib/models/app_user.dart — نموذج المستخدم.

lib/models/notification_model.dart — نموذج الإشعار.

lib/models/rating.dart — نموذج التقييم (أُنشئ حديثًا).

lib/models/vehicle.dart — نموذج المركبة (مع إصلاحات للقيم الافتراضية).

Utils
lib/utils/trip_exporter.dart — تصدير الرحلات إلى Excel (مع دعم حفظ الملف في مجلد مؤقت).

Tester
lib/pages_tester.dart — صفحة اختبارية لتجربة جميع الشاشات والخدمات بشكل منفصل.

🛠️ المراحل التي مررنا بها
المرحلة الأولى
إعداد AuthState لإدارة تسجيل الدخول والتسجيل.

بناء واجهة AuthScreen مع دعم السائق/الراكب.

المرحلة الثانية
إنشاء شاشة CreateTripScreen لإنشاء الرحلات مع التحقق من البيانات.

دعم الحقول بصيغ متعددة (camelCase و snake_case).

المرحلة الثالثة
شاشة TripDetailsScreen لعرض تفاصيل الرحلة والحجز.

ربطها بـ BookingService لإنشاء الحجز.

المرحلة الرابعة
إضافة شاشة PaymentScreen لتأكيد الدفع.

إنشاء خدمة PaymentService لمعالجة الدفع وتحديث حالة الحجز.

المرحلة الخامسة
شاشة AvailableTripsScreen لعرض الرحلات المتاحة مع فلترة.

شاشة MyBookingsScreen لإدارة حجوزات المستخدم (إلغاء/تقييم).

شاشة NotificationScreen لعرض الإشعارات.

إصلاحات في BookingService لإرجاع bookingId عند النجاح.

المرحلة السادسة
تحسين TripCard لعرض تفاصيل الرحلة بشكل أنيق وآمن.

دعم النصوص الطويلة، حالة المقاعد، وتنسيق السعر.

المرحلة الأخيرة
إنشاء ملف pages_tester.dart لتجربة جميع الشاشات والخدمات بشكل منفصل.

إضافة ملفات مفقودة (rating.dart, trip_exporter.dart).

إصلاحات في vehicle.dart, driver_bookings_screen.dart, وrating_service.dart.


# 📘 توثيق جلسة العمل الأخيرة
**التاريخ:** 25 مايو 2026  
**الغرض:** إصلاح الأخطاء، إضافة خدمات جديدة، وتجهيز خطة مرحلة البرق.

---

## ✅ ما تم إنجازه
1. **إصلاح مشكلة التشغيل في TripHistoryScreen**
   - أضفنا دالة `fetchTrips` داخل ملف `lib/screens/trip_exporter.dart` لجلب رحلات السائق من Firestore.
   - عدّلنا `TripHistoryScreen` ليستخدم هذه الدالة بشكل صحيح عند تحميل سجل الرحلات.

2. **إضافة خدمات جديدة**
   - **UserService** (`lib/services/user_service.dart`):  
     - إدارة بيانات المستخدم.  
     - رفع الوثائق إلى Firebase Storage وحفظ روابطها في Firestore.  
     - تحديث وحذف الوثائق.  
   - **AuthService** (`lib/services/auth_service.dart`):  
     - تسجيل الدخول والخروج.  
     - إنشاء حساب جديد مع سجل في Firestore.  
     - جلب بيانات المستخدم.  
     - معالجة الأخطاء برسائل عربية واضحة.

3. **تحديث ملف التشغيل `pages_tester.dart`**
   - أضفنا الاستيرادات الجديدة (`UserService`, `AuthService`).  
   - أدرجنا مزودات الخدمات في قائمة الـ `providers`.  
   - أضفنا عناصر اختبار جديدة في قائمة `TestSelector`:  
     - اختبار `UserService.getUserById`.  
     - اختبار `AuthService.getCurrentUser` و`signOut`.

4. **تجهيز خطة مرحلة البرق**
   - وضعنا جدول زمني لأربع أسابيع يتضمن:
     - توحيد النماذج (`trip.dart`, `app_user.dart`).  
     - إصلاح الأخطاء وحالات الحافة.  
     - تحسين الواجهات (UI/UX) وإضافة Theme موحّد.  
     - تفعيل إشعارات Firebase Cloud Messaging.  
     - إضافة Firebase Analytics وCrashlytics.  
     - كتابة اختبارات وحدات وتكامل.  
     - إعداد قواعد Firestore للأمان والخصوصية.

---

## 📂 الملفات التي تم تعديلها
- `lib/screens/trip_exporter.dart` → إضافة دالة `fetchTrips`.
- `lib/screens/trip_history_screen.dart` → استخدام `TripExporter.fetchTrips`.
- `lib/services/user_service.dart` → إدارة بيانات المستخدم والوثائق.
- `lib/services/auth_service.dart` → إدارة المصادقة.
- `lib/pages_tester.dart` → إدراج الخدمات الجديدة + إضافة اختبارات لها.

---

## 🎯 النتيجة
- أصبح التطبيق قادرًا على تشغيل شاشة سجل الرحلات بدون أخطاء.  
- الخدمات الأساسية للمستخدم والمصادقة أصبحت جاهزة ومتصلة بـ Firestore وFirebaseAuth.  
- ملف التشغيل الآن يحتوي على اختبارات عملية لكل خدمة وشاشة.  
- لدينا خطة واضحة للمرحلة التالية (البرق) مع جدول زمني محدد.

---

## 📌 ملاحظات
- جميع التعديلات تمت في إطار **تحسين الاستقرار** وتجهيز المشروع للمرحلة التالية.  
- التركيز القادم سيكون على **تحسين الواجهات** و**إضافة المزايا التفاعلية** (إشعارات، تحليلات).  
- هذا التوثيق محفوظ تحت قسم **Log of Work Sessions** بتاريخ **25 مايو 2026**.


# ملخّص التعديلات (2026-05-26 — 2026-05-27)
**المعدّ:** Mohammed  
**الفترة المغطاة:** 26 مايو 2026 — 27 مايو 2026

## ملخّص سريع
خلال اليومين الماضيين أنجزنا مجموعة تغييرات وظيفية وواجهية واختبارية أساسية: إضافة بيئة دفع تجريبية (sandbox) مع محاكاة webhooks وQR/deep-link، توحيد حقول المستخدم إلى camelCase، إضافة حقول مركبة في الملف الشخصي، منع إنشاء الرحلات قبل اكتمال بيانات السائق، وتحديث الثيم والألوان العامة للتطبيق.

## الملفات المعدّلة والمضافة
- **`lib/services/payment_service.dart`**
  - إضافة `PaymentResult`, `PaymentProviderAdapter`, و`MockProviderAdapter` مع إعدادات `failureRate`, `minDelayMs`, `maxDelayMs`.
  - توحيد دوال الدفع لتُعيد `PaymentResult`، ودوال لبناء payload للـ deep link/QR.
- **`lib/screens/payment_screen.dart`**
  - تعديل لمعالجة `PaymentResult` صراحةً، عرض أخطاء واضحة، والانتقال إلى شاشة التأكيد عند النجاح.
- **`lib/screens/payment_confirmation_screen.dart`**
  - شاشة جديدة لعرض رقم المعاملة، المبلغ، وطريقة الدفع.
- **`lib/widgets/payment_deeplink_widget.dart`**
  - ويدجت لعرض URI وQR لاختبار التكامل مع تطبيقات التحويل (يتطلب `qr_flutter`).
- **`lib/screens/edit_profile_screen.dart`**
  - إضافة حقول المركبة: `carPlateNumber`, `carOwnerOfficialName`, `drivingLicenseNumber`.
  - القراءة تدعم camelCase أولاً ثم snake_case احتياطياً؛ الكتابة تكتب camelCase فقط.
- **`lib/services/user_service.dart`**
  - إضافة `updateUserFields(uid, Map)`؛ تطبيع مفاتيح الخريطة إلى camelCase؛ إزالة القيم الفارغة قبل الكتابة؛ دعم رفع/حفظ المستندات.
- **`lib/models/app_user.dart`**
  - `toMap()` يكتب camelCase فقط؛ `fromDocument()` يقرأ camelCase أولاً ثم snake_case؛ دعم الحقول الجديدة.
- **`lib/screens/create_trip_screen.dart`**
  - منع إنشاء الرحلة ما لم تكتمل بيانات السائق المطلوبة؛ حوار توجيهي للانتقال إلى `EditProfileScreen`; كتابة الرحلة بصيغة camelCase.
- **`lib/pages_tester.dart`**
  - تهيئة `PaymentService.providerAdapter = MockProviderAdapter(...)`؛ إضافة اختبار Deep Link/QR؛ تحديث providers.
- **الثيم والألوان**
  - تحديث الثيم العام (primaryColor, colorScheme, appBarTheme, elevatedButtonTheme, fontFamily).
  - **ألوان رئيسية:** `#6A0DAD` (بنفسجي) — **ثانوي:** `#5DADE2` (أزرق فاتح).

## تعليمات الاختبار السريعة
1. **تثبيت الاعتماديات**
   ```bash
   flutter pub get
