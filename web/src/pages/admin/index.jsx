// web/src/pages/admin/index.jsx
import React, { useEffect, useState } from 'react';
import { auth, callSetUserRole, refreshIdToken } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getAllAgencies } from '../../services/agencyService';

export default function AdminPage() {
  const [user, setUser] = useState(null);
  const [agencies, setAgencies] = useState([]);
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
        // جلب قائمة المكاتب أو المستخدمين من الخدمة
        const list = await getAllAgencies();
        setAgencies(list);
      } catch (e) {
        setMsg('خطأ في تحميل البيانات: ' + (e.message || e.code));
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

  const changeRole = async (uid, newRole) => {
    try {
      setMsg(`جاري تغيير الدور إلى ${newRole}...`);
      await refreshIdToken(true); // جدد التوكن للتأكد من صلاحيات الأدمن
      const res = await callSetUserRole(uid, newRole);
      setMsg(`تم تغيير الدور: ${JSON.stringify(res)}`);
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  if (loading) return <p>جارٍ تحميل البيانات...</p>;

  return (
    <div style={{ maxWidth: 900, margin: '24px auto' }}>
      <h2>لوحة الأدمن</h2>
      <p>المستخدم: {user?.email}</p>
      <button onClick={logout}>تسجيل خروج</button>
      {msg && <div style={{ marginTop: 12 }}>{msg}</div>}
      <table border="1" cellPadding="8" style={{ marginTop: 20, width: '100%' }}>
        <thead>
          <tr>
            <th>المعرف</th>
            <th>الاسم</th>
            <th>الدور الحالي</th>
            <th>تغيير الدور</th>
          </tr>
        </thead>
        <tbody>
          {agencies.map(agency => (
            <tr key={agency.id}>
              <td>{agency.id}</td>
              <td>{agency.name}</td>
              <td>{agency.role || 'غير محدد'}</td>
              <td>
                <button onClick={() => changeRole(agency.id, 'agency')}>Agency</button>
                <button onClick={() => changeRole(agency.id, 'gov')} style={{ marginLeft: 8 }}>Gov</button>
                <button onClick={() => changeRole(agency.id, 'admin')} style={{ marginLeft: 8 }}>Admin</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
