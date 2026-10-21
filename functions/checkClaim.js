const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'rhlaa-app' });

async function check(uid) {
  try {
    const user = await admin.auth().getUser(uid);
    console.log('CustomClaims for', uid, user.customClaims);
  } catch (e) {
    console.error('Error', e);
  }
}

check('TxlqFpzQTyZPWrh9c1pJyoa0KtW2');
