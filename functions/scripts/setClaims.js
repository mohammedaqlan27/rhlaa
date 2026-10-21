// functions/setClaims.js
const admin = require('firebase-admin');
const path = require('path');

const USE_EMULATOR = process.env.USE_FIREBASE_EMULATOR === '1';
const KEY_PATH = process.env.SERVICE_ACCOUNT_KEY_PATH || path.join(__dirname, 'serviceAccountKey.json');

if (USE_EMULATOR) {
  admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID || 'rhlaa-app' });
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
  console.log('Admin initialized for Emulator');
} else {
  let serviceAccount;
  try {
    serviceAccount = require(KEY_PATH);
  } catch (err) {
    console.error('Missing service account file. Set SERVICE_ACCOUNT_KEY_PATH or place serviceAccountKey.json in functions/.');
    process.exit(1);
  }
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id || process.env.FIREBASE_PROJECT_ID || 'rhlaa-app'
  });
  console.log('Admin initialized with service account');
}

async function setCustomUserClaims(uid, role) {
  try {
    await admin.auth().setCustomUserClaims(uid, { role });
    console.log(`✅ ${uid} => ${role}`);
  } catch (err) {
    console.error(`❌ Failed for ${uid}:`, err.message || err);
  }
}

// قائمة المستخدمين محدثة بالأدمن والمكتب الحكومي
const list = [
  { uid: 'driver1', role: 'driver' },
  { uid: 'passenger1', role: 'passenger' },
  { uid: 'agency1', role: 'agency' },
  { uid: 'gov1', role: 'government' },
  { uid: 'admin1', role: 'admin' }
];

(async () => {
  for (const e of list) {
    await setCustomUserClaims(e.uid, e.role);
  }
  process.exit(0);
})();