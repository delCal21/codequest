const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Update this path if needed

let app;
if (!admin.apps.length) {
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} else {
  app = admin.app();
}

const db = admin.firestore();

async function fixForums() {
  const snapshot = await db.collection('forums').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const update = {};
    if (typeof data.likes === 'number') update.likes = [];
    if (typeof data.shares === 'number') update.shares = [];
    if (Object.keys(update).length > 0) {
      console.log(`Fixing ${doc.id}:`, update);
      await doc.ref.update(update);
    }
  }
  console.log('Done!');
}

fixForums(); 