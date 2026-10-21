// web/src/components/AdminPanel.jsx
import React, { useEffect, useState } from 'react';
import { auth, db } from '../lib/firebaseClient';
import { collection, query, orderBy, onSnapshot } from 'firebase/firestore';
import { onAuthStateChanged } from 'firebase/auth';
import { setUserRole } from '../services/adminService'; // استدعاء من ملف الخدمات المخصص
import '../styles/admin.css';

export default function AdminPanel() {
  const [currentUser, setCurrentUser] = useState(null);
  const [users, setUsers] = useState([]);
  const [roleChanges, setRoleChanges] = useState([]);
  const [targetUid, setTargetUid] = useState('');
  const [targetRole, setTargetRole] = useState('agency');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const unsubAuth = onAuthStateChanged(auth, async (u) => {
      setCurrentUser(u);
      if (u) {
        await u.getIdToken(true);
      }
    });

    // استماع لسجل تغييرات الأدوار
    const rcCol = collection(db, 'role_changes');
    const rcQuery = query(rcCol, orderBy('changedAt', 'desc'));
    const unsubRC = onSnapshot(rcQuery, (snap) => {
      setRoleChanges(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    // تحميل قائمة المستخدمين لحظياً من Firestore
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
      // استخدام الدالة من ملف adminService الجاهز لديك
      const res = await setUserRole(targetUid, targetRole);
      if (res && res.success !== false) {
        setMessage(`تم تعيين الدور ${targetRole} للمستخدم بنجاح.`);
        setTargetUid('');
      } else {
        setMessage('لم يتم التعيين بنجاح.');
      }
    } catch (err) {
      console.error(err);
      setMessage(err.message || 'خطأ أثناء تغيير الدور');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="admin-panel" style={{ fontFamily: 'Arial, sans-serif', padding: '16px' }}>
      <h2>لوحة الإدارة الشاملة</h2>

      <section className="card" style={{ background: '#f9f9f9', padding: 16, borderRadius: 8, marginBottom: 20 }}>
        <h3>المستخدم الحالي</h3>
        {currentUser ? (
          <div>
            <p><strong>UID</strong>: {currentUser.uid}</p>
            <p><strong>البريد</strong>: {currentUser.email}</p>
          </div>
        ) : (
          <p>لم يتم تسجيل الدخول</p>
        )}
      </section>

      <section className="card" style={{ background: '#f9f9f9', padding: 16, borderRadius: 8, marginBottom: 20 }}>
        <h3>تعيين دور لمستخدم</h3>
        <form onSubmit={handleSetRole}>
          <div style={{ marginBottom: 10 }}>
            <label>UID المستخدم:</label><br />
            <input 
              value={targetUid} 
              onChange={e => setTargetUid(e.target.value)} 
              required 
              style={{ width: '100%', padding: 6, marginTop: 4 }}
            />
          </div>
          <div style={{ marginBottom: 10 }}>
            <label>الدور:</label><br />
            <select 
              value={targetRole} 
              onChange={e => setTargetRole(e.target.value)}
              style={{ width: '100%', padding: 6, marginTop: 4 }}
            >
              <option value="admin">admin</option>
              <option value="agency">agency</option>
              <option value="gov">gov</option>
              <option value="driver">driver</option>
              <option value="passenger">passenger</option>
              <option value="security">security</option>
            </select>
          </div>
          <button 
            type="submit" 
            disabled={loading}
            style={{ background: '#1890ff', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
          >
            {loading ? 'جاري التعيين...' : 'تعيين الدور'}
          </button>
        </form>
        {message && <p className="message" style={{ marginTop: 10, color: '#d46b08' }}>{message}</p>}
      </section>

      <section className="card" style={{ background: '#f9f9f9', padding: 16, borderRadius: 8, marginBottom: 20 }}>
        <h3>قائمة المستخدمين</h3>
        <div style={{ overflowX: 'auto' }}>
          <table border="1" cellPadding="8" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'right', background: '#fff' }}>
            <thead>
              <tr style={{ background: '#eee' }}>
                <th>UID</th>
                <th>الاسم</th>
                <th>البريد</th>
                <th>نوع المستخدم</th>
              </tr>
            </thead>
            <tbody>
              {users.map(u => (
                <tr key={u.id}>
                  <td style={{ fontSize: '11px', color: '#666' }}>{u.id}</td>
                  <td>{u.displayName || u.name || '-'}</td>
                  <td>{u.email || '-'}</td>
                  <td>{u.userType || u.role || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card" style={{ background: '#f9f9f9', padding: 16, borderRadius: 8 }}>
        <h3>سجل تغييرات الأدوار</h3>
        <div style={{ overflowX: 'auto' }}>
          <table border="1" cellPadding="8" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'right', background: '#fff' }}>
            <thead>
              <tr style={{ background: '#eee' }}>
                <th>الوقت</th>
                <th>UID</th>
                <th>الدور</th>
                <th>من قبل</th>
              </tr>
            </thead>
            <tbody>
              {roleChanges.map(r => (
                <tr key={r.id}>
                  <td style={{ fontSize: '12px' }}>{r.changedAt?.toDate ? r.changedAt.toDate().toLocaleString() : ''}</td>
                  <td style={{ fontSize: '11px', color: '#666' }}>{r.uid}</td>
                  <td>{r.role}</td>
                  <td style={{ fontSize: '11px', color: '#666' }}>{r.changedBy}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}