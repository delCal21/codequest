import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/domain/repositories/challenges_repository.dart';
import 'package:codequest/services/activity_service.dart';
import 'package:codequest/features/admin/domain/models/activity_model.dart';

class ChallengesRepositoryImpl implements ChallengesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
// final ActivityService _activityService = ActivityService();

  ChallengesRepositoryImpl(this._firestore);

  @override
  Future<List<ChallengeModel>> getChallenges({
    String? difficulty,
    String? category,
  }) async {
    try {
      Query query = _firestore.collection('challenges');

      if (difficulty != null && difficulty != 'All') {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      if (category != null && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) =>
                ChallengeModel.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get challenges: $e');
    }
  }

  @override
  Future<ChallengeModel> getChallenge(String id) async {
    try {
      final doc = await _firestore.collection('challenges').doc(id).get();
      if (!doc.exists) {
        throw Exception('Challenge not found');
      }
      return ChallengeModel.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get challenge: $e');
    }
  }

  @override
  Future<void> createChallenge(ChallengeModel challenge) async {
    try {
      final docRef =
          await _firestore.collection('challenges').add(challenge.toJson());
      // Update the document with its own ID
      await docRef.update({'id': docRef.id});

      // Log the activity
      await ActivityService.logChallengeActivity(
        activityType: ActivityType.challengeCreated,
        challengeId: docRef.id,
        challengeTitle: challenge.title,
        courseId: challenge.courseId,
      );
    } catch (e) {
      throw Exception('Failed to create challenge: $e');
    }
  }

  @override
  Future<void> updateChallenge(ChallengeModel challenge) async {
    try {
      // Get the old challenge data for comparison
      final oldDoc =
          await _firestore.collection('challenges').doc(challenge.id).get();
      final oldData = oldDoc.data() as Map<String, dynamic>?;

      await _firestore
          .collection('challenges')
          .doc(challenge.id)
          .update(challenge.toJson());

      // Log the activity
      await ActivityService.logChallengeActivity(
        activityType: ActivityType.challengeUpdated,
        challengeId: challenge.id,
        challengeTitle: challenge.title,
        courseId: challenge.courseId,
      );
    } catch (e) {
      throw Exception('Failed to update challenge: $e');
    }
  }

  @override
  Future<void> deleteChallenge(String id) async {
    try {
      // Get challenge data before deletion for activity logging
      final challengeDoc =
          await _firestore.collection('challenges').doc(id).get();
      final challengeData = challengeDoc.data();

      await _firestore.collection('challenges').doc(id).delete();

      // Log the activity
      if (challengeData != null) {
        await ActivityService.logChallengeActivity(
          activityType: ActivityType.challengeDeleted,
          challengeId: id,
          challengeTitle: challengeData['title'] ?? 'Unknown Challenge',
          courseId: challengeData['courseId'],
        );
      }
    } catch (e) {
      throw Exception('Failed to delete challenge: $e');
    }
  }

  Future<List<ChallengeModel>> getChallengesByUser(String userId) async {
    final snapshot = await _firestore
        .collection('challenges')
        .where('assignedTo', isEqualTo: userId) // Use your actual user field
        .get();
    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  Future<List<ChallengeModel>> getChallengesByLesson(int lesson) async {
    try {
      final snapshot = await _firestore
          .collection('challenges')
          .where('lesson', isEqualTo: lesson)
          .get();
      return snapshot.docs
          .map((doc) => ChallengeModel.fromJson(doc.data()..['id'] = doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get challenges by lesson: $e');
    }
  }
}
