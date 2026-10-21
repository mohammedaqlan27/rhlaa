🗄️ DATABASE_SCHEMA.md
RHLAA Platform Database Schema
Overview
This document describes the Firestore database structure used by the RHLAA Platform.

All collections follow the project's official naming convention:

camelCase
Legacy snake_case fields are supported only for backward compatibility.

Collections
users
vehicles
trips
bookings
payments
ratings
notifications
agencies
agency_transactions
gov_fees
user_notification_preferences
users
Stores all user accounts.

Supported User Types
passenger
driver
agency
admin
security
Schema
Field	Type
uid	String
name	String
nickname	String
email	String
userType	String
averageRating	double
ratingCount	int
mobileNumber	String
profilePictureUrl	String
familyStatus	bool
childrenCount	int
isIdVerified	bool
identityCardUrl	String
documents	Map<String,dynamic>
createdAt	Timestamp
updatedAt	Timestamp
isDriver	bool
drivingLicenseNumber	String
plateNumber	String
carOwnerOfficialName	String
driverNotes	String
vehicleIds	List
isActiveDriver	bool
agencyName	String
agencyVerified	bool
agencyVehicles	List
walletBalance	double
vehicles
Stores registered vehicles.

Schema
Field	Type
plateNumber	String
vehicleOwner	String
ownerId	String
driverId	String
vehicleType	String
makeModelYear	String
color	String
maxCapacity	int
licenseNumber	String
isVerified	bool
notes	String
extra	Map<String,dynamic>
createdAt	Timestamp
updatedAt	Timestamp
trips
Stores trip information.

Schema
Field	Type
id	String
driverId	String
driverName	String
title	String
origin	String
destination	String
distanceKm	double
govFeeAmount	double
totalSeats	int
availableSeats	int
seatStatus	List
price	double
date	Timestamp
departureTime	Timestamp
time	String
carPlateNumber	String
description	String
manifestUrl	String
manifestStoragePath	String
manifestGeneratedAt	Timestamp
status	String
createdAt	Timestamp
updatedAt	Timestamp
bookings
Stores passenger reservations.

Schema
Field	Type
tripId	String
passengerId	String
passengerNickname	String
driverId	String
bookedSeatsCount	int
totalPrice	double
isFamilyBooking	bool
childrenCount	int
bookingStatus	String
paymentStatus	String
notes	String
seatIndexes	List
reservedUntil	Timestamp
paymentIntentId	String
transactionId	String
amountPaid	double
paidAt	Timestamp
canceledAt	Timestamp
createdAt	Timestamp
updatedAt	Timestamp
payments
Stores payment records.

Schema
Field	Type
bookingId	String
passengerId	String
driverId	String
agencyId	String
amount	double
currency	String
paymentMethod	String
transactionId	String
status	String
split	Map<String,dynamic>
rawProviderResponse	Map<String,dynamic>
refundReason	String
createdAt	Timestamp
updatedAt	Timestamp
refundedAt	Timestamp
ratings
Stores trip ratings.

Schema
Field	Type
tripId	String
bookingId	String
fromUserId	String
toUserId	String
score	double
rating	String
comment	String
note	String
createdAt	Timestamp
updatedAt	Timestamp
notifications
Stores user notifications.

Schema
Field	Type
userId	String
title	String
body	String
type	String
metadata	Map<String,dynamic>
isRead	bool
createdAt	Timestamp
updatedAt	Timestamp
agencies
Stores transportation agencies.

Schema
Field	Type
agencyName	String
managerName	String
mobileNumber	String
location	GeoPoint / Map
walletBalance	double
isActive	bool
createdAt	Timestamp
updatedAt	Timestamp
agency_transactions
Stores agency financial transactions.

Schema
Field	Type
agencyId	String
amount	double
type	String
reason	String
performedBy	String
createdAt	Timestamp
gov_fees
Government fee rules.

Schema
Field	Type
origin	String
destination	String
distanceKm	double
amount	double
fixedAmount	double
user_notification_preferences
Stores notification settings.

Schema
Field	Type
userId	String
pushEnabled	bool
bookingNotifications	bool
paymentNotifications	bool
marketingNotifications	bool
updatedAt	Timestamp
Naming Convention
Official project standard:

camelCase
Examples:

✅ averageRating

✅ bookingStatus

✅ paymentMethod

✅ driverNetAmount

❌ average_rating

❌ booking_status

❌ payment_method

Legacy fields remain supported only for migration purposes.