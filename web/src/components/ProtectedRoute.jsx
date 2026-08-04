// src/components/ProtectedRoute.jsx
import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { refreshIdToken } from '../lib/auth';   // ← غيّرنا الاستيراد هنا
import { auth } from '../lib/firebaseClient';

export default function ProtectedRoute({ children, allowedRoles = [] }) {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    // نستخدم refreshIdToken بدل subscribeAuth
    const checkAuth = async () => {
      const user = auth.currentUser;
      if (!user) {
        setAuthorized(false);
        setReady(true);
        router.replace('/login');
        return;
      }

      // جدد التوكن للحصول على الـ claims
      await refreshIdToken(true);
      const idTokenResult = await user.getIdTokenResult();
      const role = idTokenResult.claims.role || null;

      if (allowedRoles.length === 0 || allowedRoles.includes(role)) {
        setAuthorized(true);
        setReady(true);
      } else {
        // ليس لديه الدور المناسب
        await auth.signOut();
        setAuthorized(false);
        setReady(true);
        router.replace('/login');
      }
    };

    checkAuth();
  }, []);

  if (!ready) {
    return <div style={{ padding: 20 }}>جارٍ التحقق...</div>;
  }
  if (!authorized) {
    return null;
  }
  return <>{children}</>;
}
