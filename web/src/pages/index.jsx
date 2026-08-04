// web/src/pages/index.jsx
import React from 'react';
import Link from 'next/link';

export default function Home() {
  return (
    <div style={{ padding: 24 }}>
      <h1>Rhlaa Web</h1>
      <p>الخادم يعمل بنجاح إذا ظهرت هذه الصفحة.</p>

      <h2>التنقل</h2>
      <ul>
        <li>
          <Link href="/login">تسجيل الدخول</Link>
        </li>
        <li>
          <Link href="/agency/dashboard">لوحة المكتب (Agency)</Link>
        </li>
        <li>
          <Link href="/agency/transactions">معاملات المكتب (Agency)</Link>
        </li>
        <li>
          <Link href="/admin">لوحة الأدمن (Admin)</Link>
        </li>
        <li>
          <Link href="/gov">واجهة الحكومة (Gov)</Link>
        </li>
      </ul>
    </div>
  );
}
