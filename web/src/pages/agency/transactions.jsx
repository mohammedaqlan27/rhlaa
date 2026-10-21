// web/src/pages/agency/transactions.jsx
import React, { useEffect, useState, useMemo } from 'react';
import { auth } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getAgencyTransactions } from '../../services/agencyService';

// مساعدة لتفريغ CSV مع اقتباس القيم التي تحتوي على فواصل أو اقتباسات
const escapeCsvValue = (val) => {
  if (val === null || val === undefined) return '';
  const s = String(val);
  if (s.includes('"')) return `"${s.replace(/"/g, '""')}"`;
  if (s.includes(',') || s.includes('\n') || s.includes('\r')) return `"${s}"`;
  return s;
};

const formatDate = (d) => {
  if (!d) return '—';
  const date = (typeof d === 'string' || d instanceof String) ? new Date(d) : (d.seconds ? new Date(d.seconds * 1000) : new Date(d));
  return new Intl.DateTimeFormat('ar-YE', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
};

export default function TransactionsPage() {
  const [user, setUser] = useState(null);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  const [filterText, setFilterText] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const router = useRouter();

  useEffect(() => {
    let mounted = true;
    const unsub = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (!u) {
        router.push('/login');
        return;
      }
      try {
        setLoading(true);
        setMsg('');
        // جلب المعاملات من الخدمة (الخادم يجب أن يضمن صلاحية الوصول)
        const txs = await getAgencyTransactions(u.uid);
        if (!mounted) return;
        // نتوقع أن txs مصفوفة من الكائنات: { id, amount, description, date, ... }
        setTransactions(Array.isArray(txs) ? txs : []);
      } catch (e) {
        console.error('getAgencyTransactions error', e);
        setMsg('خطأ في تحميل المعاملات: ' + (e.message || e.code || 'غير معروف'));
      } finally {
        if (mounted) setLoading(false);
      }
    });
    return () => { mounted = false; unsub(); };
  }, [router]);

  const logout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  // مجموع المبالغ بعد الفلترة
  const filtered = useMemo(() => {
    const fText = filterText.trim().toLowerCase();
    const from = fromDate ? new Date(fromDate) : null;
    const to = toDate ? new Date(toDate) : null;
    return transactions.filter(tx => {
      if (fText) {
        const hay = `${tx.id} ${tx.description || ''} ${tx.type || ''} ${tx.transactionId || ''}`.toLowerCase();
        if (!hay.includes(fText)) return false;
      }
      if (from || to) {
        const d = tx.date ? (tx.date.seconds ? new Date(tx.date.seconds * 1000) : new Date(tx.date)) : null;
        if (from && d && d < from) return false;
        if (to && d && d > new Date(to.getTime() + 24*60*60*1000 - 1)) return false; // include whole to-day
      }
      return true;
    });
  }, [transactions, filterText, fromDate, toDate]);

  const totals = useMemo(() => {
    const totalAmount = filtered.reduce((s, t) => s + (Number(t.amount) || 0), 0);
    return { count: filtered.length, totalAmount };
  }, [filtered]);

  const exportCSV = () => {
    if (!filtered.length) {
      setMsg('لا توجد معاملات للتصدير');
      return;
    }
    const header = ['ID', 'Amount', 'Description', 'Date', 'Type', 'TransactionId'];
    const rows = filtered.map(tx => [
      escapeCsvValue(tx.id),
      escapeCsvValue(tx.amount),
      escapeCsvValue(tx.description),
      escapeCsvValue(tx.date ? (tx.date.seconds ? new Date(tx.date.seconds * 1000).toISOString() : new Date(tx.date).toISOString()) : ''),
      escapeCsvValue(tx.type || ''),
      escapeCsvValue(tx.transactionId || ''),
    ]);
    const csvContent = [header, ...rows].map(r => r.join(',')).join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const ts = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `transactions_${user?.uid || 'agency'}_${ts}.csv`;
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  if (loading) return <p>جارٍ تحميل المعاملات...</p>;

  return (
    <div style={{ maxWidth: 1100, margin: '24px auto', fontFamily: 'Cairo' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>معاملات المكتب</h2>
        <div>
          <button onClick={logout}>تسجيل خروج</button>
          <button onClick={exportCSV} style={{ marginLeft: 12 }}>تصدير CSV</button>
        </div>
      </header>

      <section style={{ marginTop: 12, display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <div>المستخدم: <strong>{user?.email}</strong></div>
        <div>إجمالي المعاملات: <strong>{totals.count}</strong></div>
        <div>إجمالي المبلغ: <strong>{totals.totalAmount.toLocaleString('ar-EG')}</strong></div>
      </section>

      <section style={{ marginTop: 16, border: '1px solid #eee', padding: 12, borderRadius: 8 }}>
        <h4>فلترة وبحث</h4>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <input placeholder="بحث بالمعرف أو الوصف" value={filterText} onChange={e => setFilterText(e.target.value)} />
          <label>من</label>
          <input type="date" value={fromDate} onChange={e => setFromDate(e.target.value)} />
          <label>إلى</label>
          <input type="date" value={toDate} onChange={e => setToDate(e.target.value)} />
          <button onClick={() => { setFilterText(''); setFromDate(''); setToDate(''); }}>مسح الفلاتر</button>
        </div>
      </section>

      {msg && <div style={{ marginTop: 12, color: 'crimson' }}>{msg}</div>}

      <table border="1" cellPadding="8" style={{ marginTop: 20, width: '100%', borderCollapse: 'collapse' }}>
        <thead style={{ background: '#f7f7f7' }}>
          <tr>
            <th>المعرف</th>
            <th>المبلغ</th>
            <th>الوصف</th>
            <th>التاريخ</th>
            <th>النوع</th>
            <th>معرف المعاملة</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map(tx => (
            <tr key={tx.id}>
              <td>{tx.id}</td>
              <td>{Number(tx.amount || 0).toLocaleString('ar-EG')}</td>
              <td style={{ maxWidth: 300, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{tx.description || '—'}</td>
              <td>{formatDate(tx.date)}</td>
              <td>{tx.type || '—'}</td>
              <td>{tx.transactionId || '—'}</td>
            </tr>
          ))}
          {filtered.length === 0 && (
            <tr><td colSpan={6} style={{ textAlign: 'center', padding: 12 }}>لا توجد معاملات مطابقة</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
