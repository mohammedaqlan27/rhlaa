// web/src/pages/agency/transactions.jsx
import React, { useEffect, useState } from 'react';
import { auth } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getAgencyTransactions } from '../../services/agencyService';

export default function TransactionsPage() {
  const [user, setUser] = useState(null);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  const router = useRouter();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (!u) {
        router.push('/login');
        return;
      }
      try {
        setLoading(true);
        const txs = await getAgencyTransactions(u.uid);
        setTransactions(txs);
      } catch (e) {
        setMsg('خطأ في تحميل المعاملات: ' + (e.message || e.code));
      } finally {
        setLoading(false);
      }
    });
    return () => unsub();
  }, []);

  const logout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  const exportCSV = () => {
    if (!transactions.length) {
      setMsg('لا توجد معاملات للتصدير');
      return;
    }
    const header = ['ID', 'Amount', 'Description', 'Date'];
    const rows = transactions.map(tx => [
      tx.id,
      tx.amount,
      tx.description,
      new Date(tx.date).toLocaleString()
    ]);
    const csvContent = [header, ...rows].map(r => r.join(',')).join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'transactions.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  if (loading) return <p>جارٍ تحميل المعاملات...</p>;

  return (
    <div style={{ maxWidth: 900, margin: '24px auto' }}>
      <h2>معاملات المكتب</h2>
      <p>المستخدم: {user?.email}</p>
      <button onClick={logout}>تسجيل خروج</button>
      <button onClick={exportCSV} style={{ marginLeft: 12 }}>تصدير CSV</button>
      {msg && <div style={{ marginTop: 12 }}>{msg}</div>}
      <table border="1" cellPadding="8" style={{ marginTop: 20, width: '100%' }}>
        <thead>
          <tr>
            <th>المعرف</th>
            <th>المبلغ</th>
            <th>الوصف</th>
            <th>التاريخ</th>
          </tr>
        </thead>
        <tbody>
          {transactions.map(tx => (
            <tr key={tx.id}>
              <td>{tx.id}</td>
              <td>{tx.amount}</td>
              <td>{tx.description}</td>
              <td>{new Date(tx.date).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
