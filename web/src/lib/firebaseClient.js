// src/firebaseClient.js
import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';

/**
 * تهيئة Firebase من متغيرات البيئة (Next.js أو أي بيئة تستخدم متغيرات NEXT_PUBLIC_)
 * تأكد من ضبط المتغيرات في .env.local أو بيئة الاستضافة.
 */
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || '',
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || '',
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || '',
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || '',
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || '',
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || '',
};

if (!firebaseConfig.projectId) {
  // تحذير مفيد أثناء التطوير إن كانت الإعدادات ناقصة
  console.warn('Firebase config: NEXT_PUBLIC_FIREBASE_PROJECT_ID غير مضبوط. تأكد من متغيرات البيئة.');
}

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app);

/**
 * دعم المحاكيات أثناء التطوير
 * ضع NEXT_PUBLIC_USE_FIREBASE_EMULATOR = 'true' في .env.local لتفعيل المحاكيات
 */
export const useEmulator = process.env.NEXT_PUBLIC_USE_FIREBASE_EMULATOR === 'true';

if (useEmulator) {
  const authHost = process.env.NEXT_PUBLIC_FIREBASE_AUTH_EMULATOR_HOST || 'http://localhost:9099';
  const firestoreHost = process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST || 'localhost';
  const firestorePort = Number(process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_PORT || 8080);
  const functionsHost = process.env.NEXT_PUBLIC_FUNCTIONS_EMULATOR_HOST || 'localhost';
  const functionsPort = Number(process.env.NEXT_PUBLIC_FUNCTIONS_EMULATOR_PORT || 5001);

  connectAuthEmulator(auth, authHost, { disableWarnings: true });
  connectFirestoreEmulator(db, firestoreHost, firestorePort);
  connectFunctionsEmulator(functions, functionsHost, functionsPort);

  console.info('Connected to Firebase emulators:', { authHost, firestoreHost, firestorePort, functionsHost, functionsPort });
}

/**
 * Utility: force refresh ID token for current user
 * استخدم هذا بعد أن تغيّر custom claims (مثل role) لتحديث التوكن فورياً.
 */
export async function refreshIdToken(force = true) {
  const user = auth.currentUser;
  if (!user) return null;
  await user.getIdToken(force);
  return user;
}

/**
 * Utility: استدعاء دالة callable setUserRole من العميل
 * الدالة تفترض أن الدالة السحابية 'setUserRole' موجودة ومحمية بحيث يسمح فقط للأدمن باستدعائها.
 */
export async function callSetUserRole(targetUid, role) {
  if (!targetUid || !role) {
    throw new Error('callSetUserRole: targetUid and role are required');
  }

  const user = auth.currentUser;
  if (!user) {
    throw new Error('callSetUserRole: user not signed in');
  }

  await refreshIdToken(true);

  const fn = httpsCallable(functions, 'setUserRole');
  const res = await fn({ uid: targetUid, role });
  return res.data || res;
}

/**
 * Export الافتراضي (في حال أردت الوصول إلى app)
 */
export default app;
