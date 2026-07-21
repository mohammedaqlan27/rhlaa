rules_version = '2';
service cloud.firestore {
match /databases/{database}/documents {

    // =====================================================================
    // 1. دوال مساعدة (Helper Functions) لتسهيل القراءة وتطبيق الشروط
    // =====================================================================

    // التحقق من تسجيل الدخول
    function isAuthenticated() {
      return request.auth != null;
    }

    // جلب بيانات المستخدم الحالي
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }

    // جلب بيانات رحلة معينة (تُستخدم للتحقق من صلاحيات السائق/المكتب على الحجز)
    function getTripData(tripId) {
      return get(/databases/$(database)/documents/trips/$(tripId)).data;
    }

    // التحقق من الأدوار (Roles)
    function isAdmin() { return isAuthenticated() && getUserData().userType == 'admin'; }
    function isSecurity() { return isAuthenticated() && getUserData().userType == 'security'; }
    function isDriver() { return isAuthenticated() && (getUserData().isDriver == true || getUserData().userType == 'driver'); }
    function isPassenger() { return isAuthenticated() && getUserData().userType == 'passenger'; }
    function isAgency() { return isAuthenticated() && getUserData().userType == 'agency'; }

    // التحقق من توثيق السائق والمكتب
    function isVerifiedDriver() { return isDriver() && getUserData().isIdVerified == true && getUserData().identityCardUrl != null; }

    // التحقق من عدم تعديل الحقول الأساسية
    function protectedFieldsUnchanged() {
      return !request.resource.data.diff(resource.data).affectedKeys().hasAny(['uid', 'id', 'createdAt']);
    }

    // السماح للأدمن بالوصول الكامل لكل شيء في قاعدة البيانات
    match /{document=**} {
      allow read, write: if isAdmin();
    }

    // =====================================================================
    // 2. مجموعة المستخدمين (users)
    // =====================================================================
    match /users/{userId} {
      // القراءة: المستخدم لنفسه، والأمن
      // ملاحظة: السائق والمكتب يقرؤون بيانات الراكب من خلال الحجوزات أو واجهة التطبيق
      allow read: if request.auth.uid == userId || isSecurity();

      // الإنشاء: يجب أن يتطابق الـ uid مع المستند
      allow create: if request.auth.uid == userId;

      // التحديث: حماية الحقول الأساسية، وضمان أن المحفظة رقم
      allow update: if request.auth.uid == userId
                    && protectedFieldsUnchanged()
                    && (request.resource.data.walletBalance is number);
    }

    // =====================================================================
    // 3. مجموعة الرحلات (trips)
    // =====================================================================
    match /trips/{tripId} {
      // القراءة: متاح للجميع (المسجلين) لرؤية الرحلات المتاحة، وللجهات الأمنية
      allow read: if isAuthenticated();

      // الإنشاء: للسائق الموثق أو المكتب فقط
      allow create: if isVerifiedDriver() || isAgency();

      // التحديث: للسائق/المكتب المالك للرحلة.
      // *استثناء هام لمعاملات الحجز (Transactions)*: يُسمح للراكب بتحديث المقاعد المتاحة وحالة المقاعد فقط عند الحجز
      allow update: if (request.auth.uid == resource.data.driverId) ||
                       (request.auth.uid == resource.data.agencyId) ||
                       (isPassenger() && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['availableSeats', 'seatStatus', 'updatedAt']));
    }

    // =====================================================================
    // 4. مجموعة الحجوزات (bookings)
    // =====================================================================
    match /bookings/{bookingId} {
      // القراءة: الراكب لنفسه، السائق للرحلة، المكتب للرحلة، والجهات الأمنية
      allow read: if request.auth.uid == resource.data.passengerId ||
                     request.auth.uid == getTripData(resource.data.tripId).driverId ||
                     request.auth.uid == getTripData(resource.data.tripId).agencyId ||
                     isSecurity();

      // الإنشاء: الراكب فقط، ويجب أن يمتلك صورة هوية في حسابه
      allow create: if isPassenger()
                    && request.resource.data.passengerId == request.auth.uid
                    && getUserData().identityCardUrl != null; // شرط وجود الهوية للراكب

      // التحديث: لدعم المعاملات (تغيير حالة الحجز)
      allow update: if request.auth.uid == resource.data.passengerId ||
                       request.auth.uid == getTripData(resource.data.tripId).driverId;
    }

    // =====================================================================
    // 5. مجموعة المركبات (vehicles)
    // =====================================================================
    match /vehicles/{vehicleId} {
      allow read: if isAuthenticated();
      allow create, update: if (isDriver() || isAgency())
                            // منع كتابة أنواع خاطئة لسعة المركبة
                            && request.resource.data.maxCapacity is number;
    }

    // =====================================================================
    // 6. مجموعة المدفوعات (payments) والمعاملات المالية (agency_transactions)
    // =====================================================================
    match /payments/{paymentId} {
      // القراءة: الأطراف المعنية فقط
      allow read: if request.auth.uid == resource.data.driverId ||
                     request.auth.uid == resource.data.agencyId ||
                     request.auth.uid == resource.data.passengerId;
                     // ملاحظة: تم استبعاد الأمن من قراءة المدفوعات بناءً على طلبك

      // الإنشاء/التحديث: التحقق من أنواع البيانات والأرقام الموجبة
      allow write: if isAuthenticated()
                   && (request.resource.data.amount is number && request.resource.data.amount >= 0)
                   && (request.resource.data.split.totalAmount is number)
                   && (request.resource.data.transactionId is string && request.resource.data.transactionId != "");
    }

    match /agency_transactions/{transactionId} {
      allow read: if request.auth.uid == resource.data.agencyId;
      allow write: if false; // يُفضل أن تتم المعاملات المالية عبر Cloud Functions فقط
    }

    // =====================================================================
    // 7. مجموعة الرسوم الحكومية (gov_fees)
    // =====================================================================
    match /gov_fees/{feeId} {
      allow read: if isAuthenticated();
      // الأدمن فقط يكتب، مع حماية أنواع البيانات
      allow write: if isAdmin()
                   && (request.resource.data.amount is number && request.resource.data.amount >= 0)
                   && (request.resource.data.fixedAmount is number && request.resource.data.fixedAmount >= 0);
    }

    // =====================================================================
    // 8. الإشعارات (notifications) والتقييمات (ratings)
    // =====================================================================
    match /notifications/{notifId} {
      allow read, update: if request.auth.uid == resource.data.userId;
      allow create: if isAuthenticated();
    }

    match /ratings/{ratingId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.auth.uid == request.resource.data.fromUserId;
    }
}
}