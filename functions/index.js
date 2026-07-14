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

/* ------------------------------------------------------------------
   Additional notification functions:
   - sendNotificationToUser (callable)
   - processScheduledNotifications (scheduled)
   These functions integrate with the notification system:
   - reads tokens from users/{uid}/fcmTokens/{token}
   - creates notification docs in notifications collection (when scheduled)
   - sends FCM payloads and cleans invalid tokens
   ------------------------------------------------------------------ */

/**
 * Helper: getUserTokens
 * Returns array of token strings for a given userId
 */
async function getUserTokens(userId) {
  try {
    const tokensSnap = await db.collection('users').doc(userId).collection('fcmTokens').get();
    return tokensSnap.docs.map(d => d.id).filter(Boolean);
  } catch (err) {
    console.error('getUserTokens error for', userId, err);
    return [];
  }
}

/**
 * Callable: sendNotificationToUser
 * Expects: { userId, title, body, data, notificationId }
 * Sends FCM to all tokens under users/{userId}/fcmTokens/{token}
 */
exports.sendNotificationToUser = functions.https.onCall(async (data, context) => {
  const payloadData = data || {};
  const userId = payloadData.userId;
  const title = payloadData.title;
  const body = payloadData.body;
  const extraData = payloadData.data || {};
  const notificationId = payloadData.notificationId || '';

  if (!userId || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing userId/title/body');
  }

  const tokens = await getUserTokens(userId);
  if (!tokens.length) {
    console.log('No FCM tokens for user:', userId);
    return { success: false, reason: 'no_tokens' };
  }

  const message = {
    notification: { title: String(title), body: String(body) },
    data: Object.assign({}, extraData, { notificationId: String(notificationId) }),
  };

  try {
    const res = await admin.messaging().sendToDevice(tokens, message);
    // Collect invalid tokens to remove
    const tokensToRemove = [];
    res.results.forEach((r, i) => {
      const err = r.error;
      if (err) {
        const token = tokens[i];
        if (err.code === 'messaging/invalid-registration-token' || err.code === 'messaging/registration-token-not-registered') {
          tokensToRemove.push(token);
        } else {
          console.warn('FCM send error for token', tokens[i], err.code, err.message);
        }
      }
    });

    if (tokensToRemove.length) {
      const batch = db.batch();
      tokensToRemove.forEach(t => {
        const ref = db.collection('users').doc(userId).collection('fcmTokens').doc(t);
        batch.delete(ref);
      });
      await batch.commit();
      console.log('Removed invalid tokens for user', userId, tokensToRemove.length);
    }

    return { success: true, sent: res.successCount, failed: res.failureCount };
  } catch (err) {
    console.error('sendNotificationToUser error', err);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

/**
 * Scheduled: processScheduledNotifications
 * Runs every minute, processes scheduled_notifications where sendAt <= now and sent == false
 */
exports.processScheduledNotifications = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();
  try {
    const snaps = await db
      .collection('scheduled_notifications')
      .where('sendAt', '<=', now)
      .where('sent', '==', false)
      .limit(50)
      .get();

    if (snaps.empty) {
      // nothing to do
      return null;
    }

    for (const doc of snaps.docs) {
      const data = doc.data() || {};
      try {
        // create notification doc in notifications collection
        const notifRef = await db.collection('notifications').add({
          userId: data.userId,
          title: data.title,
          body: data.body,
          type: data.type || 'scheduled',
          metadata: data.metadata || {},
          isRead: false,
          sendNotification: data.sendNotification !== false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // send push if requested
        if (data.sendNotification !== false) {
          try {
            // call the callable function logic directly to send FCM
            // reuse sendNotificationToUser implementation by invoking it programmatically
            // but since onCall wrapper expects HTTPS callable, we call the internal helper instead:
            const tokens = await getUserTokens(data.userId);
            if (tokens.length) {
              const message = {
                notification: { title: String(data.title), body: String(data.body) },
                data: Object.assign({}, data.metadata || {}, { notificationId: notifRef.id }),
              };
              const res = await admin.messaging().sendToDevice(tokens, message);
              // remove invalid tokens
              const tokensToRemove = [];
              res.results.forEach((r, i) => {
                const err = r.error;
                if (err) {
                  const token = tokens[i];
                  if (err.code === 'messaging/invalid-registration-token' || err.code === 'messaging/registration-token-not-registered') {
                    tokensToRemove.push(token);
                  }
                }
              });
              if (tokensToRemove.length) {
                const batch = db.batch();
                tokensToRemove.forEach(t => {
                  const ref = db.collection('users').doc(data.userId).collection('fcmTokens').doc(t);
                  batch.delete(ref);
                });
                await batch.commit();
              }
            } else {
              console.log('No tokens to send scheduled notification for user', data.userId);
            }
          } catch (sendErr) {
            console.error('Failed to send scheduled push for doc', doc.id, sendErr);
          }
        }

        // mark scheduled doc as sent
        await doc.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
      } catch (docErr) {
        console.error('Error processing scheduled notification doc', doc.id, docErr);
        // continue with next doc
      }
    }
  } catch (err) {
    console.error('processScheduledNotifications error', err);
  }

  return null;
});
