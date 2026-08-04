const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { stringify } = require('csv-stringify/sync');

admin.initializeApp();

// مراجع سريعة
const db = admin.firestore();
const agenciesCol = db.collection('agencies');
const transactionsCol = db.collection('agency_transactions');
const paymentsCol = db.collection('payments');

/**
 * Helpers
 */
function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }
}

function hasRole(context, role) {
  return context.auth && context.auth.token && context.auth.token.role === role;
}

/**
 * createAgencySafe
 * Callable function: ينشئ مكتبًا جديدًا داخل Transaction ويتحقق من عدم تكرار رقم الهاتف.
 * متطلبات: المستدعي يجب أن يكون admin.
 */
exports.createAgencySafe = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  if (!hasRole(context, 'admin')) {
    throw new functions.https.HttpsError('permission-denied', 'Only admin can create agencies.');
  }

  const { agencyName, managerName, location = null, mobileNumber, initialBalance = 0.0, isActive = true, ownerId = null } = data || {};

  if (!agencyName || !mobileNumber) {
    throw new functions.https.HttpsError('invalid-argument', 'agencyName and mobileNumber are required.');
  }

  const normalizedMobile = mobileNumber.toString().trim();

  try {
    const result = await db.runTransaction(async (tx) => {
      const q = await tx.get(agenciesCol.where('mobileNumber', '==', normalizedMobile).limit(1));
      if (!q.empty) {
        throw new functions.https.HttpsError('already-exists', 'Mobile number already registered for another agency.');
      }

      const now = admin.firestore.Timestamp.now();
      const docRef = agenciesCol.doc();
      const payload = {
        agencyName,
        managerName,
        location,
        mobileNumber: normalizedMobile,
        walletBalance: Number(initialBalance) || 0.0,
        isActive: !!isActive,
        createdAt: now,
        updatedAt: now,
        searchKey: agencyName.toLowerCase(),
        ownerId: ownerId || null
      };

      tx.set(docRef, payload);
      return { id: docRef.id, ...payload };
    });

    return { success: true, agency: result };
  } catch (err) {
    functions.logger.error('createAgencySafe failed', err);
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('internal', 'Failed to create agency');
  }
});

/**
 * creditAgency
 * Callable function: يشحن محفظة المكتب ويُسجّل معاملة في agency_transactions.
 * صلاحية: admin أو صاحب المكتب نفسه (role 'agency' ويطابق ownerId).
 */
exports.creditAgency = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const callerUid = context.auth.uid;
  const callerRole = context.auth.token && context.auth.token.role;

  const { agencyId, amount, reason = 'Manual credit' } = data || {};
  if (!agencyId || !amount || Number(amount) <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'agencyId and positive amount are required.');
  }

  try {
    // صلاحية: admin أو صاحب المكتب نفسه
    if (callerRole === 'admin') {
      // ok
    } else if (callerRole === 'agency') {
      const agencySnap = await agenciesCol.doc(agencyId).get();
      if (!agencySnap.exists) throw new functions.https.HttpsError('not-found', 'Agency not found.');
      const agencyData = agencySnap.data();
      if (agencyData.ownerId !== callerUid) {
        throw new functions.https.HttpsError('permission-denied', 'Agency user is not owner of this agency.');
      }
    } else {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized to credit agency.');
    }

    const res = await db.runTransaction(async (tx) => {
      const agencyRef = agenciesCol.doc(agencyId);
      const snap = await tx.get(agencyRef);
      if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Agency not found.');

      const dataSnap = snap.data();
      const currentBalance = Number(dataSnap.walletBalance || 0);
      const newBalance = currentBalance + Number(amount);

      tx.update(agencyRef, {
        walletBalance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const txDoc = transactionsCol.doc();
      const txPayload = {
        id: txDoc.id,
        agencyId,
        amount: Number(amount),
        type: 'credit',
        reason,
        performedBy: callerUid || 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        oldBalance: currentBalance,
        newBalance,
      };
      tx.set(txDoc, txPayload);

      return txPayload;
    });

    return { success: true, transaction: res };
  } catch (err) {
    functions.logger.error('creditAgency failed', err);
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('internal', 'Failed to credit agency');
  }
});

/**
 * debitAgency
 * Callable function: يخصم من محفظة المكتب بعد التحقق من كفاية الرصيد.
 */
