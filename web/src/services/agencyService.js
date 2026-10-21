// web/src/services/agencyService.js
import { getFunctions, httpsCallable } from 'firebase/functions';
import { auth, functions as firebaseFunctions } from '../lib/firebaseClient'; // تأكد من تهيئة auth و functions في firebaseClient

const fns = getFunctions(firebaseFunctions.app || undefined);

/**
 * Helper: الحصول على idToken للمستخدم الحالي
 */
async function getIdToken() {
  const user = auth.currentUser;
  if (!user) throw new Error('Not authenticated');
  return await user.getIdToken(/* forceRefresh */ false);
}

/**
 * -------------------------
 * Callable functions wrappers
 * -------------------------
 * استخدم هذه الدوال إذا نشرت الدوال كـ callable في Cloud Functions
 */
export async function createAgencySafe(payload) {
  const fn = httpsCallable(fns, 'createAgencySafe');
  const res = await fn(payload);
  return res.data;
}

export async function creditAgency(agencyId, amount, reason) {
  const fn = httpsCallable(fns, 'creditAgency');
  const res = await fn({ agencyId, amount, reason });
  return res.data;
}

export async function debitAgency(agencyId, amount, reason) {
  const fn = httpsCallable(fns, 'debitAgency');
  const res = await fn({ agencyId, amount, reason });
  return res.data;
}

/**
 * Callable export (إن وُجدت كـ callable)
 */
export async function exportTransactionsCallable(agencyId, fromTs, toTs) {
  const fn = httpsCallable(fns, 'exportTransactions');
  const res = await fn({ agencyId, fromTs, toTs });
  return res.data;
}

/**
 * Callable getAgencyTransactions (إن وُجدت كـ callable)
 */
export async function getAgencyTransactionsCallable(agencyId, options = {}) {
  const fn = httpsCallable(fns, 'getAgencyTransactions');
  const payload = { agencyId, ...options };
  const res = await fn(payload);
  return res.data.transactions || res.data || [];
}

/**
 * ---------------------------------------
 * HTTP-based functions via Next.js API proxy
 * (موصى به: يسهل التعامل مع CORS والأمان)
 * ---------------------------------------
 * API routes المتوقعة:
 *  - /api/getAgencyTransactions
 *  - /api/exportTransactions
 *
 * هذه الدوال ترسل idToken في الهيدر Authorization: Bearer <idToken>
 */

/**
 * جلب معاملات المكتب عبر الـ proxy (يدعم from/to/limit/pageToken)
 * options: { from, to, limit, pageToken }
 */
export async function getAgencyTransactions(agencyId, options = {}) {
  const params = new URLSearchParams();
  if (options.from) params.append('from', options.from);
  if (options.to) params.append('to', options.to);
  if (options.limit) params.append('limit', String(options.limit));
  if (options.pageToken) params.append('pageToken', options.pageToken);

  const url = `/api/getAgencyTransactions?${params.toString()}`;
  const idToken = await getIdToken();

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || res.statusText || 'Failed to fetch transactions');
  }

  const data = await res.json();
  return data.transactions || data || [];
}

/**
 * تصدير معاملات المكتب عبر الـ proxy
 * options: { from, to }
 * يعيد Blob (CSV) أو كائن JSON إذا أعاد الخادم رابطًا
 */
export async function exportTransactions(agencyId, options = {}) {
  const params = new URLSearchParams();
  if (options.from) params.append('from', options.from);
  if (options.to) params.append('to', options.to);

  const url = `/api/exportTransactions?${params.toString()}`;
  const idToken = await getIdToken();

  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${idToken}`,
    },
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || res.statusText || 'Export failed');
  }

  const contentType = res.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    const json = await res.json();
    return json; // { url: 'https://...' } أو بيانات وصفية
  }

  const blob = await res.blob();
  return blob; // الواجهة تستلم blob وتحولها لملف للتحميل
}

/**
 * Admin helpers (callable)
 */
export async function getAllAgencies() {
  const fn = httpsCallable(fns, 'getAllAgencies');
  const res = await fn();
  return res.data.agencies || [];
}
