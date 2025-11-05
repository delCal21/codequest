// Usage: node migrate_firestore_to_auth.js
// Make sure you have set up Firebase Admin SDK credentials.

const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const firestore = admin.firestore();
const auth = admin.auth();

function generateTempPassword(length = 12) {
  return crypto.randomBytes(length).toString('base64').slice(0, length);
}

async function getFirestoreUsers() {
  const usersSnapshot = await firestore.collection('users').get();
  return usersSnapshot.docs.map(doc => ({
    uid: doc.id,
    email: doc.data().email,
    role: doc.data().role,
    name: doc.data().name || doc.data().fullName || '',
  }));
}

async function getAuthUsers() {
  const users = [];
  let nextPageToken;
  do {
    const result = await auth.listUsers(1000, nextPageToken);
    users.push(...result.users.map(u => ({ uid: u.uid, email: u.email })));
    nextPageToken = result.pageToken;
  } while (nextPageToken);
  return users;
}

(async () => {
  const firestoreUsers = await getFirestoreUsers();
  const authUsers = await getAuthUsers();
  const authEmails = new Set(authUsers.map(u => u.email));

  const missingInAuth = firestoreUsers.filter(u => u.email && !authEmails.has(u.email));

  if (missingInAuth.length === 0) {
    console.log('All Firestore users are present in Firebase Auth.');
    return;
  }

  console.log(`Migrating ${missingInAuth.length} users to Firebase Auth...`);

  for (const user of missingInAuth) {
    try {
      const tempPassword = generateTempPassword();
      const createdUser = await auth.createUser({
        uid: user.uid,
        email: user.email,
        emailVerified: false,
        password: tempPassword,
        displayName: user.name,
        disabled: false,
      });
      // Send password reset email
      await auth.generatePasswordResetLink(user.email);
      console.log(`Created and sent reset link to: ${user.email}`);
    } catch (e) {
      console.error(`Failed to create/send reset for ${user.email}:`, e.message);
    }
  }

  console.log('Migration complete.');
})(); 