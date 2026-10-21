🔒 SECURITY & GOVERNANCE
الأمن والحوكمة في منصة رحلاء (RHLAA)
📖 مقدمة
تم تطوير منصة رحلاء (RHLAA) كمنصة تشغيلية متكاملة لإدارة النقل البري والرحلات والمدفوعات والوكالات.

ونظرًا لحساسية البيانات التشغيلية والمالية وبيانات المستخدمين والرحلات، فقد تم تصميم النظام وفق مبادئ الحوكمة والأمن الحديثة لضمان:

سرية البيانات (Confidentiality)
سلامة البيانات (Integrity)
توفر الخدمات (Availability)
إدارة الصلاحيات (Access Control)
التتبع والمساءلة (Accountability)
🎯 أهداف الأمن والحوكمة
تهدف استراتيجية الأمن والحوكمة إلى:

حماية بيانات المستخدمين.
حماية بيانات الرحلات.
منع الوصول غير المصرح به.
إدارة الصلاحيات حسب الدور.
حماية المعاملات المالية.
التحقق من هوية السائقين.
حماية بيانات الوكالات.
ضمان نزاهة البيانات.
🏛 نموذج الحوكمة
تعتمد المنصة على نموذج:

Role Based Access Control
(RBAC)
👥 الأدوار المعتمدة
تنقسم الصلاحيات إلى خمسة أدوار رئيسية:

Passenger
Driver
Agency
Security
Admin
👤 Passenger Permissions
يمكن للراكب:

✅ إنشاء الحساب

✅ تعديل بياناته الشخصية

✅ إنشاء الحجوزات

✅ الدفع

✅ استلام الإشعارات

✅ تقييم الرحلات

ولا يمكنه:

❌ تعديل رحلات الآخرين

❌ تعديل المدفوعات

❌ تعديل بيانات السائقين

❌ تعديل بيانات الوكالات

🚘 Driver Permissions
يمكن للسائق:

✅ إدارة ملفه الشخصي

✅ إدارة مركباته

✅ إنشاء الرحلات

✅ تعديل رحلاته الخاصة

✅ مراجعة الحجوزات المرتبطة به

✅ إنشاء كشوفات الرحلات

ولا يمكنه:

❌ تعديل رحلات سائقين آخرين

❌ تعديل المدفوعات بعد إنشائها

❌ الوصول لبيانات المستخدمين غير المرتبطين برحلاته

🏢 Agency Permissions
يمكن للوكالة:

✅ إدارة الرحلات الخاصة بها

✅ إدارة المركبات التابعة لها

✅ إدارة المحفظة

✅ مراجعة المعاملات

✅ متابعة الحجوزات

ولا يمكنها:

❌ الوصول لإعدادات النظام

❌ إدارة المستخدمين بالكامل

❌ تعديل بيانات الوكالات الأخرى

👮 Security Permissions
يمكن للجهات الأمنية:

✅ قراءة بيانات الرحلات

✅ مراجعة بيانات المسافرين

✅ الاطلاع على كشوفات الرحلات

✅ التحقق من صحة بيانات الرحلة

ولا يمكنها:

❌ تعديل الرحلات

❌ إدارة المدفوعات

❌ تعديل المستخدمين

👨‍💼 Admin Permissions
يمتلك مسؤول النظام:

✅ إدارة كافة المجموعات

✅ إدارة المستخدمين

✅ إدارة الوكالات

✅ إدارة الرحلات

✅ إدارة المدفوعات

✅ إدارة الرسوم

✅ إدارة إعدادات النظام

🔐 Authentication
تعتمد المنصة على:

Firebase Authentication
لتوفير:

تسجيل الدخول.
إنشاء الحسابات.
إدارة الجلسات.
التعرف على المستخدم.
🛡 Authorization
تعتمد المنصة على:

Firestore Security Rules
للتحقق من:

هوية المستخدم.
صلاحيات المستخدم.
ملكية البيانات.
الدور الوظيفي.
✅ Driver Verification
قبل السماح بإنشاء رحلة يجب أن يكون السائق مستوفيًا لمتطلبات التحقق.

الشروط الحالية:

isDriver == true

AND

isIdVerified == true

AND

identityCardUrl != null
✅ Identity Verification
توفر المنصة آلية للتحقق من الهوية باستخدام:

