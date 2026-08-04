// web/src/services/adminService.js
import { getFunctions, httpsCallable } from 'firebase/functions';
import { functions } from '../lib/firebaseClient'; // تأكد من تهيئة functions في firebaseClient

const fns = getFunctions();

/**
 * جلب جميع المستخدمين (للاستخدام في لوحة الأدمن)
 */
export async function getAllUsers() {
  const fn = httpsCallable(fns, 'getAllUsers');
  const res = await fn();
  return res.data.users || [];
}

/**
 * تغيير دور مستخدم محدد
 */
export async function setUserRole(targetUid, role) {
  if (!targetUid || !role) {
    throw new Error('setUserRole: targetUid and role are required');
  }
  const fn = httpsCallable(fns, 'setUserRole');
  const res = await fn({ uid: targetUid, role });
  return res.data;
}

/**
 * تعطيل مستخدم (إيقاف الحساب مؤقتاً)
 */
export async function disableUser(targetUid) {
  if (!targetUid) {
    throw new Error('disableUser: targetUid is required');
  }
  const fn = httpsCallable(fns, 'disableUser');
  const res = await fn({ uid: targetUid });
  return res.data;
}

/**
 * تفعيل مستخدم (إعادة الحساب للعمل)
 */
export async function enableUser(targetUid) {
  if (!targetUid) {
    throw new Error('enableUser: targetUid is required');
  }
  const fn = httpsCallable(fns, 'enableUser');
  const res = await fn({ uid: targetUid });
  return res.data;
}
