# Firebase Functions (Agencies & Transactions)

## دوال متوفرة
- `createAgencySafe` : إنشاء مكتب جديد مع التحقق من عدم تكرار رقم الهاتف.
- `creditAgency` : شحن رصيد المكتب وتسجيل معاملة.
- `debitAgency` : خصم رصيد المكتب وتسجيل معاملة.
- `exportTransactions` : تصدير سجل المعاملات بصيغة CSV.

## إعداد محلي
```bash
cd functions
npm install
firebase emulators:start --only functions,firestore,auth
