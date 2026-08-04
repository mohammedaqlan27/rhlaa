// web/src/pages/gov/index.jsx
import React, { useEffect, useState } from 'react';
import { auth } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getGovReports } from '../../services/govService';
import { refreshIdToken } from '../../lib/auth';

export default function GovPage() {
  const [user, setUser] = useState(null);
  const [reports, setReports] = useState([]);
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
        await refreshIdToken(true); // جدد التوكن للتأكد من وجود claims محدثة
        const list = await getGovReports(); // جلب تقارير الحكومة من الخدمة
        setReports(list);
      } catch (e) {
        setMsg('خطأ في تحميل التقارير: ' + (e.message || e.code));
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

  if (loading) return <p>جارٍ تحميل التقارير...</p>;

  return (
    <div style={{ maxWidth: 900, margin: '24px auto' }}>
      <h2>واجهة الحكومة</h2>
      <p>المستخدم: {user?.email}</p>
      <button onClick={logout}>تسجيل خروج</button>
      {msg && <div style={{ marginTop: 12 }}>{msg}</div>}
      <table border="1" cellPadding="8" style={{ marginTop: 20, width: '100%' }}>
        <thead>
          <tr>
            <th>المعرف</th>
            <th>العنوان</th>
            <th>الوصف</th>
            <th>التاريخ</th>
          </tr>
        </thead>
        <tbody>
          {reports.map(report => (
            <tr key={report.id}>
              <td>{report.id}</td>
              <td>{report.title}</td>
              <td>{report.description}</td>
              <td>{new Date(report.date).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
