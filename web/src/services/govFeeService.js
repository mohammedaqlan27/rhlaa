// web/src/services/govService.js
import { getFunctions, httpsCallable } from 'firebase/functions';
import { functions } from '../lib/firebaseClient'; // تأكد من تهيئة functions في firebaseClient

const fns = getFunctions();

/**
 * جلب تقارير الحكومة
 * هذه الدالة تستدعي Cloud Function باسم 'getGovReports'
 * يجب أن تكون الدالة السحابية موجودة ومهيأة في مشروع Firebase Functions
 */
export async function getGovReports() {
  const fn = httpsCallable(fns, 'getGovReports');
  const res = await fn();
  return res.data.reports || [];
}
