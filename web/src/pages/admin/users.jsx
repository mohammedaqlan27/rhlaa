// web/src/pages/admin/users.jsx
import React, { useEffect, useState } from 'react';
import { auth, refreshIdToken } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getAllUsers, setUserRole, disableUser, enableUser } from '../../services/adminService';
import AdminNav from '../../components/AdminNav';

export default function AdminUsersPage() {
  const [currentUser, setCurrentUser] = useState(null);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  const router = useRouter();

  // جلب المستخدمين وحماية الصفحة
  const fetchUsersData = async () => {
    try {
      setLoading(true);
      const list = await getAllUsers();
      setUsers(list);
    } catch (e) {
      setMsg('خطأ في جلب المستخدمين: ' + (e.message || e.code));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (!u) {
        router.push('/login');
        return;
      }
      setCurrentUser(u);
      await fetchUsersData();
    });
    return () => unsub();
  }, [router]);

  const handleLogout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  // تغيير دور المستخدم
  const handleChangeRole = async (uid, newRole) => {
    try {
      setMsg(`جاري تحديث الدور إلى ${newRole}...`);
      await refreshIdToken(true);
      await setUserRole(uid, newRole);
      setMsg(`تم تحديث دور المستخدم بنجاح.`);
      await fetchUsersData(); // تحديث القائمة
    } catch (e) {
      setMsg('خطأ في تغيير الدور: ' + (e.message || e.code));
    }
  };

  // تعطيل حساب المستخدم
  const handleDisable = async (uid) => {
    if (!confirm('هل أنت متأكد من تعطيل هذا الحساب؟')) return;
    try {
      setMsg('جاري تعطيل الحساب...');
      await disableUser(uid);
      setMsg('تم تعطيل الحساب بنجاح.');
      await fetchUsersData();
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  // تفعيل حساب المستخدم
  const handleEnable = async (uid) => {
    try {
      setMsg('جاري تفعيل الحساب...');
      await enableUser(uid);
      setMsg('تم تفعيل الحساب بنجاح.');
      await fetchUsersData();
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  if (loading && users.length === 0) {
    return (
      <div style={{ textAlign: 'center', marginTop: 50, fontFamily: 'Arial, sans-serif' }}>
        <p>جاري تحميل قائمة المستخدمين...</p>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 1100, margin: '24px auto', padding: '0 16px', fontFamily: 'Arial, sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>إدارة المستخدمين والصلاحيات</h2>
        <div>
          <button 
            onClick={() => router.push('/admin')} 
            style={{ marginRight: 8, padding: '8px 12px', cursor: 'pointer' }}
          >
            العودة للوحة الرئيسية
          </button>
          <button 
            onClick={handleLogout} 
            style={{ background: '#ff4d4f', color: '#fff', border: 'none', padding: '8px 12px', borderRadius: 4, cursor: 'pointer' }}
          >
            خروج
          </button>
        </div>
      </div>

      <p style={{ color: '#555' }}>المسؤول الحالي: {currentUser?.email}</p>

      {msg && (
        <div style={{ marginTop: 12, padding: 10, background: '#f0f5ff', border: '1px solid #adc6ff', borderRadius: 4 }}>
          {msg}
        </div>
      )}

      <div style={{ overflowX: 'auto', marginTop: 20 }}>
        <table border="1" cellPadding="10" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'right' }}>
          <thead>
            <tr style={{ background: '#fafafa' }}>
              <th>UID</th>
              <th>البريد الإلكتروني / الاسم</th>
              <th>الحالة</th>
              <th>الدور</th>
              <th>التحكم بالأدوار</th>
              <th>إجراءات الحساب</th>
            </tr>
          </thead>
          <tbody>
            {users.length === 0 ? (
              <tr>
                <td colSpan="6" style={{ textAlign: 'center', padding: 20 }}>لا يوجد مستخدمون مسجلون.</td>
              </tr>
            ) : (
              users.map(u => (
                <tr key={u.uid || u.id}>
                  <td style={{ fontSize: '11px', color: '#666' }}>{u.uid || u.id}</td>
                  <td>{u.email || u.name || 'بدون اسم'}</td>
                  <td>
                    <span style={{ 
                      color: u.disabled ? '#ff4d4f' : '#52c41a', 
                      fontWeight: 'bold' 
                    }}>
                      {u.disabled ? 'معطل' : 'نشط'}
                    </span>
                  </td>
                  <td>
                    <span style={{ background: '#e6f4ff', padding: '2px 6px', borderRadius: 4 }}>
                      {u.role || 'user'}
                    </span>
                  </td>
                  <td>
                    <button onClick={() => handleChangeRole(u.uid || u.id, 'user')} style={{ cursor: 'pointer', fontSize: '12px' }}>User</button>
                    <button onClick={() => handleChangeRole(u.uid || u.id, 'agency')} style={{ margin: '0 4px', cursor: 'pointer', fontSize: '12px' }}>Agency</button>
                    <button onClick={() => handleChangeRole(u.uid || u.id, 'admin')} style={{ cursor: 'pointer', fontSize: '12px' }}>Admin</button>
                  </td>
                  <td>
                    {u.disabled ? (
                      <button 
                        onClick={() => handleEnable(u.uid || u.id)} 
                        style={{ background: '#52c41a', color: '#fff', border: 'none', padding: '4px 8px', borderRadius: 4, cursor: 'pointer' }}
                      >
                        تفعيل
                      </button>
                    ) : (
                      <button 
                        onClick={() => handleDisable(u.uid || u.id)} 
                        style={{ background: '#faad14', color: '#fff', border: 'none', padding: '4px 8px', borderRadius: 4, cursor: 'pointer' }}
                      >
                        تعطيل
                      </button>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}