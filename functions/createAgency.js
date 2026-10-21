// functions/createAgency.js
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'rhlaa-app' });
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

async function createAgency() {
  try {
    await admin.auth().createUser({
      uid: 'agency1',
      email: 'agency1@test.local',
      password: 'password123'
    });
    console.log('✅ Created agency1');
  } catch (e) {
    console.error('❌ Error creating agency1:', e.message);
  }
}

createAgency();
