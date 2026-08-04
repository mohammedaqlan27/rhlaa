// web/src/pages/admin/users.jsx
import React, { useEffect, useState } from 'react';
import { auth } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getAllUsers, setUserRole, disableUser, enableUser } from '../../services/adminService';
import { refreshIdToken } from '../../lib/auth';

export default function AdminUsersPage() {
  const [user, setUser] = useState(null);
  const [users, setUsers] = useState([]);
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
        await refreshIdToken(true); // جدد التوكن للتأكد من صلاحيات الأدمن
        const list = await getAllUsers();
        setUsers(list);
      } catch (e) {
        setMsg('خطأ في تحميل المستخدمين: ' + (e.message || e.code));
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
      await refreshIdToken(true);
      const res = await setUserRole(uid, newRole);
      setMsg(`تم تغيير الدور: ${JSON.stringify(res)}`);
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  const disable = async (uid) => {
    try {
      setMsg('جاري تعطيل المستخدم...');
      const res = await disableUser(uid);
      setMsg(`تم تعطيل المستخدم: ${JSON.stringify(res)}`);
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  const enable = async (uid) => {
    try {
      setMsg('جاري تفعيل المستخدم...');
      const res = await enableUser(uid);
      setMsg(`تم تفعيل المستخدم: ${JSON.stringify(res)}`);
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  if (loading) return <p>جارٍ تحميل المستخدمين...</p>;

  return (
    <div style={{ maxWidth: 900, margin: '24px auto' }}>
      <h2>إدارة المستخدمين (Admin)</h2>
      <p>المستخدم الأدمن: {user?.email}</p>
      <button onClick={logout}>تسجيل خروج</button>
      {msg && <div style={{ marginTop: 12 }}>{msg}</div>}
      <table border="1" cellPadding="8" style={{ marginTop: 20, width: '100%' }}>
        <thead>
          <tr>
            <th>المعرف</th>
            <th>البريد الإلكتروني</th>
            <th>الدور الحالي</th>
            <th>الإجراءات</th>
          </tr>
        </thead>
        <tbody>
          {users.map(u => (
            <tr key={u.uid}>
              <td>{u.uid}</td>
              <td>{u.email}</td>
              <td>{u.role || 'غير محدد'}</td>
              <td>
                <button onClick={() => changeRole(u.uid, 'agency')}>Agency</button>
                <button onClick={() => changeRole(u.uid, 'gov')} style={{ marginLeft: 8 }}>Gov</button>
                <button onClick={() => changeRole(u.uid, 'admin')} style={{ marginLeft: 8 }}>Admin</button>
                <button onClick={() => disable(u.uid)} style={{ marginLeft: 8 }}>تعطيل</button>
                <button onClick={() => enable(u.uid)} style={{ marginLeft: 8 }}>تفعيل</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
