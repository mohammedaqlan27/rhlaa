// functions/createAndClaim.js
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'rhlaa-app' });

async function createAndClaim(uid, email, pwd, role) {
  try {
    await admin.auth().createUser({ uid, email, password: pwd });
  } catch(e) {}

  await admin.auth().setCustomUserClaims(uid, { role });
  console.log('✅ Custom Claim Set:', uid, '=>', role);
}

(async () => {
  await createAndClaim('driver1', 'driver1@test.local', 'password', 'driver');
  await createAndClaim('passenger1', 'pass1@test.local', 'password', 'passenger');
  await createAndClaim('agency1', 'agency1@test.local', 'password', 'agency');
  await createAndClaim('gov1', 'gov1@test.local', 'password', 'government');
  await createAndClaim('admin1', 'admin1@test.local', 'password', 'admin');

  process.exit(0);
})();