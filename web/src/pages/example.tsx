// src/pages/example.tsx
import React from 'react';
import Button from '../components/Button';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/solid';

export default function ExamplePage() {
  return (
    <div style={{ padding: 20 }}>
      <h2>أمثلة على الأزرار</h2>

      <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
        <Button variant="primary" onClick={() => console.log('save')}>
          حفظ
        </Button>

        <Button variant="primary" icon={<PlusIcon width={16} height={16} />} onClick={() => console.log('add')}>
          إضافة
        </Button>

        <Button variant="secondary" size="sm">إلغاء</Button>

        <Button variant="danger" icon={<TrashIcon width={16} height={16} />} ariaLabel="حذف" iconOnly onClick={() => console.log('delete')} />

        <Button variant="primary" loading>جارٍ التحميل</Button>

        <Button variant="primary" block>إرسال</Button>
      </div>
    </div>
  );
}
