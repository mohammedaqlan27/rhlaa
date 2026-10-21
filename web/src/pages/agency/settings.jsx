// web/src/pages/agency/settings.jsx
import React, { useEffect, useState } from 'react';
import { db, auth } from '../../lib/firebaseClient';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc, updateDoc, serverTimestamp } from 'firebase/firestore';

export default function SettingsPage() {
  const [agencyId, setAgencyId] = useState(null);
  const [data, setData] = useState({ agencyName: '', mobileNumber: '', location: null, email: '', isActive: true });
  const [msg, setMsg] = useState('');

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async u => {
      if (!u) { setAgencyId(null); return; }
      setAgencyId(u.uid);
      const ref = doc(db, 'agencies', u.uid);
      const snap = await getDoc(ref);
      if (snap.exists()) setData(snap.data());
    });
    return () => unsub();
  }, []);

  const handleChange = e => setData(prev => ({ ...prev, [e.target.name]: e.target.value }));

  const handleSave = async e => {
    e.preventDefault();
    try {
      const ref = doc(db, 'agencies', agencyId);
      await updateDoc(ref, { ...data, updatedAt: serverTimestamp() });
      setMsg('تم حفظ الإعدادات');
    } catch (err) { console.error(err); setMsg('خطأ في الحفظ'); }
  };

  return (
    <div style={{ maxWidth: 900, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>إعدادات المكتب</h2>
      <form onSubmit={handleSave}>
        <input name="agencyName" placeholder="اسم المكتب" value={data.agencyName || ''} onChange={handleChange} required />
        <input name="mobileNumber" placeholder="رقم الجوال" value={data.mobileNumber || ''} onChange={handleChange} />
        <input name="email" placeholder="البريد الإلكتروني" value={data.email || ''} onChange={handleChange} />
        <label>حالة الترخيص</label>
        <select name="isActive" value={data.isActive ? 'true' : 'false'} onChange={e => setData(prev => ({ ...prev, isActive: e.target.value === 'true' }))}>
          <option value="true">مفعل</option>
          <option value="false">غير مفعل</option>
        </select>
        <button type="submit">حفظ</button>
      </form>
      {msg && <p>{msg}</p>}
    </div>
  );
}
