// web/src/pages/agency/staff.jsx
import React, { useEffect, useState } from 'react';
import { db } from '../../lib/firebaseClient';
import { collection, query, where, onSnapshot, addDoc, doc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

export default function StaffPage() {
  const [staff, setStaff] = useState([]);
  const [form, setForm] = useState({ name: '', email: '', role: 'receptionist' });
  const [edit, setEdit] = useState(null);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    const q = query(collection(db, 'agencies_staff'));
    const unsub = onSnapshot(q, snap => setStaff(snap.docs.map(d => ({ id: d.id, ...d.data() }))));
    return () => unsub();
  }, []);

  const handleChange = e => setForm(prev => ({ ...prev, [e.target.name]: e.target.value }));

  const handleAdd = async e => {
    e.preventDefault();
    try {
      await addDoc(collection(db, 'agencies_staff'), { ...form, createdAt: serverTimestamp() });
      setMsg('تم إضافة موظف');
      setForm({ name: '', email: '', role: 'receptionist' });
    } catch (err) { console.error(err); setMsg('خطأ'); }
  };

  const handleEdit = s => setEdit(s);

  const handleUpdate = async e => {
    e.preventDefault();
    try {
      await updateDoc(doc(db, 'agencies_staff', edit.id), { name: edit.name, email: edit.email, role: edit.role, updatedAt: serverTimestamp() });
      setMsg('تم تحديث الموظف');
      setEdit(null);
    } catch (err) { console.error(err); setMsg('خطأ'); }
  };

  const handleDelete = async id => { if (!confirm('حذف الموظف؟')) return; await deleteDoc(doc(db, 'agencies_staff', id)); setMsg('تم الحذف'); };

  return (
    <div style={{ maxWidth: 900, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>إدارة الموظفين</h2>

      {!edit ? (
        <form onSubmit={handleAdd}>
          <input name="name" placeholder="الاسم" value={form.name} onChange={handleChange} required />
          <input name="email" placeholder="البريد" value={form.email} onChange={handleChange} required />
          <select name="role" value={form.role} onChange={handleChange}>
            <option value="receptionist">موظف استقبال</option>
            <option value="manager">مدير</option>
            <option value="auditor">مراقب</option>
          </select>
          <button type="submit">إضافة</button>
        </form>
      ) : (
        <form onSubmit={handleUpdate}>
          <input value={edit.name} onChange={e => setEdit(prev => ({ ...prev, name: e.target.value }))} />
          <input value={edit.email} onChange={e => setEdit(prev => ({ ...prev, email: e.target.value }))} />
          <select value={edit.role} onChange={e => setEdit(prev => ({ ...prev, role: e.target.value }))}>
            <option value="receptionist">موظف استقبال</option>
            <option value="manager">مدير</option>
            <option value="auditor">مراقب</option>
          </select>
          <button type="submit">حفظ</button>
          <button type="button" onClick={() => setEdit(null)} style={{ marginLeft: 8 }}>إلغاء</button>
        </form>
      )}

      {msg && <p>{msg}</p>}

      <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 12 }}>
        <thead><tr style={{ background: '#f7f7f7' }}><th>الاسم</th><th>البريد</th><th>الدور</th><th>إجراءات</th></tr></thead>
        <tbody>
          {staff.map(s => (
            <tr key={s.id}>
              <td>{s.name}</td><td>{s.email}</td><td>{s.role}</td>
              <td><button onClick={() => handleEdit(s)}>✏️</button><button onClick={() => handleDelete(s.id)} style={{ marginLeft: 8 }}>❌</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
