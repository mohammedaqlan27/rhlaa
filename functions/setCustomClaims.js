const admin = require('firebase-admin');
const path = require('path');

const keyPath = path.join(__dirname, 'serviceAccountKey.json');

let serviceAccount;
try {
  serviceAccount = require(keyPath);
} catch (err) {
  console.error('❌ لم أجد ملف serviceAccountKey.json في functions/. ضع ملف المفتاح ثم أعد المحاولة.');
  console.error('المسار المتوقع:', keyPath);
  process.exit(1);
}

// تهيئة Admin SDK باستخدام ملف Service Account
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id || 'rhlaa-app'
});

async function setCustomUserClaims(uid, role) {
  try {
    await admin.auth().setCustomUserClaims(uid, { role });
    console.log(`✅ تم تعيين الدور "${role}" للمستخدم ${uid}`);
  } catch (err) {
    console.error('❌ خطأ أثناء تعيين الدور:', err);
  }
}

// استبدل هذه القيم بالـ UID الحقيقية للمستخدمين في مشروعك
// مثال: setCustomUserClaims('abc123UID', 'admin');
setCustomUserClaims('TxlqFpzQTyZPWrh9c1pJyoa0KtW2', 'admin');
setCustomUserClaims('mtSNPV3wnjWmv19OEz87kyHLLFI2', 'agency');
setCustomUserClaims('H5CjRhPD8ETMi2L2vVukp7fRM662', 'gov');
setCustomUserClaims('V0oOI5tfKrVQ6l5NCQ68wyo8s5k1', 'driver');
setCustomUserClaims('kOk4UYsoCcVsT9QUjeX7G9jLNNo2', 'passenger');