exports.debitAgency = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const callerUid = context.auth.uid;
  const callerRole = context.auth.token && context.auth.token.role;

  const { agencyId, amount, reason = 'Manual debit' } = data || {};
  if (!agencyId || !amount || Number(amount) <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'agencyId and positive amount are required.');
  }

  try {
    // صلاحية: admin أو صاحب المكتب نفسه
    if (callerRole === 'admin') {
      // ok
    } else if (callerRole === 'agency') {
      const agencySnap = await agenciesCol.doc(agencyId).get();
      if (!agencySnap.exists) throw new functions.https.HttpsError('not-found', 'Agency not found.');
      const agencyData = agencySnap.data();
      if (agencyData.ownerId !== callerUid) {
        throw new functions.https.HttpsError('permission-denied', 'Agency user is not owner of this agency.');
      }
    } else {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized to debit agency.');
    }

    const res = await db.runTransaction(async (tx) => {
      const agencyRef = agenciesCol.doc(agencyId);
      const snap = await tx.get(agencyRef);
      if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Agency not found.');

      const dataSnap = snap.data();
      const currentBalance = Number(dataSnap.walletBalance || 0);
      if (currentBalance < Number(amount)) {
        throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance.');
      }
      const newBalance = currentBalance - Number(amount);

      tx.update(agencyRef, {
        walletBalance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const txDoc = transactionsCol.doc();
      const txPayload = {
        id: txDoc.id,
        agencyId,
        amount: Number(amount),
        type: 'debit',
        reason,
        performedBy: callerUid || 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        oldBalance: currentBalance,
        newBalance,
      };
      tx.set(txDoc, txPayload);

      return txPayload;
    });

    return { success: true, transaction: res };
  } catch (err) {
    functions.logger.error('debitAgency failed', err);
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('internal', 'Failed to debit agency');
  }
});

/**
 * exportTransactions
 * Callable function that returns CSV of transactions for an agency between dates.
 * For large exports: يفضل رفع الملف إلى Cloud Storage وإرجاع رابط موقّع.
 */
exports.exportTransactions = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const callerRole = context.auth.token && context.auth.token.role;
  const callerUid = context.auth.uid;

  const { agencyId, fromTs, toTs } = data || {};
  if (!agencyId) throw new functions.https.HttpsError('invalid-argument', 'agencyId is required.');

  // Authorization: admin or agency owner
  if (!(callerRole === 'admin' || callerRole === 'agency')) {
    throw new functions.https.HttpsError('permission-denied', 'Not authorized to export transactions.');
  }

  try {
    if (callerRole === 'agency') {
      const agencySnap = await agenciesCol.doc(agencyId).get();
      if (!agencySnap.exists) throw new functions.https.HttpsError('not-found', 'Agency not found.');
      const agencyData = agencySnap.data();
      if (agencyData.ownerId !== callerUid) {
        throw new functions.https.HttpsError('permission-denied', 'Agency user is not owner of this agency.');
      }
    }

    const from = fromTs ? admin.firestore.Timestamp.fromMillis(Number(fromTs)) : admin.firestore.Timestamp.fromMillis(0);
    const to = toTs ? admin.firestore.Timestamp.fromMillis(Number(toTs)) : admin.firestore.Timestamp.now();

    const snap = await transactionsCol
      .where('agencyId', '==', agencyId)
      .where('createdAt', '>=', from)
      .where('createdAt', '<=', to)
      .orderBy('createdAt', 'desc')
      .get();

    const rows = snap.docs.map((d) => {
      const dt = d.data();
      return {
        id: dt.id,
        agencyId: dt.agencyId,
        type: dt.type,
        amount: dt.amount,
        reason: dt.reason,
        performedBy: dt.performedBy,
        createdAt: dt.createdAt ? dt.createdAt.toDate().toISOString() : '',
        oldBalance: dt.oldBalance,
        newBalance: dt.newBalance,
      };
    });

    const csv = stringify(rows, { header: true });
    return { success: true, csv };
  } catch (err) {
    functions.logger.error('exportTransactions failed', err);
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('internal', 'Failed to export transactions');
  }
});

/**
 * setUserRole
 * Callable function آمنة لتعيين custom claims (roles) للمستخدمين.
 * المستدعي يجب أن يكون admin داخل التطبيق.
 */
exports.setUserRole = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const callerRole = context.auth.token && context.auth.token.role;
  if (callerRole !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can set roles');
  }

  const { uid, role } = data || {};
  if (!uid || !role) throw new functions.https.HttpsError('invalid-argument', 'uid and role are required');

  const allowedRoles = ['admin', 'agency', 'gov', 'driver', 'passenger', 'security'];
  if (!allowedRoles.includes(role)) throw new functions.https.HttpsError('invalid-argument', 'role not allowed');

  try {
    await admin.auth().setCustomUserClaims(uid, { role });
    await db.collection('role_changes').add({
      uid,
      role,
      changedBy: context.auth.uid,
      changedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    return { success: true, uid, role };
  } catch (err) {
    functions.logger.error('setUserRole failed', err);
    throw new functions.https.HttpsError('internal', 'Failed to set role');
  }
});
