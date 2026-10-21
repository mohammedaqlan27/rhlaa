// web/src/pages/agency/bookings.jsx
import React, { useEffect, useState } from 'react';
import { db, auth } from '../../lib/firebaseClient';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, query, where, onSnapshot, doc, updateDoc } from 'firebase/firestore';

export default function BookingsPage() {
  const [bookings, setBookings] = useState([]);
  const [agencyId, setAgencyId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, u => { if (u) setAgencyId(u.uid); else setAgencyId(null); });
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!agencyId) { setBookings([]); setLoading(false); return; }
    setLoading(true);
    const q = query(collection(db, 'bookings'), where('agencyId', '==', agencyId));
    const unsub = onSnapshot(q, snap => { setBookings(snap.docs.map(d => ({ id: d.id, ...d.data() }))); setLoading(false); }, err => { console.error(err); setLoading(false); });
    return () => unsub();
  }, [agencyId]);

  const updateStatus = async (id, status) => {
    try {
      await updateDoc(doc(db, 'bookings', id), { bookingStatus: status, updatedAt: new Date() });
      setMsg('تم تحديث حالة الحجز');
    } catch (err) { console.error(err); setMsg('خطأ في تحديث الحجز'); }
  };

  if (loading) return <p>جارٍ تحميل الحجوزات...</p>;

  return (
    <div style={{ maxWidth: 1000, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>الحجوزات</h2>
      {msg && <p>{msg}</p>}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr style={{ background: '#f7f7f7' }}><th>الراكب</th><th>الرحلة</th><th>المقاعد</th><th>المبلغ</th><th>الحالة</th><th>إجراءات</th></tr></thead>
        <tbody>
          {bookings.map(b => (
            <tr key={b.id}>
              <td>{b.passengerNickname || b.passengerId}</td>
              <td>{b.tripId}</td>
              <td>{b.bookedSeatsCount}</td>
              <td>{b.totalPrice ?? b.amountPaid ?? '—'}</td>
              <td>{b.bookingStatus}</td>
              <td>
                {b.bookingStatus !== 'confirmed' && <button onClick={() => updateStatus(b.id, 'confirmed')}>✅ تأكيد</button>}
                {b.bookingStatus !== 'cancelled' && <button onClick={() => updateStatus(b.id, 'cancelled')} style={{ marginLeft: 8 }}>❌ إلغاء</button>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
