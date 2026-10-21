// web/src/pages/agency/dashboard.jsx
import React, { useEffect, useState, useMemo } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { auth, db } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { getCurrentUserRole, refreshIdToken } from '../../lib/auth';
import { creditAgency, getAgencyTransactions } from '../../services/agencyService';
import { collection, query, where, onSnapshot } from 'firebase/firestore';
import '../../styles/agency.module.css';
import Button from '../components/Button.txs';

/**
 * Dashboard مع زر تصدير CSV مباشر
 * ملاحظة: تم تحديث كل استخدامات <Link> لتتوافق مع API الجديد في Next.js
 */

const escapeCsvValue = (val) => {
  if (val === null || val === undefined) return '';
  const s = String(val);
  if (s.includes('"')) return `"${s.replace(/"/g, '""')}"`;
  if (s.includes(',') || s.includes('\n') || s.includes('\r')) return `"${s}"`;
  return s;
};

const formatDateShort = (d) => {
  if (!d) return '—';
  const date = (typeof d === 'string' || d instanceof String) ? new Date(d) : (d.seconds ? new Date(d.seconds * 1000) : new Date(d));
  return new Intl.DateTimeFormat('ar-EG', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
};

export default function Dashboard() {
  const router = useRouter();
  const [user, setUser] = useState(null);
  const [role, setRole] = useState(null);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  const [counts, setCounts] = useState({
    trips: 0,
    vehicles: 0,
    bookings: 0,
    transactions: 0,
    revenue: 0,
  });

  const [exportFrom, setExportFrom] = useState('');
  const [exportTo, setExportTo] = useState('');
  const [exportLoading, setExportLoading] = useState(false);

  useEffect(() => {
    const unsubAuth = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (!u) {
        router.push('/login');
        return;
      }
      try {
        const r = await getCurrentUserRole(false);
        setRole(r);
        if (r !== 'agency') {
          router.push('/');
          return;
        }
      } catch (err) {
        console.error('خطأ في جلب الدور:', err);
      } finally {
        setLoading(false);
      }
    });
    return () => unsubAuth();
  }, [router]);

  useEffect(() => {
    if (!user) return;
    const agencyId = user.uid;

    const qTrips = query(collection(db, 'trips'), where('agencyId', '==', agencyId));
    const unsubTrips = onSnapshot(qTrips, (snap) => setCounts(prev => ({ ...prev, trips: snap.size })), (err) => console.error(err));

    const qVehicles = query(collection(db, 'vehicles'), where('agencyId', '==', agencyId));
    const unsubVehicles = onSnapshot(qVehicles, (snap) => setCounts(prev => ({ ...prev, vehicles: snap.size })), (err) => console.error(err));

    const qBookings = query(collection(db, 'bookings'), where('agencyId', '==', agencyId));
    const unsubBookings = onSnapshot(qBookings, (snap) => {
      const paid = snap.docs.reduce((acc, d) => acc + (Number(d.data().amountPaid) || 0), 0);
      setCounts(prev => ({ ...prev, bookings: snap.size, revenue: paid }));
    }, (err) => console.error(err));

    const qTx = query(collection(db, 'agency_transactions'), where('agencyId', '==', agencyId));
    const unsubTx = onSnapshot(qTx, (snap) => setCounts(prev => ({ ...prev, transactions: snap.size })), (err) => console.error(err));

    return () => {
      unsubTrips(); unsubVehicles(); unsubBookings(); unsubTx();
    };
  }, [user]);

  const handleRefreshToken = async () => {
    try {
      setMsg('جاري تجديد التوكن...');
      const tokenRes = await refreshIdToken();
      setRole(tokenRes.claims?.role || role);
      setMsg('تم تجديد التوكن');
    } catch (e) {
      console.error(e);
      setMsg('خطأ في تجديد التوكن: ' + (e.message || e.code));
    }
  };

  const handleCredit = async () => {
    try {
      setMsg('جاري شحن المحفظة...');
      const agencyId = user?.uid;
      const res = await creditAgency(agencyId, 100, 'Manual credit from dashboard');
      setMsg('تم الشحن. TX: ' + (res?.transaction?.id || '—'));
    } catch (e) {
      console.error(e);
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  const logout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  const handleExportCsv = async () => {
    if (!user) {
      setMsg('غير مسموح: يجب تسجيل الدخول');
      return;
    }
    setExportLoading(true);
    setMsg('');
    try {
      const payload = {};
      if (exportFrom) payload.from = new Date(exportFrom).toISOString();
      if (exportTo) {
        const toDateObj = new Date(exportTo);
        toDateObj.setHours(23, 59, 59, 999);
        payload.to = toDateObj.toISOString();
      }

      const txs = await getAgencyTransactions(user.uid, payload);

      if (!Array.isArray(txs) || txs.length === 0) {
        setMsg('لا توجد معاملات للتصدير ضمن النطاق المحدد');
        setExportLoading(false);
        return;
      }

      const header = ['ID', 'Amount', 'Description', 'Date', 'Type', 'TransactionId'];
      const rows = txs.map(tx => [
        escapeCsvValue(tx.id || tx.transactionId || ''),
        escapeCsvValue(tx.amount ?? ''),
        escapeCsvValue(tx.description ?? ''),
        escapeCsvValue(tx.date ? (tx.date.seconds ? new Date(tx.date.seconds * 1000).toISOString() : new Date(tx.date).toISOString()) : ''),
        escapeCsvValue(tx.type ?? ''),
        escapeCsvValue(tx.transactionId ?? ''),
      ]);
      const csvContent = [header, ...rows].map(r => r.join(',')).join('\n');
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const ts = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `transactions_${user.uid}_${ts}.csv`;
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', filename);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      setMsg(`✅ تم تصدير ${txs.length} معاملة`);
    } catch (err) {
      console.error('export CSV error', err);
      setMsg('خطأ أثناء التصدير: ' + (err.message || 'غير معروف'));
    } finally {
      setExportLoading(false);
    }
  };

  const exportRangeLabel = useMemo(() => {
    if (!exportFrom && !exportTo) return 'كل الفترات';
    if (exportFrom && !exportTo) return `من ${exportFrom}`;
    if (!exportFrom && exportTo) return `حتى ${exportTo}`;
    return `${exportFrom} → ${exportTo}`;
  }, [exportFrom, exportTo]);

  if (loading) return <p>جارٍ التحميل...</p>;

  return (
    <div style={{ maxWidth: 1200, margin: '24px auto', fontFamily: 'Cairo', display: 'flex', gap: 24 }}>
      <aside style={{ width: 300, border: '1px solid #e0e0e0', padding: 16, borderRadius: 8 }}>
        <h3 style={{ marginTop: 0 }}>لوحة المكتب</h3>
        <p style={{ fontSize: 14 }}>المستخدم: <strong>{user?.email}</strong></p>
        <p style={{ fontSize: 14 }}>الدور: <strong>{role || 'غير محدد'}</strong></p>

        <nav style={{ marginTop: 12 }}>
          <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/trips">📌 إدارة الرحلات</Link>
            </li>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/vehicles">🚗 إدارة المركبات</Link>
            </li>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/drivers">👨‍✈️ إدارة السائقين</Link>
            </li>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/bookings">📑 الحجوزات</Link>
            </li>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/reports">💰 التقارير المالية</Link>
            </li>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/transactions">💳 المعاملات</Link>
            </li>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/staff">👥 إدارة الموظفين</Link>
            </li>
            <li style={{ marginBottom: 8 }}>
              <Link href="/agency/settings">⚙️ إعدادات المكتب</Link>
            </li>
          </ul>
        </nav>

        <div style={{ marginTop: 16 }}>
          <button onClick={handleRefreshToken} style={{ marginBottom: 8, width: '100%' }}>تجديد التوكن</button>
          <button onClick={handleCredit} style={{ marginBottom: 8, width: '100%' }}>شحن 100</button>
          <button onClick={logout} style={{ width: '100%' }}>تسجيل خروج</button>
        </div>

        {msg && <div style={{ marginTop: 12, color: '#444' }}>{msg}</div>}
      </aside>

      <main style={{ flex: 1 }}>
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2 style={{ margin: 0 }}>ملخص سريع للمكتب</h2>
          <div style={{ fontSize: 14, color: '#666' }}>معرف المكتب: <strong>{user?.uid}</strong></div>
        </header>

        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginTop: 16 }}>
          <div style={{ padding: 12, border: '1px solid #e0e0e0', borderRadius: 8 }}>
            <h4 style={{ margin: '0 0 8px 0' }}>الرحلات</h4>
            <div style={{ fontSize: 22, fontWeight: 'bold' }}>{counts.trips}</div>
            <div style={{ marginTop: 8 }}>
              <Link href="/agency/trips">عرض الرحلات</Link>
            </div>
          </div>

          <div style={{ padding: 12, border: '1px solid #e0e0e0', borderRadius: 8 }}>
            <h4 style={{ margin: '0 0 8px 0' }}>المركبات</h4>
            <div style={{ fontSize: 22, fontWeight: 'bold' }}>{counts.vehicles}</div>
            <div style={{ marginTop: 8 }}>
              <Link href="/agency/vehicles">عرض المركبات</Link>
            </div>
          </div>

          <div style={{ padding: 12, border: '1px solid #e0e0e0', borderRadius: 8 }}>
            <h4 style={{ margin: '0 0 8px 0' }}>الحجوزات</h4>
            <div style={{ fontSize: 22, fontWeight: 'bold' }}>{counts.bookings}</div>
            <div style={{ marginTop: 8 }}>إيرادات: <strong>{counts.revenue?.toLocaleString ? counts.revenue.toLocaleString() : counts.revenue}</strong></div>
            <div style={{ marginTop: 8 }}>
              <Link href="/agency/bookings">عرض الحجوزات</Link>
            </div>
          </div>

          <div style={{ padding: 12, border: '1px solid #e0e0e0', borderRadius: 8 }}>
            <h4 style={{ margin: '0 0 8px 0' }}>المعاملات</h4>
            <div style={{ fontSize: 22, fontWeight: 'bold' }}>{counts.transactions}</div>
            <div style={{ marginTop: 8 }}>
              <Link href="/agency/transactions" className="btn" style={{ display: 'inline-block', padding: '6px 10px', border: '1px solid #ddd', borderRadius: 6 }}>
                عرض المعاملات
              </Link>
            </div>
          </div>
        </section>

        <section style={{ marginTop: 20 }}>
          <h3>تصدير معاملات المكتب (CSV)</h3>

          <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
            <label style={{ display: 'flex', flexDirection: 'column' }}>
              <strong>من</strong>
              <input type="date" value={exportFrom} onChange={e => setExportFrom(e.target.value)} />
            </label>

            <label style={{ display: 'flex', flexDirection: 'column' }}>
              <strong>إلى</strong>
              <input type="date" value={exportTo} onChange={e => setExportTo(e.target.value)} />
            </label>

            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <button onClick={handleExportCsv} disabled={exportLoading} style={{ padding: '8px 12px' }}>
                {exportLoading ? 'جارٍ التصدير...' : 'تصدير CSV'}
              </button>

              <button onClick={() => { setExportFrom(''); setExportTo(''); setMsg(''); }} style={{ padding: '8px 12px' }}>
                مسح الفلاتر
              </button>
            </div>

            <div style={{ marginLeft: 'auto', color: '#555' }}>
              <small>نطاق التصدير: <strong>{exportRangeLabel}</strong></small>
            </div>
          </div>

          <div style={{ marginTop: 12, color: '#666' }}>
            <small>ملاحظة: التصدير يتم عبر استدعاء آمن للخادم الذي يتحقق من صلاحية الوصول للمكتب.</small>
          </div>
        </section>

        <section style={{ marginTop: 24 }}>
          <h3>إجراءات سريعة</h3>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <Link href="/agency/trips" style={{ padding: '8px 12px', border: '1px solid #ddd', borderRadius: 6 }}>➕ إضافة رحلة</Link>
            <Link href="/agency/vehicles" style={{ padding: '8px 12px', border: '1px solid #ddd', borderRadius: 6 }}>➕ إضافة مركبة</Link>
            <Link href="/agency/drivers" style={{ padding: '8px 12px', border: '1px solid #ddd', borderRadius: 6 }}>➕ إضافة سائق</Link>
            <Link href="/agency/transactions" style={{ padding: '8px 12px', border: '1px solid #ddd', borderRadius: 6 }}>💳 تصفح المعاملات</Link>
          </div>
        </section>
      </main>
    </div>
  );
}
