const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const fs = require('fs');

// إعداد الاتصال بالمحاكي المحلي
process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";

// تهيئة التطبيق
initializeApp({ projectId: "rhlaa-app" });

// الحصول على نسخة Firestore بالطريقة الجديدة
const db = getFirestore();

// قراءة ملف الـ JSON
const data = JSON.parse(fs.readFileSync('./firestore_structure.json', 'utf8'));

async function importData() {
    console.log("⏳ جاري بدء رفع البيانات للمحاكي...");
    try {
        for (const collectionName in data) {
            const documents = data[collectionName];
            for (const docId in documents) {
                const fields = documents[docId].fields;
                const cleanData = parseFields(fields);

                await db.collection(collectionName).doc(docId).set(cleanData);
                console.log(`✅ تم رفع: [${collectionName}] -> ${docId}`);
            }
        }
        console.log("🚀 انتهت العملية بنجاح! اذهب الآن لمتصفح كروم وافتح Emulator UI.");
    } catch (error) {
        console.error("❌ حدث خطأ أثناء الرفع:", error);
    }
}

// دالة لتحويل تنسيق Firestore المعقد إلى بيانات بسيطة
function parseFields(fields) {
    const obj = {};
    if (!fields) return obj;

    for (const key in fields) {
        const valueObj = fields[key];
        const type = Object.keys(valueObj)[0];
        const val = valueObj[type];

        if (type === 'mapValue') {
            obj[key] = parseFields(val.fields);
        } else if (type === 'arrayValue') {
            obj[key] = val.values ? val.values.map(v => {
                const t = Object.keys(v)[0];
                return v[t];
            }) : [];
        } else if (type === 'timestampValue') {
            obj[key] = Timestamp.fromDate(new Date(val));
        } else if (type === 'integerValue') {
            obj[key] = parseInt(val);
        } else if (type === 'doubleValue') {
            obj[key] = parseFloat(val);
        } else if (type === 'geoPointValue') {
            obj[key] = val; // يمكنك تحويلها لـ GeoPoint إذا أردت
        } else {
            obj[key] = val;
        }
    }
    return obj;
}

importData();