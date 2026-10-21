// web/src/pages/agency/notifications.jsx
import React, { useEffect, useState } from 'react';
import { db, auth } from '../../lib/firebaseClient';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';

export default function NotificationsPage() {
  const [agencyId, setAgencyId] = useState(null);
  const [form, setForm] = useState({ title: '', body: '', type: 'general' });
  const [msg, setMsg] = useState('');

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, u => { if (u) setAgencyId(u.uid); else setAgencyId(null); });
    return () => unsub();
  }, []);

  const handleChange = e => setForm(prev => ({ ...prev, [e.target.name]: e.target.value }));

  const handleSend = async e => {
    e.preventDefault();
    try {
      await addDoc(collection(db, 'notifications'), { ...form, agencyId, isRead: false, createdAt: serverTimestamp() });
      setMsg('تم إرسال الإشعار (سجل فقط)');
      setForm({ title: '', body: '', type: 'general' });
    } catch (err) { console.error(err); setMsg('خطأ'); }
  };

  return (
    <div style={{ maxWidth: 800, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>إدارة التنبيهات</h2>
      <form onSubmit={handleSend}>
        <input name="title" placeholder="العنوان" value={form.title} onChange={handleChange} required />
        <textarea name="body" placeholder="نص الإشعار" value={form.body} onChange={handleChange} required />
        <select name="type" value={form.type} onChange={handleChange}>
          <option value="general">عام</option>
          <option value="booking">حجز</option>
          <option value="payment">دفع</option>
        </select>
        <button type="submit">إرسال</button>
      </form>
      {msg && <p>{msg}</p>}
    </div>
  );
}
