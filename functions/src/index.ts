import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

export const expirePendingBookingsHttp = functions.https.onRequest(async (req, res) => {
    try {
        const now = admin.firestore.Timestamp.now();

        // 1. البحث عن الحجوزات التي انتهت مدتها ولم يتم تأكيدها
        const expiredBookingsSnapshot = await db.collection('bookings')
            .where('bookingStatus', '==', 'pending')
            .where('reservedUntil', '<', now)
            .get();

        if (expiredBookingsSnapshot.empty) {
            res.status(200).send('لا توجد حجوزات منتهية الصلاحية.');
            return;
        }

        const batch = db.batch();

        for (const doc of expiredBookingsSnapshot.docs) {
            const booking = doc.data();
            const bookingId = doc.id;
            const tripId = booking.tripId;
            const seatNumber = booking.seatNumber; // نفترض أن الحجز يحمل رقم المقعد

            // 2. إلغاء الحجز
            batch.update(doc.ref, {
                bookingStatus: 'cancelled',
                updatedAt: now
            });

            // 3. تحديث الرحلة لإعادة المقعد (إلغاء الحجز في array seatStatus)
            const tripRef = db.collection('trips').doc(tripId);
            const tripDoc = await tripRef.get();

            if (tripDoc.exists) {
                const tripData = tripDoc.data();
                if (tripData && tripData.seatStatus) {
                    const newSeatStatus = [...tripData.seatStatus];
                    // نعتبر المقاعد تبدأ من index 0 (تأكد من تطبيقك إذا كنت تستخدم index 0 أو 1)
                    newSeatStatus[seatNumber - 1] = true; // إعادة المقعد للحالة "متاح" (true)

                    batch.update(tripRef, {
                        seatStatus: newSeatStatus,
                        availableSeats: admin.firestore.FieldValue.increment(1)
                    });
                }
            }
        }

        // تنفيذ العمليات دفعة واحدة
        await batch.commit();
        res.status(200).send(`تم إلغاء ${expiredBookingsSnapshot.size} حجز بنجاح.`);

    } catch (error) {
        console.error('خطأ في إيقاف الحجوزات:', error);
        res.status(500).send('حدث خطأ داخلي.');
    }
});