// web/src/pages/agency/trips.jsx
import React, { useEffect, useState } from 'react';
import { db, auth } from '../../lib/firebaseClient';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, query, where, onSnapshot, addDoc, doc, updateDoc, serverTimestamp } from 'firebase/firestore';

export default function TripsPage() {
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ destination: '', date: '', price: '', seats: '', driverId: '', vehicleId: '' });
  const [edit, setEdit] = useState(null);
  const [msg, setMsg] = useState('');
  const [agencyId, setAgencyId] = useState(null);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, u => { if (u) setAgencyId(u.uid); else setAgencyId(null); });
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!agencyId) { setTrips([]); setLoading(false); return; }
    setLoading(true);
    const q = query(collection(db, 'trips'), where('agencyId', '==', agencyId));
    const unsub = onSnapshot(q, snap => {
      setTrips(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }, err => { console.error(err); setMsg('خطأ في جلب الرحلات'); setLoading(false); });
    return () => unsub();
  }, [agencyId]);

  const handleChange = e => setForm(prev => ({ ...prev, [e.target.name]: e.target.value }));

  const handleAdd = async e => {
    e.preventDefault();
    try {
      const seats = Number(form.seats);
      await addDoc(collection(db, 'trips'), {
        destination: form.destination,
        date: form.date ? new Date(form.date) : null,
        price: Number(form.price),
        totalSeats: seats,
        availableSeats: seats,
        seatStatus: Array(seats).fill(true),
        driverId: form.driverId || null,
        vehicleId: form.vehicleId || null,
        agencyId,
        status: 'active',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      setMsg('تم إضافة الرحلة');
      setForm({ destination: '', date: '', price: '', seats: '', driverId: '', vehicleId: '' });
    } catch (err) { console.error(err); setMsg('خطأ في إضافة الرحلة'); }
  };

  const handleEdit = trip => setEdit(trip);

  const handleUpdate = async e => {
    e.preventDefault();
    try {
      const ref = doc(db, 'trips', edit.id);
      await updateDoc(ref, {
        destination: edit.destination,
        date: edit.date ? new Date(edit.date) : null,
        price: Number(edit.price),
        updatedAt: serverTimestamp(),
      });
      setMsg('تم تحديث الرحلة');
      setEdit(null);
    } catch (err) { console.error(err); setMsg('خطأ في تحديث الرحلة'); }
  };

  const handleCancel = async (tripId) => {
    try {
      const ref = doc(db, 'trips', tripId);
      await updateDoc(ref, { status: 'cancelled', updatedAt: serverTimestamp() });
      setMsg('تم إلغاء الرحلة');
    } catch (err) { console.error(err); setMsg('خطأ في إلغاء الرحلة'); }
  };

  if (loading) return <p>جارٍ تحميل الرحلات...</p>;

  return (
    <div style={{ maxWidth: 1000, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>إدارة الرحلات</h2>

      {!edit ? (
        <form onSubmit={handleAdd} style={{ marginBottom: 20 }}>
          <h3>إضافة رحلة جديدة</h3>
          <input name="destination" placeholder="الوجهة" value={form.destination} onChange={handleChange} required />
          <input name="date" type="date" value={form.date} onChange={handleChange} required />
          <input name="price" type="number" placeholder="السعر" value={form.price} onChange={handleChange} required />
          <input name="seats" type="number" placeholder="عدد المقاعد" value={form.seats} onChange={handleChange} required />
          <input name="driverId" placeholder="معرف السائق (اختياري)" value={form.driverId} onChange={handleChange} />
          <input name="vehicleId" placeholder="معرف المركبة (اختياري)" value={form.vehicleId} onChange={handleChange} />
          <button type="submit">إضافة</button>
        </form>
      ) : (
        <form onSubmit={handleUpdate} style={{ marginBottom: 20 }}>
          <h3>تعديل الرحلة</h3>
          <input value={edit.destination} onChange={e => setEdit(prev => ({ ...prev, destination: e.target.value }))} />
          <input type="date" value={edit.date ? new Date(edit.date.seconds ? edit.date.seconds * 1000 : edit.date).toISOString().slice(0,10) : ''} onChange={e => setEdit(prev => ({ ...prev, date: e.target.value }))} />
          <input value={edit.price} onChange={e => setEdit(prev => ({ ...prev, price: e.target.value }))} />
          <button type="submit">حفظ</button>
          <button type="button" onClick={() => setEdit(null)} style={{ marginLeft: 8 }}>إلغاء</button>
        </form>
      )}

      {msg && <p>{msg}</p>}

      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr style={{ background: '#f7f7f7' }}>
            <th>الوجهة</th><th>التاريخ</th><th>السعر</th><th>المقاعد</th><th>الحالة</th><th>إجراءات</th>
          </tr>
        </thead>
        <tbody>
          {trips.map(t => (
            <tr key={t.id}>
              <td>{t.destination}</td>
              <td>{t.date ? (t.date.seconds ? new Date(t.date.seconds*1000).toLocaleString() : new Date(t.date).toLocaleString()) : '—'}</td>
              <td>{t.price ?? '—'}</td>
              <td>{t.availableSeats ?? t.totalSeats ?? '—'}</td>
              <td>{t.status}</td>
              <td>
                <button onClick={() => handleEdit(t)}>✏️</button>
                <button onClick={() => handleCancel(t.id)} style={{ marginLeft: 8 }}>❌ إلغاء</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
