// functions/seedFirestore.js (Updated for userType alignment)
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const AUTH_EMULATOR = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT || 'rhlaa-app';

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_EMULATOR;
process.env.GCLOUD_PROJECT = PROJECT_ID;

console.log('Using FIRESTORE_EMULATOR_HOST =', process.env.FIRESTORE_EMULATOR_HOST);
console.log('Using FIREBASE_AUTH_EMULATOR_HOST =', process.env.FIREBASE_AUTH_EMULATOR_HOST);
console.log('Using GCLOUD_PROJECT =', process.env.GCLOUD_PROJECT);

try {
  admin.initializeApp({ projectId: PROJECT_ID });
} catch (e) {
  console.error('admin.initializeApp failed:', e);
  process.exit(1);
}

const db = admin.firestore();

try {
  const [host, port] = EMULATOR_HOST.split(':');
  db.settings({ host: `${host}:${port}`, ssl: false });
  console.log('Firestore settings applied to emulator host.');
} catch (e) {
  console.warn('Could not apply explicit db.settings:', e);
}

function convertValue(key, val) {
  if (val && typeof val === 'object' && val._serverTimestamp) {
    return admin.firestore.FieldValue.serverTimestamp();
  }
  if (typeof val === 'string' && (key.toLowerCase().includes('time') || key.toLowerCase().includes('date') || key === 'departureTime')) {
    const d = new Date(val);
    if (!isNaN(d.getTime())) return admin.firestore.Timestamp.fromDate(d);
  }
  return val;
}

async function writeCollection(name, items) {
  if (!Array.isArray(items)) {
    console.warn(`Skipping ${name}: not an array`);
    return;
  }
  console.log(`\n--- Writing collection: ${name} (${items.length} docs) ---`);
  for (const item of items) {
    try {
      const docId = item.id || item.uid || db.collection(name).doc().id;
      const docRef = db.collection(name).doc(docId);

      const copy = { ...item };
      copy.id = docId;

      if (!copy.uid && name === 'users') {
        copy.uid = docId;
      }

      // 🛠️ التعديل هنا: ضمان توحيد الحقل userType لمجموعة users بناءً على أي حقل قديم مثل role
      if (name === 'users') {
        if (!copy.userType && copy.role) {
          copy.userType = copy.role; // تحويل role القديم إلى userType
        }
        // تصحيح افتراضي بناءً على الـ ID أو الإيميل إذا لزم الأمر
        if (docId === 'admin1' && !copy.userType) copy.userType = 'admin';
        if (docId === 'gov1' && !copy.userType) copy.userType = 'government';
        if (docId === 'agency1' && !copy.userType) copy.userType = 'agency';
        if (docId === 'driver1' && !copy.userType) copy.userType = 'driver';
        if (docId === 'passenger1' && !copy.userType) copy.userType = 'passenger';
      }

      const preview = { ...copy };
      if (preview.description && typeof preview.description === 'string' && preview.description.length > 200) {
        preview.description = preview.description.slice(0, 200) + '...';
      }
      console.log(`Writing doc ${name}/${docId} -> preview keys: ${Object.keys(preview).join(', ')}`);

      for (const k of Object.keys(copy)) {
        try {
          copy[k] = convertValue(k, copy[k]);
        } catch (convErr) {
          console.error(`  convertValue failed for key=${k} in ${name}/${docId}:`, convErr);
          throw convErr;
        }
      }

      await docRef.set(copy, { merge: true });
      console.log(`✅ Wrote ${name}/${docId}`);
    } catch (err) {
      console.error(`❌ Failed to write doc in ${name}:`, err && err.stack ? err.stack : err);
    }
  }
}

async function verifyCollections(expectedCollections) {
  console.log('\nVerifying written collections...');
  for (const col of expectedCollections) {
    try {
      const snap = await db.collection(col).limit(1).get();
      if (snap.empty) {
        console.warn(`⚠️ Collection ${col} is empty or does not exist`);
      } else {
        console.log(`✔️ Collection ${col} exists and has documents (sample: ${snap.docs.map(d => d.id).join(', ')})`);
      }
    } catch (e) {
      console.error(`Error checking collection ${col}:`, e && e.stack ? e.stack : e);
    }
  }
}

async function seed() {
  const filePath = path.join(__dirname, 'data', 'seed.json');
  if (!fs.existsSync(filePath)) {
    console.error('seed.json not found in functions/data/');
    process.exit(1);
  }
  const raw = fs.readFileSync(filePath, 'utf8');
  let data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    console.error('Invalid JSON in seed.json:', e);
    process.exit(1);
  }

  const expected = Object.keys(data);
  for (const [col, items] of Object.entries(data)) {
    await writeCollection(col, items);
  }

  await verifyCollections(expected);

  console.log('\nSeeding complete');
  process.exit(0);
}

seed().catch(err => {
  console.error('Seeding failed', err && err.stack ? err.stack : err);
  process.exit(1);
});