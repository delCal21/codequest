const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

let app;
if (!admin.apps.length) {
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} else {
  app = admin.app();
}

const db = admin.firestore();

async function fixFillInTheBlankChallenges() {
  const challengesRef = db.collection('challenges');
  const snapshot = await challengesRef.where('type', '==', 'fillInTheBlank').get();

  if (snapshot.empty) {
    console.log('No fill-in-the-blank challenges found.');
    return;
  }

  const batch = db.batch();
  snapshot.forEach(doc => {
    const data = doc.data();
    if (Array.isArray(data.blanks) && data.blanks.length > 0) {
      batch.update(doc.ref, { correctAnswers: data.blanks });
    }
  });

  await batch.commit();
  console.log('All fill-in-the-blank challenges updated!');
}

fixFillInTheBlankChallenges();