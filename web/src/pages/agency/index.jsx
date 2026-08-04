// web/src/pages/agency/index.jsx
import React from 'react';
import Link from 'next/link';

export default function AgencyHome() {
  return (
    <div style={{ padding: 24 }}>
      <h1>واجهة المكتب (Agency)</h1>
      <p>مرحباً بك في واجهة المكتب. اختر أحد الخيارات التالية:</p>

      <ul>
        <li>
          <Link href="/agency/login">تسجيل دخول المكتب</Link>
        </li>
        <li>
          <Link href="/agency/dashboard">لوحة المكتب</Link>
        </li>
        <li>
          <Link href="/agency/transactions">معاملات المكتب</Link>
        </li>
      </ul>
    </div>
  );
}
