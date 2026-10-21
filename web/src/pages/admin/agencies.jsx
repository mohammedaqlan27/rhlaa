// web/src/pages/admin/agencies.jsx
import React, { useEffect, useState } from 'react';
import { auth, refreshIdToken } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { useRouter } from 'next/router';
import { getAllAgencies, creditAgency, debitAgency, createAgencySafe } from '../../services/agencyService';
import AdminNav from '../../components/AdminNav';

export default function AdminAgenciesPage() {
  const [currentUser, setCurrentUser] = useState(null);
  const [agencies, setAgencies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  
  // حالة نموذج إنشاء مكتب جديد
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newAgencyData, setNewAgencyData] = useState({ email: '', password: '', name: '' });
  
  const router = useRouter();

  // جلب بيانات المكاتب وحماية الصفحة
  const fetchAgenciesData = async () => {
    try {
      setLoading(true);
      const list = await getAllAgencies();
      setAgencies(list);
    } catch (e) {
      setMsg('خطأ في جلب المكاتب: ' + (e.message || e.code));
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
      await fetchAgenciesData();
    });
    return () => unsub();
  }, [router]);

  const handleLogout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  // شحن رصيد مكتب
  const handleCredit = async (agencyId) => {
    const amountStr = prompt('أدخل المبلغ المراد إضافته (شحن الرصيد):');
    if (!amountStr || isNaN(amountStr)) return;
    const amount = parseFloat(amountStr);
    const reason = prompt('سبب الشحن (اختياري):') || 'شحن إداري';

    try {
      setMsg('جاري شحن الرصيد...');
      await refreshIdToken(true);
      await creditAgency(agencyId, amount, reason);
      setMsg('تم شحن الرصيد بنجاح.');
      await fetchAgenciesData();
    } catch (e) {
      setMsg('خطأ في شحن الرصيد: ' + (e.message || e.code));
    }
  };

  // خصم رصيد من مكتب
  const handleDebit = async (agencyId) => {
    const amountStr = prompt('أدخل المبلغ المراد خصمه:');
    if (!amountStr || isNaN(amountStr)) return;
    const amount = parseFloat(amountStr);
    const reason = prompt('سبب الخصم (اجباري):') || 'خصم إداري';

    try {
      setMsg('جاري خصم الرصيد...');
      await refreshIdToken(true);
      await debitAgency(agencyId, amount, reason);
      setMsg('تم خصم الرصيد بنجاح.');
      await fetchAgenciesData();
    } catch (e) {
      setMsg('خطأ في خصم الرصيد: ' + (e.message || e.code));
    }
  };

  // إنشاء مكتب جديد
  const handleCreateAgency = async (e) => {
    e.preventDefault();
    try {
      setMsg('جاري إنشاء المكتب بشكل آمن...');
      await refreshIdToken(true);
      await createAgencySafe(newAgencyData);
      setMsg('تم إنشاء المكتب بنجاح!');
      setShowCreateModal(false);
      setNewAgencyData({ email: '', password: '', name: '' });
      await fetchAgenciesData();
    } catch (e) {
      setMsg('خطأ في إنشاء المكتب: ' + (e.message || e.code));
    }
  };

  if (loading && agencies.length === 0) {
    return (
      <div style={{ textAlign: 'center', marginTop: 50, fontFamily: 'Arial, sans-serif' }}>
        <p>جاري تحميل قائمة المكاتب...</p>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 1100, margin: '24px auto', padding: '0 16px', fontFamily: 'Arial, sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>إدارة المكاتب والجهات</h2>
        <div>
          <button 
            onClick={() => setShowCreateModal(true)} 
            style={{ background: '#52c41a', color: '#fff', border: 'none', padding: '8px 12px', borderRadius: 4, cursor: 'pointer', marginRight: 8 }}
          >
            + إضافة مكتب جديد
          </button>
          <button 
            onClick={() => router.push('/admin')} 
            style={{ marginRight: 8, padding: '8px 12px', cursor: 'pointer' }}
          >
            اللوحة الرئيسية
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

      {/* نافذة إنشاء مكتب جديد */}
      {showCreateModal && (
        <div style={{ background: '#fafafa', border: '1px solid #ddd', padding: 16, borderRadius: 8, marginTop: 20 }}>
          <h3>إنشاء حساب مكتب جديد</h3>
          <form onSubmit={handleCreateAgency}>
            <div style={{ marginBottom: 10 }}>
              <label>اسم المكتب:</label><br />
              <input 
                type="text" 
                value={newAgencyData.name} 
                onChange={e => setNewAgencyData({...newAgencyData, name: e.target.value})} 
                required 
                style={{ width: '100%', padding: 6, marginTop: 4 }}
              />
            </div>
            <div style={{ marginBottom: 10 }}>
              <label>البريد الإلكتروني:</label><br />
              <input 
                type="email" 
                value={newAgencyData.email} 
                onChange={e => setNewAgencyData({...newAgencyData, email: e.target.value})} 
                required 
                style={{ width: '100%', padding: 6, marginTop: 4 }}
              />
            </div>
            <div style={{ marginBottom: 10 }}>
              <label>كلمة المرور:</label><br />
              <input 
                type="password" 
                value={newAgencyData.password} 
                onChange={e => setNewAgencyData({...newAgencyData, password: e.target.value})} 
                required 
                style={{ width: '100%', padding: 6, marginTop: 4 }}
              />
            </div>
            <button type="submit" style={{ background: '#1890ff', color: '#fff', border: 'none', padding: '6px 12px', borderRadius: 4, cursor: 'pointer' }}>حفظ وإنشاء</button>
            <button type="button" onClick={() => setShowCreateModal(false)} style={{ marginRight: 8, padding: '6px 12px', cursor: 'pointer' }}>إلغاء</button>
          </form>
        </div>
      )}

      <div style={{ overflowX: 'auto', marginTop: 20 }}>
        <table border="1" cellPadding="10" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'right' }}>
          <thead>
            <tr style={{ background: '#fafafa' }}>
              <th>معرف المكتب (ID)</th>
              <th>اسم المكتب</th>
              <th>الرصيد الحالي</th>
              <th>العمليات المالية (شحن / خصم)</th>
            </tr>
          </thead>
          <tbody>
            {agencies.length === 0 ? (
              <tr>
                <td colSpan="4" style={{ textAlign: 'center', padding: 20 }}>لا توجد مكاتب مسجلة حتى الآن.</td>
              </tr>
            ) : (
              agencies.map(agency => (
                <tr key={agency.id}>
                  <td style={{ fontSize: '11px', color: '#666' }}>{agency.id}</td>
                  <td>{agency.name || agency.email || 'بدون اسم'}</td>
                  <td>
                    <span style={{ fontWeight: 'bold', color: '#1890ff' }}>
                      {agency.balance !== undefined ? agency.balance : 0}
                    </span>
                  </td>
                  <td>
                    <button 
                      onClick={() => handleCredit(agency.id)} 
                      style={{ background: '#52c41a', color: '#fff', border: 'none', padding: '4px 8px', borderRadius: 4, cursor: 'pointer', fontSize: '12px' }}
                    >
                      شحن رصيد
                    </button>
                    <button 
                      onClick={() => handleDebit(agency.id)} 
                      style={{ background: '#faad14', color: '#fff', border: 'none', padding: '4px 8px', borderRadius: 4, cursor: 'pointer', fontSize: '12px', marginRight: 6 }}
                    >
                      خصم رصيد
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