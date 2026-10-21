// functions/getAgencyTransactions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.getAgencyTransactions = functions.https.onRequest(async (req, res) => {
  try {
    res.set('Access-Control-Allow-Origin', req.get('origin') || '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');

    if (req.method === 'OPTIONS') return res.status(204).send('');

    const authHeader = req.get('Authorization') || req.get('authorization') || '';
    if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Unauthorized: missing Bearer token' });

    const idToken = authHeader.split('Bearer ')[1].trim();
    let decoded;
    try { decoded = await admin.auth().verifyIdToken(idToken); }
    catch (err) { return res.status(401).json({ error: 'Unauthorized: invalid token' }); }

    const agencyId = decoded.uid;

    const { from, to, limit, pageToken } = req.query;
    const pageLimit = Math.min(Math.max(parseInt(limit || '100', 10), 1), 1000);

    let q = db.collection('agency_transactions')
              .where('agencyId', '==', agencyId)
              .orderBy('createdAt', 'desc');

    if (from) {
      const fromDate = new Date(from);
      if (isNaN(fromDate.getTime())) return res.status(400).json({ error: 'Invalid from date' });
      q = q.where('createdAt', '>=', admin.firestore.Timestamp.fromDate(fromDate));
    }
    if (to) {
      const toDate = new Date(to);
      if (isNaN(toDate.getTime())) return res.status(400).json({ error: 'Invalid to date' });
      q = q.where('createdAt', '<=', admin.firestore.Timestamp.fromDate(toDate));
    }
    if (pageToken) {
      const tokenDate = new Date(pageToken);
      if (isNaN(tokenDate.getTime())) return res.status(400).json({ error: 'Invalid pageToken' });
      q = q.startAfter(admin.firestore.Timestamp.fromDate(tokenDate));
    }

    q = q.limit(pageLimit);
    const snap = await q.get();

    const transactions = snap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        amount: data.amount ?? null,
        description: data.reason || data.description || null,
        date: data.createdAt ? data.createdAt.toDate().toISOString() : (data.date || null),
        type: data.type || null,
        transactionId: data.transactionId || null,
      };
    });

    let nextPageToken = null;
    if (snap.docs.length === pageLimit) {
      const last = snap.docs[snap.docs.length - 1].data();
      if (last && last.createdAt) nextPageToken = last.createdAt.toDate().toISOString();
    }

    return res.json({ transactions, nextPageToken });
  } catch (err) {
    console.error('getAgencyTransactions error', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});
