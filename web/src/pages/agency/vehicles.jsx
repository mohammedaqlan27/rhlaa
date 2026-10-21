// web/src/pages/agency/vehicles.jsx
import React, { useEffect, useState } from 'react';
import { db, auth } from '../../lib/firebaseClient';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, query, where, onSnapshot, addDoc, deleteDoc, doc, updateDoc, serverTimestamp } from 'firebase/firestore';

export default function VehiclesPage() {
  const [vehicles, setVehicles] = useState([]);
  const [drivers, setDrivers] = useState([]);
  const [form, setForm] = useState({ plateNumber: '', vehicleType: '', makeModelYear: '', color: '', maxCapacity: '', driverId: '' });
  const [edit, setEdit] = useState(null);
  const [msg, setMsg] = useState('');
  const [agencyId, setAgencyId] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, u => { if (u) setAgencyId(u.uid); else setAgencyId(null); });
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!agencyId) { setVehicles([]); setLoading(false); return; }
    setLoading(true);
    const q = query(collection(db, 'vehicles'), where('agencyId', '==', agencyId));
    const unsub = onSnapshot(q, snap => { setVehicles(snap.docs.map(d => ({ id: d.id, ...d.data() }))); setLoading(false); }, err => { console.error(err); setLoading(false); });
    const qDrivers = query(collection(db, 'users'), where('userType', '==', 'driver'));
    const unsubD = onSnapshot(qDrivers, snap => setDrivers(snap.docs.map(d => ({ id: d.id, ...d.data() }))));
    return () => { unsub(); unsubD(); };
  }, [agencyId]);

  const handleChange = e => setForm(prev => ({ ...prev, [e.target.name]: e.target.value }));

  const handleAdd = async e => {
    e.preventDefault();
    try {
      await addDoc(collection(db, 'vehicles'), {
        plateNumber: form.plateNumber || null,
        vehicleType: form.vehicleType || null,
        makeModelYear: form.makeModelYear || null,
        color: form.color || null,
        maxCapacity: form.maxCapacity ? Number(form.maxCapacity) : null,
        driverId: form.driverId || null,
        agencyId,
        isVerified: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      setMsg('تم إضافة المركبة');
      setForm({ plateNumber: '', vehicleType: '', makeModelYear: '', color: '', maxCapacity: '', driverId: '' });
    } catch (err) { console.error(err); setMsg('خطأ في إضافة المركبة'); }
  };

  const handleEdit = v => setEdit(v);

  const handleUpdate = async e => {
    e.preventDefault();
    try {
      const ref = doc(db, 'vehicles', edit.id);
      await updateDoc(ref, {
        plateNumber: edit.plateNumber || null,
        vehicleType: edit.vehicleType || null,
        makeModelYear: edit.makeModelYear || null,
        color: edit.color || null,
        maxCapacity: edit.maxCapacity ? Number(edit.maxCapacity) : null,
        driverId: edit.driverId || null,
        updatedAt: serverTimestamp(),
      });
      setMsg('تم تعديل المركبة');
      setEdit(null);
    } catch (err) { console.error(err); setMsg('خطأ في تعديل المركبة'); }
  };

  const handleDelete = async id => {
    if (!confirm('هل تريد حذف المركبة؟')) return;
    try { await deleteDoc(doc(db, 'vehicles', id)); setMsg('تم حذف المركبة'); }
    catch (err) { console.error(err); setMsg('خطأ في حذف المركبة'); }
  };

  if (loading) return <p>جارٍ تحميل المركبات...</p>;

  const getDriverName = id => { const d = drivers.find(x => x.id === id); return d ? (d.name || d.nickname || d.email) : 'غير مرتبط'; };

  return (
    <div style={{ maxWidth: 1000, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>إدارة المركبات</h2>

      {!edit ? (
        <form onSubmit={handleAdd} style={{ marginBottom: 20 }}>
          <input name="plateNumber" placeholder="رقم اللوحة" value={form.plateNumber} onChange={handleChange} />
          <input name="vehicleType" placeholder="نوع المركبة" value={form.vehicleType} onChange={handleChange} />
          <input name="makeModelYear" placeholder="الموديل/السنة" value={form.makeModelYear} onChange={handleChange} />
          <input name="color" placeholder="اللون" value={form.color} onChange={handleChange} />
          <input name="maxCapacity" type="number" placeholder="السعة" value={form.maxCapacity} onChange={handleChange} />
          <select name="driverId" value={form.driverId} onChange={handleChange}>
            <option value="">اختر السائق (اختياري)</option>
            {drivers.map(d => <option key={d.id} value={d.id}>{d.name || d.nickname || d.email}</option>)}
          </select>
          <button type="submit">إضافة</button>
        </form>
      ) : (
        <form onSubmit={handleUpdate} style={{ marginBottom: 20 }}>
          <input value={edit.plateNumber} onChange={e => setEdit(prev => ({ ...prev, plateNumber: e.target.value }))} />
          <input value={edit.vehicleType} onChange={e => setEdit(prev => ({ ...prev, vehicleType: e.target.value }))} />
          <input value={edit.makeModelYear} onChange={e => setEdit(prev => ({ ...prev, makeModelYear: e.target.value }))} />
          <input value={edit.color} onChange={e => setEdit(prev => ({ ...prev, color: e.target.value }))} />
          <input type="number" value={edit.maxCapacity} onChange={e => setEdit(prev => ({ ...prev, maxCapacity: e.target.value }))} />
          <select value={edit.driverId} onChange={e => setEdit(prev => ({ ...prev, driverId: e.target.value }))}>
            <option value="">اختر السائق (اختياري)</option>
            {drivers.map(d => <option key={d.id} value={d.id}>{d.name || d.nickname || d.email}</option>)}
          </select>
          <button type="submit">حفظ</button>
          <button type="button" onClick={() => setEdit(null)} style={{ marginLeft: 8 }}>إلغاء</button>
        </form>
      )}

      {msg && <p>{msg}</p>}

      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr style={{ background: '#f7f7f7' }}><th>اللوحة</th><th>النوع</th><th>الموديل</th><th>اللون</th><th>السعة</th><th>السائق</th><th>إجراءات</th></tr></thead>
        <tbody>
          {vehicles.map(v => (
            <tr key={v.id}>
              <td>{v.plateNumber || '—'}</td>
              <td>{v.vehicleType || '—'}</td>
              <td>{v.makeModelYear || '—'}</td>
              <td>{v.color || '—'}</td>
              <td>{v.maxCapacity ?? '—'}</td>
              <td>{getDriverName(v.driverId)}</td>
              <td>
                <button onClick={() => handleEdit(v)}>✏️</button>
                <button onClick={() => handleDelete(v.id)} style={{ marginLeft: 8 }}>❌</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
