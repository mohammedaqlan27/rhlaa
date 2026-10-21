// web/src/components/AdminNav.jsx
import React from 'react';
import { useRouter } from 'next/router';
import { signOut } from 'firebase/auth';
import { auth } from '../lib/firebaseClient';

export default function AdminNav({ title }) {
  const router = useRouter();

  const handleLogout = async () => {
    await signOut(auth);
    router.push('/login');
  };

  const isActive = (path) => router.pathname === path;

  const linkStyle = (path) => ({
    padding: '8px 14px',
    background: isActive(path) ? '#1890ff' : '#f0f2f5',
    color: isActive(path) ? '#fff' : '#333',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    textDecoration: 'none',
    fontWeight: 'bold',
    fontSize: '14px'
  });

  return (
    <div style={{ background: '#fff', padding: '16px', borderRadius: 8, boxShadow: '0 2px 8px rgba(0,0,0,0.06)', marginBottom: 24 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
        <h2 style={{ margin: 0, fontSize: '20px', color: '#222' }}>{title || 'لوحة تحكم الأدمن'}</h2>
        
        {/* أزرار التنقل */}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button style={linkStyle('/admin')} onClick={() => router.push('/admin')}>
            الرئيسية
          </button>
          <button style={linkStyle('/admin/users')} onClick={() => router.push('/admin/users')}>
            المستخدمين
          </button>
          <button style={linkStyle('/admin/agencies')} onClick={() => router.push('/admin/agencies')}>
            المكاتب والجهات
          </button>
          <button 
            onClick={handleLogout} 
            style={{ padding: '8px 14px', background: '#ff4d4f', color: '#fff', border: 'none', borderRadius: 4, cursor: 'pointer', fontWeight: 'bold' }}
          >
            تسجيل خروج
          </button>
        </div>
      </div>
    </div>
  );
}