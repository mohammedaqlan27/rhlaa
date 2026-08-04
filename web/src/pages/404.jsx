// web/src/pages/404.jsx
import React from 'react';
import Link from 'next/link';

export default function Custom404() {
  return (
    <div style={{ padding: 40, textAlign: 'center' }}>
      <h1>404 - الصفحة غير موجودة</h1>
      <p>عذراً، الصفحة التي تحاول الوصول إليها غير متوفرة.</p>
      <p>
        <Link href="/">العودة إلى الصفحة الرئيسية</Link>
      </p>
    </div>
  );
}
