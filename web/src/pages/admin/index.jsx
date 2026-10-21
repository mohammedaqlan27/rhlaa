// web/src/pages/admin/index.jsx
import React, { useEffect, useState } from 'react';
import { auth, callSetUserRole, refreshIdToken } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getAllAgencies } from '../../services/agencyService';
import AdminNav from '../../components/AdminNav';

export default function AdminPage() {
  const [agencies, setAgencies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  const router = useRouter();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (!u) {
        router.push('/login');
        return;
      }
      try {
        setLoading(true);
        const list = await getAllAgencies();
        setAgencies(list);
      } catch (e) {
        setMsg('خطأ في تحميل البيانات: ' + (e.message || e.code));
      } finally {
        setLoading(false);
      }
    });
    return () => unsub();
  }, [router]);

  const changeRole = async (uid, newRole) => {
    try {
      setMsg(`جاري تغيير الدور إلى ${newRole}...`);
      await refreshIdToken(true);
      const res = await callSetUserRole(uid, newRole);
      setMsg(`تم تغيير الدور بنجاح: ${JSON.stringify(res)}`);
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  if (loading) {
    return (
      <div style={{ textAlign: 'center', marginTop: 50, fontFamily: 'Arial, sans-serif' }}>
        <p>جارٍ تحميل لوحة التحكم...</p>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 1100, margin: '24px auto', padding: '0 16px', fontFamily: 'Arial, sans-serif' }}>
      <AdminNav title="لوحة التحكم الرئيسية" />

      {msg && (
        <div style={{ marginBottom: 16, padding: 10, background: '#e6f7ff', border: '1px solid #91d5ff', borderRadius: 4 }}>
          {msg}
        </div>
      )}

      <div style={{ overflowX: 'auto', marginTop: 24 }}>
        <table border="1" cellPadding="10" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'right' }}>
          <thead>
            <tr style={{ background: '#fafafa' }}>
              <th>المعرف</th>
              <th>الاسم</th>
              <th>الدور الحالي</th>
              <th>إجراءات تغيير الدور</th>
            </tr>
          </thead>
          <tbody>
            {agencies.length === 0 ? (
              <tr>
                <td colSpan="4" style={{ textAlign: 'center', padding: '20px' }}>لا توجد بيانات مكاتب متاحة حالياً.</td>
              </tr>
            ) : (
              agencies.map(agency => (
                <tr key={agency.id}>
                  <td style={{ fontSize: '12px', color: '#666' }}>{agency.id}</td>
                  <td>{agency.name || 'مكتب بدون اسم'}</td>
                  <td>
                    <span style={{ background: '#e6f4ff', padding: '2px 8px', borderRadius: 4 }}>
                      {agency.role || 'غير محدد'}
                    </span>
                  </td>
                  <td>
                    <button 
                      onClick={() => changeRole(agency.id, 'agency')} 
                      style={{ cursor: 'pointer', padding: '4px 8px' }}
                    >
                      Agency
                    </button>
                    <button 
                      onClick={() => changeRole(agency.id, 'gov')} 
                      style={{ marginLeft: 6, cursor: 'pointer', padding: '4px 8px' }}
                    >
                      Gov
                    </button>
                    <button 
                      onClick={() => changeRole(agency.id, 'admin')} 
                      style={{ marginLeft: 6, cursor: 'pointer', padding: '4px 8px' }}
                    >
                      Admin
                    </button>
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