// functions/createGovOffice.js
const admin = require('firebase-admin');

// تهيئة تطبيق الفايربيس مخصص للمشروع
if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'rhlaa-app' });
}

// توجيه الاتصال إلى محاكي المصادقة وقواعد البيانات المحلية (Emulators)
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

const db = admin.firestore();

async function createGovOffice() {
  const uid = 'gov_office_1';
  const email = 'gov1@test.local';
  const password = 'password123';

  try {
    // 1. إنشاء حساب المستخدم في Firebase Auth
    await admin.auth().createUser({
      uid: uid,
      email: email,
      password: password,
      displayName: 'مكتب الرقابة والتصاريح الحكومي',
    });
    console.log(`✅ تم إنشاء حساب المستخدم في Auth: ${email}`);

    // 2. إضافة مستند للجهة الحكومية في Firestore لإسناد الصلاحيات (Role)
    await db.collection('users').doc(uid).set({
      uid: uid,
      email: email,
      name: 'مكتب الرقابة والتصاريح الحكومي',
      role: 'government', // الصلاحية الخاصة بالجهة الحكومية
      officeName: 'الجهة الرقابية للرحلات',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ تم تسجيل بيانات المكتب الحكومي وصلاحياته في Firestore');

  } catch (e) {
    if (e.code === 'auth/uid-already-exists' || e.code === 'auth/email-already-in-use') {
      console.log('⚠️ الحساب موجود بالفعل على المحاكي.');
    } else {
      console.error('❌ حدث خطأ أثناء إنشاء حساب المكتب الحكومي:', e.message);
    }
  }
}

createGovOffice();