🔒 FIRESTORE_RULES.md
RHLAA Platform Security Rules Documentation
Overview
The RHLAA Platform uses Firebase Firestore Security Rules to enforce authentication, authorization, ownership validation, and role-based access control.

The security model is designed around the following user roles:

passenger
driver
agency
security
admin
Role Definitions
Passenger
Can:

Read available trips
Create bookings
Receive notifications
Create ratings
Manage personal profile
Cannot:

Delete payments
Modify other users
Modify unrelated trips
Driver
Can:

Manage own profile
Create trips
Manage vehicles
Manage own bookings
Access passenger manifests
Requires:

isDriver == true

AND

isIdVerified == true
Agency
Can:

Create and manage agency trips
Manage agency vehicles
Manage agency financial operations
Cannot:

Access unrelated agencies
Security
Can:

Read passenger information
Read booking information
Verify manifests
Cannot:

Create trips
Create payments
Admin
Has full system access.

Read
Create
Update
Delete
across all collections.

Authentication Requirement
Most operations require:

request.auth != null
Anonymous users have no access.

User Protection
Protected fields:

uid
id
createdAt
walletBalance
Users cannot modify these fields directly.

Trip Rules
Create Trip:

Allowed for:

Verified Drivers
OR
Agencies
Requirements:

Identity Verified

Valid Driver Account

Required Documentation
Booking Rules
Create Booking:

Allowed only when:

Passenger Account

Authenticated

Identity Available
Passenger must be the owner of:

passengerId
Vehicle Rules
Only:

Driver
Agency
can create or modify vehicles.

Payment Rules
Payments support:

Wallet
QR
Deep Link
Sandbox
Creation rules validate:

amount

transactionId
Updates are blocked from clients.

Recommended source:

Cloud Functions
Notifications Rules
Users may only:

Read Own Notifications

Update Own Notifications
Based on:

userId == request.auth.uid
Agency Rules
Agencies are isolated.

One agency cannot access:

Other Agency Financial Data
Agency transactions are intended to be generated from trusted backend services.

Government Fees Rules
Only administrators may:

Create
Update
Delete
government fee records.

All authenticated users may read them.

Default Security Policy
The project uses:

Default Deny
Policy.

Fallback rule:

match /{document=**} {
allow read, write: if false;
}
Any resource that is not explicitly allowed is automatically denied.

Security Features
Implemented protections:

✅ Authentication Validation

✅ Role Based Access Control (RBAC)

✅ Booking Ownership Validation

✅ Driver Verification

✅ Vehicle Ownership Validation

✅ Agency Isolation

✅ Notification Ownership Validation

✅ Protected Fields

✅ Payment Restrictions

✅ Government Fee Protection

✅ Default Deny Strategy

Production Recommendations
Before national deployment:

Add Custom Claims Management
Add Audit Logging
Add Cloud Functions Validation
Add Fraud Detection
Add Payment Provider Verification
Add Abuse Monitoring
Add Security Monitoring Dashboards
Add Automated Rule Testing
Security Status
Current Assessment:

Development: Ready

Beta: Ready

Production: Good

National Scale: Requires Monitoring, Auditing, and Cloud Functions Hardening