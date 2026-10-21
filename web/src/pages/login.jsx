// web/src/pages/login.jsx
import React, { useState } from 'react';
import { useRouter } from 'next/router';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth, refreshIdToken } from '../lib/firebaseClient';

export default function LoginPage() {
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

      // توجيه ذكي بناءً على دور المستخدم
      if (role === 'admin') {
        router.replace('/admin'); // توجيه الأدمن إلى لوحة التحكم الرئيسية
      } else if (role === 'agency' || role === 'gov') {
        router.replace('/agency/dashboard'); // توجيه المكاتب أو الجهات الحكومية
      } else {
        // خروج فوري إن الدور غير مسموح له بإدارة الويب
        await auth.signOut();
        setError('ليس لديك صلاحية الوصول إلى لوحة التحكم.');
      }
    } catch (err) {
      console.error(err);
      setError(err.message || 'خطأ أثناء تسجيل الدخول، تأكد من البيانات.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>تسجيل دخول لوحة التحكم</h1>
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
            {loading ? 'جارٍ التحقق...' : 'دخول'}
          </button>
        </form>
        {error && <div className="error" style={{ color: 'red', marginTop: 10 }}>{error}</div>}
      </div>
    </div>
  );
}