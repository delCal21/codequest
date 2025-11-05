// Usage: node audit_firestore_vs_auth.js
// Make sure you have set up Firebase Admin SDK credentials.

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const firestore = admin.firestore();
const auth = admin.auth();

async function getFirestoreUsers() {
  const usersSnapshot = await firestore.collection('users').get();
  return usersSnapshot.docs.map(doc => ({
    uid: doc.id,
    email: doc.data().email,
    role: doc.data().role,
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
  } else {
    console.log('Users in Firestore but NOT in Firebase Auth:');
    missingInAuth.forEach(u => {
      console.log(`Email: ${u.email}, UID: ${u.uid}, Role: ${u.role}`);
    });
    console.log(`\nTotal missing: ${missingInAuth.length}`);
  }
})(); 