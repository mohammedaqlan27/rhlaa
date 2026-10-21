// functions/createUserForTest.js
const admin = require('firebase-admin');

// تهيئة الـ Admin SDK للـ Emulator
admin.initializeApp({ projectId: 'rhlaa-app' });

// ربط الـ Emulator
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

const db = admin.firestore();

async function create(uid, email, password, role = 'user', name = '') {
  try {
    // 1. إنشاء الحساب في Auth
    await admin.auth().createUser({ uid, email, password, displayName: name });
    console.log('✅ Created Auth:', uid);
  } catch (e) {
    console.warn('⚠️ Maybe exists in Auth:', e.message);
    try {
      await admin.auth().updateUser(uid, { password });
      console.log('🔄 Updated password for', uid);
    } catch (err) {
      console.error(err);
    }
  }

  // 2. إنشاء/تحديث المستند في Firestore لتعيين الصلاحيات (Role)
  try {
    await db.collection('users').doc(uid).set({
      uid: uid,
      email: email,
      name: name || uid,
      role: role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`📋 Updated Firestore document for ${uid} with role: ${role}`);
  } catch (err) {
    console.error(`❌ Error updating Firestore for ${uid}:`, err.message);
  }
}

(async () => {
  // إضافة حساب الأدمن
  await create('admin1', 'admin1@test.local', 'password123', 'admin', 'مدير النظام الرئيسي');

  // الحسابات السابقة
  await create('driver1', 'driver1@test.local', 'password123', 'driver', 'السائق 1');
  await create('passenger1', 'pass1@test.local', 'password123', 'passenger', 'الراكب 1');
  await create('gov1', 'gov1@test.local', 'password123', 'government','مكتب الرقابة والترخيص');
  await create('agency1', 'agency1@test.local', 'password123', 'agency', 'مكتب السفريات / وكالة السفريات');
    process.exit(0);
})();