// web/src/services/agencyService.js
import { getFunctions, httpsCallable } from 'firebase/functions';
import { functions } from '../lib/firebaseClient'; // تأكد من تهيئة functions في firebaseClient

const fns = getFunctions();

/**
 * إنشاء مكتب جديد بشكل آمن
 */
export async function createAgencySafe(payload) {
  const fn = httpsCallable(fns, 'createAgencySafe');
  const res = await fn(payload);
  return res.data;
}

/**
 * شحن رصيد المكتب
 */
export async function creditAgency(agencyId, amount, reason) {
  const fn = httpsCallable(fns, 'creditAgency');
  const res = await fn({ agencyId, amount, reason });
  return res.data;
}

/**
 * خصم رصيد المكتب
 */
export async function debitAgency(agencyId, amount, reason) {
  const fn = httpsCallable(fns, 'debitAgency');
  const res = await fn({ agencyId, amount, reason });
  return res.data;
}

/**
 * تصدير معاملات المكتب (CSV أو رابط)
 */
export async function exportTransactions(agencyId, fromTs, toTs) {
  const fn = httpsCallable(fns, 'exportTransactions');
  const res = await fn({ agencyId, fromTs, toTs });
  return res.data;
}

/**
 * جلب معاملات المكتب
 */
export async function getAgencyTransactions(agencyId) {
  const fn = httpsCallable(fns, 'getAgencyTransactions');
  const res = await fn({ agencyId });
  return res.data.transactions || [];
}

/**
 * جلب جميع المكاتب (للاستخدام في لوحة الأدمن)
 */
export async function getAllAgencies() {
  const fn = httpsCallable(fns, 'getAllAgencies');
  const res = await fn();
  return res.data.agencies || [];
}
