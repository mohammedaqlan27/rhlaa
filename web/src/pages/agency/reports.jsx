// web/src/pages/agency/reports.jsx
import React, { useEffect, useState } from 'react';
import { db, auth } from '../../lib/firebaseClient';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, query, where, onSnapshot } from 'firebase/firestore';

export default function ReportsPage() {
  const [agencyId, setAgencyId] = useState(null);
  const [payments, setPayments] = useState([]);
  const [summary, setSummary] = useState({ total: 0, govFee: 0, agencyCommission: 0, driverNet: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, u => { if (u) setAgencyId(u.uid); else setAgencyId(null); });
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!agencyId) { setPayments([]); setLoading(false); return; }
    setLoading(true);
    const q = query(collection(db, 'payments'), where('agencyId', '==', agencyId));
    const unsub = onSnapshot(q, snap => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setPayments(list);
      const total = list.reduce((s, p) => s + (p.amount || 0), 0);
      const govFee = list.reduce((s, p) => s + (p.split?.govFee || 0), 0);
      const agencyCommission = list.reduce((s, p) => s + (p.split?.agencyCommissionAmount || 0), 0);
      const driverNet = list.reduce((s, p) => s + (p.split?.driverNetAmount || 0), 0);
      setSummary({ total, govFee, agencyCommission, driverNet });
      setLoading(false);
    }, err => { console.error(err); setLoading(false); });
    return () => unsub();
  }, [agencyId]);

  if (loading) return <p>جارٍ تحميل التقارير...</p>;

  return (
    <div style={{ maxWidth: 1000, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>التقارير المالية</h2>
      <div style={{ display: 'flex', gap: 12 }}>
        <div style={{ padding: 12, border: '1px solid #eee' }}>إجمالي المدفوعات: <strong>{summary.total}</strong></div>
        <div style={{ padding: 12, border: '1px solid #eee' }}>الرسوم الحكومية: <strong>{summary.govFee}</strong></div>
        <div style={{ padding: 12, border: '1px solid #eee' }}>عمولة المكتب: <strong>{summary.agencyCommission}</strong></div>
        <div style={{ padding: 12, border: '1px solid #eee' }}>صافي السائقين: <strong>{summary.driverNet}</strong></div>
      </div>

      <h3 style={{ marginTop: 16 }}>سجل المدفوعات</h3>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr style={{ background: '#f7f7f7' }}><th>المعرف</th><th>المبلغ</th><th>الحالة</th><th>التاريخ</th></tr></thead>
        <tbody>
          {payments.map(p => (
            <tr key={p.id}>
              <td>{p.transactionId || p.id}</td>
              <td>{p.amount}</td>
              <td>{p.status}</td>
              <td>{p.createdAt ? (p.createdAt.seconds ? new Date(p.createdAt.seconds*1000).toLocaleString() : new Date(p.createdAt).toLocaleString()) : '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
