// web/src/pages/agency/login.jsx
import React, { useState } from 'react';
import { useRouter } from 'next/router';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth, refreshIdToken } from '../../lib/firebaseClient';
import '../../styles/login.css';

export default function AgencyLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const cred = await signInWithEmailAndPassword(auth, email, password);
      // جدد التوكن فوراً للحصول على custom claims المحدثة
      await refreshIdToken(true);
      const idTokenResult = await cred.user.getIdTokenResult();
      const role = idTokenResult.claims.role || null;

      // تحقق من أن الدور هو agency فقط
      if (role === 'agency') {
        router.replace('/agency/dashboard');
      } else {
        // خروج فوري إن الدور غير مناسب
        await auth.signOut();
        setError('ليس لديك صلاحية الوصول. هذه الواجهة مخصصة لدور agency فقط.');
      }
    } catch (err) {
      console.error(err);
      setError(err.message || 'خطأ أثناء تسجيل الدخول');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>تسجيل دخول المكتب</h1>
        <form onSubmit={handleSubmit}>
          <label>البريد الإلكتروني</label>
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            required
          />
          <label>كلمة المرور</label>
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
          />
          <button type="submit" disabled={loading}>
            {loading ? 'جارٍ...' : 'دخول'}
          </button>
        </form>
        {error && <div className="error">{error}</div>}
      </div>
    </div>
  );
}
