// web/src/lib/auth.js
import { auth } from './firebaseClient';

/**
 * إرجاع الدور الحالي للمستخدم من الـ custom claims
 * @param {boolean} forceRefresh - إذا true يجبر تجديد التوكن
 * @returns {string|null} الدور أو null إذا لا يوجد مستخدم
 */
export async function getCurrentUserRole(forceRefresh = false) {
  const user = auth.currentUser;
  if (!user) return null;
  const idTokenResult = await user.getIdTokenResult(forceRefresh);
  return idTokenResult.claims?.role || null;
}

/**
 * يجدد الـ ID token ويعيد claims كاملة
 * @returns {IdTokenResult} كائن يحتوي على الـ claims
 */
export async function refreshIdToken() {
  const user = auth.currentUser;
  if (!user) throw new Error('No user');
  return await user.getIdTokenResult(true);
}
