// src/components/AdminPanel.jsx
import React, { useEffect, useState } from 'react';
import { auth, functions, db } from '../firebaseClient';
import { httpsCallable } from 'firebase/functions';
import { collection, query, orderBy, onSnapshot, getDocs } from 'firebase/firestore';
import { onAuthStateChanged } from 'firebase/auth';
import '../styles/admin.css';

export default function AdminPanel() {
  const [currentUser, setCurrentUser] = useState(null);
  const [users, setUsers] = useState([]); // قائمة مبسطة من users collection
  const [roleChanges, setRoleChanges] = useState([]);
  const [targetUid, setTargetUid] = useState('');
  const [targetRole, setTargetRole] = useState('agency');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const unsubAuth = onAuthStateChanged(auth, async (u) => {
      setCurrentUser(u);
      if (u) {
        // تجديد التوكن للحصول على claims محدثة
        await u.getIdToken(true);
      }
    });

    // استماع لسجل تغييرات الأدوار
    const rcCol = collection(db, 'role_changes');
    const rcQuery = query(rcCol, orderBy('changedAt', 'desc'));
    const unsubRC = onSnapshot(rcQuery, (snap) => {
      setRoleChanges(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    // تحميل قائمة المستخدمين من مجموعة users (مبسطة)
    const usersCol = collection(db, 'users');
    const unsubUsers = onSnapshot(usersCol, (snap) => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    return () => {
      unsubAuth();
      unsubRC();
      unsubUsers();
    };
  }, []);

  async function handleSetRole(e) {
    e.preventDefault();
    setMessage('');
    if (!currentUser) return setMessage('يجب تسجيل الدخول كأدمن أولاً.');
    setLoading(true);
    try {
      // استدعاء الدالة callable
      const setUserRole = httpsCallable(functions, 'setUserRole');
      const res = await setUserRole({ uid: targetUid, role: targetRole });
      if (res.data && res.data.success) {
        setMessage(`تم تعيين الدور ${targetRole} للمستخدم ${targetUid}`);
        setTargetUid('');
      } else {
        setMessage('لم يتم التعيين بنجاح.');
      }
    } catch (err) {
      console.error(err);
      setMessage(err.message || 'خطأ أثناء استدعاء الدالة');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="admin-panel">
      <h2>لوحة الإدارة</h2>

      <section className="card">
        <h3>المستخدم الحالي</h3>
        {currentUser ? (
          <div>
            <p><strong>UID</strong>: {currentUser.uid}</p>
            <p><strong>البريد</strong>: {currentUser.email}</p>
            <p><strong>ملاحظة</strong>: تأكد أن لديك claim role: 'admin'</p>
          </div>
        ) : (
          <p>لم يتم تسجيل الدخول</p>
        )}
      </section>

      <section className="card">
        <h3>تعيين دور لمستخدم</h3>
        <form onSubmit={handleSetRole}>
          <label>UID المستخدم</label>
          <input value={targetUid} onChange={e => setTargetUid(e.target.value)} required />
          <label>الدور</label>
          <select value={targetRole} onChange={e => setTargetRole(e.target.value)}>
            <option value="admin">admin</option>
            <option value="agency">agency</option>
            <option value="gov">gov</option>
            <option value="driver">driver</option>
            <option value="passenger">passenger</option>
            <option value="security">security</option>
          </select>
          <button type="submit" disabled={loading}>تعيين الدور</button>
        </form>
        {message && <p className="message">{message}</p>}
      </section>

      <section className="card">
        <h3>قائمة المستخدمين (مبسطة)</h3>
        <div className="table">
          <div className="row header"><div>UID</div><div>الاسم</div><div>البريد</div><div>نوع المستخدم</div></div>
          {users.map(u => (
            <div className="row" key={u.id}>
              <div>{u.id}</div>
              <div>{u.displayName || '-'}</div>
              <div>{u.email || '-'}</div>
              <div>{u.userType || '-'}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="card">
        <h3>سجل تغييرات الأدوار</h3>
        <div className="table">
          <div className="row header"><div>الوقت</div><div>UID</div><div>الدور</div><div>من قبل</div></div>
          {roleChanges.map(r => (
            <div className="row" key={r.id}>
              <div>{r.changedAt?.toDate ? r.changedAt.toDate().toLocaleString() : ''}</div>
              <div>{r.uid}</div>
              <div>{r.role}</div>
              <div>{r.changedBy}</div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