National ID
Passport
Identity Documents
ويتم حفظ الملفات في:

Firebase Storage
بينما تحفظ بيانات المرجعية داخل:

users
🚘 Vehicle Verification
لدعم النزاهة التشغيلية.

تشمل عملية التحقق:

Vehicle Ownership
Plate Number
Driver License
Vehicle Documents
🔒 حماية بيانات المستخدمين
لا يسمح للمستخدم بتعديل الحقول الحساسة التالية:

uid
id
createdAt
walletBalance
إلا من خلال العمليات المصرح بها داخل النظام.

💳 حماية المدفوعات
تم تصميم سجل المدفوعات بحيث:

يمنع تعديل المدفوعات من العميل.
يمنع حذف المدفوعات.
يعتمد على Transaction ID فريد.
يسمح فقط بإنشاء العمليات وفق شروط محددة.
💰 حماية المحافظ المالية
يحظر على المستخدم:

❌ تعديل walletBalance مباشرة

وتتم جميع العمليات المالية عن طريق:

PaymentService
CommissionService
AgenciesService
🧾 حماية المعاملات المالية
كل معاملة تحتوي على:

Transaction Id
Amount
Timestamp
Payment Method
Related Booking
Related User
لضمان إمكانية التتبع والمراجعة.

📄 حماية كشوفات الرحلات
تتضمن كشوفات الرحلات:

Driver Information
Vehicle Information
Passenger List
Trip Details
ويتم تخزينها في:

Firebase Storage
مع حفظ مرجع الملف داخل قاعدة البيانات.

🔔 أمن الإشعارات
الإشعارات مرتبطة بالمستخدم.

لا يمكن الوصول إلى إشعار إلا إذا:

request.auth.uid == notification.userId
🗂 حماية البيانات
تعتمد المنصة على:

Firestore Security Rules
لمنع:

الوصول غير المصرح به.
تعديل بيانات الآخرين.
حذف السجلات المهمة.
التلاعب بالمدفوعات.
🛡 Default Deny Strategy
تتبع المنصة مبدأ:

Default Deny
أي أن:

أي عملية غير مصرح بها
=
مرفوضة افتراضياً
🔍 Data Ownership Validation
تتحقق المنصة دائمًا من ملكية البيانات قبل السماح بالوصول.

أمثلة:

Passenger → Own Bookings

Driver → Own Trips

Agency → Own Records

User → Own Profile
⚖ Principles Applied
تعتمد المنصة على المبادئ التالية:

Least Privilege
منح أقل صلاحية ممكنة لكل مستخدم.

Separation Of Duties
فصل المهام والصلاحيات.

Accountability
إمكانية تتبع العمليات.

Data Integrity
الحفاظ على سلامة البيانات.

Privacy By Design
تصميم المنصة مع مراعاة الخصوصية منذ البداية.

🚨 المخاطر المحتملة
تم تحديد عدد من المخاطر التشغيلية:

وصول غير مصرح به
المعالجة:

Authentication
Authorization
Firestore Rules
التلاعب بالمدفوعات
المعالجة:

Payment Restrictions
Transaction Validation
انتحال الهوية
المعالجة:

Identity Verification
Driver Verification
حذف البيانات الحساسة
المعالجة:

Delete Restrictions
Protected Fields
✅ الضوابط الأمنية الحالية
✔ Firebase Authentication

✔ Firestore Security Rules

✔ Role Based Access Control

✔ Driver Verification

✔ Agency Validation

✔ Identity Verification

✔ Ownership Validation

✔ Protected Fields

✔ Notification Ownership

✔ Payment Restrictions

✔ Wallet Protection

✔ Default Deny Policy
🚀 التحسينات المستقبلية
المخطط لإضافته مستقبلاً:

Firebase App Check

Multi-Factor Authentication (MFA)

Audit Logs

Security Monitoring

Crash Analytics

Security Dashboard

Advanced Fraud Detection

Cloud Functions Enforcement
📌 الخلاصة
تعتمد منصة رحلاء على نموذج حوكمة وأمن قائم على الأدوار والصلاحيات والملكية، مع تطبيق مجموعة من الضوابط الأمنية التي تضمن حماية المستخدمين والرحلات والمدفوعات والمعاملات التشغيلية، وتوفر أساساً قابلاً للتوسع لمنصة نقل وطنية آمنة وموثوقة