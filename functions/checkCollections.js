// functions/checkCollections.js
const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'rhlaa-app';

try {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
} catch (e) {
  // ignore if already initialized
}
const db = admin.firestore();

async function listCollections() {
  try {
    const collections = await db.listCollections();
    if (!collections.length) {
      console.log('No top-level collections found.');
      return;
    }
    for (const col of collections) {
      const snap = await col.limit(5).get();
      console.log(`Collection: ${col.id} — sample docs: ${snap.size}`);
      snap.docs.forEach(d => console.log(`  - ${d.id}`));
    }
  } catch (e) {
    console.error('Error listing collections:', e && e.stack ? e.stack : e);
  } finally {
    process.exit(0);
  }
}

listCollections();
