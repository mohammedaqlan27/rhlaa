// web/src/pages/500.jsx
import React from 'react';
import Link from 'next/link';

export default function Custom500() {
  return (
    <div style={{ padding: 40, textAlign: 'center' }}>
      <h1>500 - خطأ داخلي في الخادم</h1>
      <p>حدث خطأ غير متوقع أثناء معالجة الطلب.</p>
      <p>
        <Link href="/">العودة إلى الصفحة الرئيسية</Link>
      </p>
    </div>
  );
}
