// web/src/pages/agency/ratings.jsx
import React, { useEffect, useState } from 'react';
import { db } from '../../lib/firebaseClient';
import { collection, query, where, onSnapshot, doc, updateDoc } from 'firebase/firestore';

export default function RatingsPage() {
  const [ratings, setRatings] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'ratings'));
    const unsub = onSnapshot(q, snap => { setRatings(snap.docs.map(d => ({ id: d.id, ...d.data() }))); setLoading(false); }, err => { console.error(err); setLoading(false); });
    return () => unsub();
  }, []);

  const handleModerate = async (id, note) => {
    try { await updateDoc(doc(db, 'ratings', id), { note, moderatedAt: new Date() }); } catch (err) { console.error(err); }
  };

  if (loading) return <p>جارٍ تحميل التقييمات...</p>;

  return (
    <div style={{ maxWidth: 900, margin: '24px auto', fontFamily: 'Cairo' }}>
      <h2>التقييمات</h2>
      <table style={{ width: '100%' }}>
        <thead><tr style={{ background: '#f7f7f7' }}><th>من</th><th>إلى</th><th>الدرجة</th><th>التعليق</th><th>إجراءات</th></tr></thead>
        <tbody>
          {ratings.map(r => (
            <tr key={r.id}>
              <td>{r.fromUserId}</td>
              <td>{r.toUserId}</td>
              <td>{r.score}</td>
              <td>{r.comment}</td>
              <td><button onClick={() => handleModerate(r.id, 'تم المراجعة')}>وضع ملاحظة</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
