// web/src/pages/agency/dashboard.jsx
import React, { useEffect, useState } from 'react';
import { auth } from '../../lib/firebaseClient';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { getCurrentUserRole, refreshIdToken } from '../../lib/auth';
import { creditAgency } from '../../services/agencyService';
import { useRouter } from 'next/router';

export default function Dashboard() {
  const [user, setUser] = useState(null);
  const [role, setRole] = useState(null);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');
  const router = useRouter();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (!u) {
        router.push('/login'); // توجيه إلى صفحة تسجيل الدخول العامة
        return;
      }
      const r = await getCurrentUserRole(false);
      setRole(r);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const handleRefreshToken = async () => {
    try {
      setMsg('جاري تجديد التوكن...');
      const tokenRes = await refreshIdToken();
      setRole(tokenRes.claims?.role || null);
      setMsg('تم تجديد التوكن');
    } catch (e) {
      setMsg('خطأ في تجديد التوكن: ' + e.message);
    }
  };

  const handleCredit = async () => {
    try {
      setMsg('جاري شحن المحفظة...');
      // استبدل بالقيمة الحقيقية لمعرف المكتب
      const agencyId = user?.uid;
      const res = await creditAgency(agencyId, 100, 'Test credit from web');
      setMsg('تم الشحن. TX: ' + res.transaction.id);
    } catch (e) {
      setMsg('خطأ: ' + (e.message || e.code));
    }
  };

  const logout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  if (loading) return <p>جارٍ التحميل...</p>;

  return (
    <div style={{ maxWidth: 800, margin: '24px auto' }}>
      <h2>لوحة المكتب</h2>
      <p>المستخدم: {user?.email}</p>
      <p>الدور الحالي: <strong>{role || 'غير محدد'}</strong></p>
      <button onClick={handleRefreshToken}>تجديد التوكن الآن</button>
      <button onClick={handleCredit} style={{ marginLeft: 12 }}>شحن 100</button>
      <button onClick={logout} style={{ marginLeft: 12 }}>تسجيل خروج</button>
      {msg && <div style={{ marginTop: 12 }}>{msg}</div>}
    </div>
  );
}
