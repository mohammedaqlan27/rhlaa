// web/src/pages/agency/drivers.jsx
import React, { useEffect, useState } from 'react';
import { db } from '../../lib/firebaseClient';
import { collection, query, where, onSnapshot, addDoc, deleteDoc, doc, updateDoc, serverTimestamp } from 'firebase/firestore';

export default function DriversPage() {
  const [drivers, setDrivers] = useState([]);
  const [form, setForm] = useState({ name: '', phone: '', license: '' });
  const [edit, setEdit] = useState(null);
  const [msg, setMsg] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'users'), where('userType', '==', 'driver'));
    const unsub = onSnapshot(q, snap => { setDrivers(snap.docs.map(d => ({ id: d.id, ...d.data() }))); setLoading(false); }, err => { console.error(err); setLoading(false); });
    return () => unsub();
  }, []);

  const handleChange = e => { const { name, value } = e.target; if (edit) setEdit(prev => ({ ...prev, [name]: value })); else setForm(prev => ({ ...prev, [name]: value })); };

  const handleAdd = async e => {
    e.preventDefault();
    try {
      await addDoc(collection(db, 'users'), { name: form.name, phone: form.phone, license: form.license, userType: 'driver', createdAt: serverTimestamp() });
      setMsg('تم إضافة السائق');
      setForm({ name: '', phone: '', license: '' });
    } catch (err) { console.error(err); setMsg('خطأ في إضافة السائق'); }
  };

  const handleEdit = d => setEdit({ id: d.id, name: d.name || '', phone: d.phone || '', license: d.license || '' });

  const handleUpdate = async e => {
    e.preventDefault();
    try {
      const ref = doc(db, 'users', edit.id);
      await updateDoc(ref, { name: edit.name, phone: edit.phone, license: edit.license, updatedAt: serverTimestamp() });
      setMsg('تم تعديل السائق');
      setEdit(null);
    } catch (err) { console.error(err); setMsg('خطأ في تعديل السائق'); }
  };

  const handleDelete = async id => {
    if (!confirm('هل تريد حذف السائق؟')) return;
    try { await deleteDoc(doc(db, 'users', id)); setMsg('تم حذف السائق'); } catch (err) { console.error(err); setMsg('خطأ في حذف السائق'); }
  };

  if (loading) return <p>جارٍ تحميل السائقين...</p>;

  return (
    <div style={{ maxWidth: 1000, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>إدارة السائقين</h2>

      {!edit ? (
        <form onSubmit={handleAdd} style={{ marginBottom: 20 }}>
          <input name="name" placeholder="الاسم" value={form.name} onChange={handleChange} required />
          <input name="phone" placeholder="الهاتف" value={form.phone} onChange={handleChange} required />
          <input name="license" placeholder="الرخصة" value={form.license} onChange={handleChange} required />
          <button type="submit">إضافة</button>
        </form>
      ) : (
        <form onSubmit={handleUpdate} style={{ marginBottom: 20 }}>
          <input name="name" value={edit.name} onChange={handleChange} required />
          <input name="phone" value={edit.phone} onChange={handleChange} required />
          <input name="license" value={edit.license} onChange={handleChange} required />
          <button type="submit">حفظ</button>
          <button type="button" onClick={() => setEdit(null)} style={{ marginLeft: 8 }}>إلغاء</button>
        </form>
      )}

      {msg && <p>{msg}</p>}

      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr style={{ background: '#f7f7f7' }}><th>الاسم</th><th>الهاتف</th><th>الرخصة</th><th>إجراءات</th></tr></thead>
        <tbody>
          {drivers.map(d => (
            <tr key={d.id}>
              <td>{d.name || '—'}</td>
              <td>{d.phone || '—'}</td>
              <td>{d.license || '—'}</td>
              <td>
                <button onClick={() => handleEdit(d)}>✏️</button>
                <button onClick={() => handleDelete(d.id)} style={{ marginLeft: 8 }}>❌</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
