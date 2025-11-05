const admin = require('firebase-admin');

// Path to your service account key JSON file
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Set the real name you want to display for all old 'Teacher' comments
const DEFAULT_TEACHER_NAME = 'Excel V. Cabrera';

async function updateAllTeacherComments() {
  const forumsSnapshot = await db.collection('forums').get();

  for (const forumDoc of forumsSnapshot.docs) {
    const forumData = forumDoc.data();
    let comments = forumData.comments || [];
    let updated = false;

    for (let comment of comments) {
      // Update if it's a teacher comment with 'user' == 'Teacher'
      if (comment.user === 'Teacher') {
        comment.user = DEFAULT_TEACHER_NAME;
        updated = true;
      }
    }

    if (updated) {
      await forumDoc.ref.update({ comments });
      console.log(`Updated comments for forum: ${forumDoc.id}`);
    }
  }
  console.log('Done updating all teacher comment names!');
}

updateAllTeacherComments().catch(console.error);