// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fs = require('fs');
require('dotenv').config(); // تحميل متغيرات البيئة من ملف .env إذا موجود

console.log('Functions file loading. Node version:', process.version);

// تهيئة Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// قراءة السر: أولاً من متغير البيئة، ثم من ملف .secret إذا لم يكن موجود
let EXPECTED_TOKEN = process.env.EXPIRE_TOKEN || '';
if (!EXPECTED_TOKEN) {
  try {
    EXPECTED_TOKEN = fs.readFileSync('.secret', 'utf8').trim();
    console.log('Token loaded from .secret file');
  } catch (err) {
    console.warn('No EXPIRE_TOKEN in env and no .secret file found');
  }
}
console.log('EXPIRE_TOKEN present:', !!EXPECTED_TOKEN);

/**
 * verifyRequest
 * يقبل إما توكن ثابت مخزن في EXPIRE_TOKEN أو Firebase ID token (من محاكي Auth أو الإنتاج)
 */
async function verifyRequest(req) {
  const auth = req.get('Authorization') || '';
  const token = auth.replace(/^Bearer\s*/i, '').trim();
  if (!token) return false;

  // 1) تحقق من السر الثابت أولاً
  if (EXPECTED_TOKEN && token === EXPECTED_TOKEN) {
    return true;
  }

  // 2) حاول التحقق كـ Firebase ID token
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return !!decoded;
  } catch (e) {
    console.warn('verifyRequest: token invalid or verification failed.', e && e.message);
    return false;
  }
}

/**
 * Utility: commitBatchInChunks
 */
async function commitBatchInChunks(batches) {
  for (const b of batches) {
    await b.commit();
  }
}

/**
 * expirePendingBookingsHttp
 */
exports.expirePendingBookingsHttp = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization');

  if (req.method === 'OPTIONS') {
    console.log('CORS preflight (OPTIONS) received');
    return res.status(204).send('');
  }

  console.log('expirePendingBookingsHttp invoked. headers:', req.headers);

  try {
    const ok = await verifyRequest(req);
    if (!ok) {
      console.warn('Unauthorized request.');
      return res.status(401).send('Unauthorized');
    }

    const now = admin.firestore.Timestamp.now();
    console.log('Querying pending bookings with reservedUntil <=', now.toDate?.() || now);

    const q = await db.collection('bookings')
      .where('bookingStatus', '==', 'pending')
      .where('reservedUntil', '<=', now)
      .limit(100)
      .get();

    if (q.empty) {
      console.log('No expired pending bookings found.');
      return res.status(200).send('No expired pending bookings.');
    }

    const batches = [];
    let currentBatch = db.batch();
    let opsInCurrent = 0;
    let processed = 0;

    for (const doc of q.docs) {
      try {
        const booking = doc.data() || {};
        const tripId = booking.tripId;
        const seatIndexes = Array.isArray(booking.seatIndexes) ? booking.seatIndexes : [];
        const bookedSeatsCount = Number(booking.bookedSeatsCount || 0);

        currentBatch.update(doc.ref, {
          bookingStatus: 'cancelled',
          canceledAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: 'cron_http',
        });
        opsInCurrent++;

        if (tripId) {
          const tripRef = db.collection('trips').doc(tripId);
          const tripSnap = await tripRef.get();
          if (!tripSnap.exists) {
            console.warn('Trip not found for tripId:', tripId, 'bookingId:', doc.id);
          } else {
            const tripData = tripSnap.data() || {};
            let seatStatus = Array.isArray(tripData.seatStatus)
              ? tripData.seatStatus.slice()
              : new Array(Number(tripData.totalSeats || 0)).fill(true);

            if (seatIndexes.length > 0) {
              for (const idx of seatIndexes) {
                if (typeof idx === 'number' && idx >= 0 && idx < seatStatus.length) {
                  seatStatus[idx] = true;
                }
              }
            } else {
              let released = 0;
              for (let i = 0; i < seatStatus.length && released < bookedSeatsCount; i++) {
                if (seatStatus[i] === false) {
                  seatStatus[i] = true;
                  released++;
                }
              }
            }

            currentBatch.update(tripRef, {
              seatStatus,
              availableSeats: admin.firestore.FieldValue.increment(bookedSeatsCount),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            opsInCurrent++;
          }
        }

        processed++;
      } catch (docErr) {
        console.error('Error processing booking doc', doc.id, docErr);
      }

      if (opsInCurrent >= 450) {
        batches.push(currentBatch);
        currentBatch = db.batch();
        opsInCurrent = 0;
      }
    }

    if (opsInCurrent > 0) {
      batches.push(currentBatch);
    }

    try {
      await commitBatchInChunks(batches);
      console.log('All batches committed. processed:', processed, 'batches:', batches.length);
    } catch (commitErr) {
      console.error('Batch commit failed:', commitErr);
      return res.status(500).send('Failed to commit updates');
    }

    return res.status(200).send(`Expired bookings processed. Count: ${processed}`);
  } catch (err) {
    console.error('expirePendingBookingsHttp error:', err);
    return res.status(500).send('Internal error');
  }
});
