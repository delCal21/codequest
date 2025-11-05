import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/admin/domain/models/activity_model.dart';

class ActivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log a teacher activity
  static Future<void> logActivity({
    required ActivityType activityType,
    required EntityType entityType,
    required String entityId,
    required String entityTitle,
    required String description,
    String? courseId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get teacher name
      String teacherName = 'Unknown Teacher';
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          teacherName = userData['fullName'] ??
              userData['name'] ??
              userData['displayName'] ??
              user.email ??
              'Unknown Teacher';
        }
      } catch (e) {
        print('Error getting teacher name: $e');
      }

      final activity = ActivityModel(
        id: '', // Will be set by Firestore
        teacherId: user.uid,
        teacherName: teacherName,
        activityType: activityType,
        entityType: entityType,
        entityId: entityId,
        entityTitle: entityTitle,
        description: description,
        timestamp: DateTime.now(),
        metadata: metadata,
        courseId: courseId,
      );

      await _firestore.collection('teacher_activities').add(activity.toJson());
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  /// Log course activities
  static Future<void> logCourseActivity({
    required ActivityType activityType,
    required String courseId,
    required String courseTitle,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    String desc = description ??
        _getDefaultDescription(activityType, 'course', courseTitle);

    await logActivity(
      activityType: activityType,
      entityType: EntityType.course,
      entityId: courseId,
      entityTitle: courseTitle,
      description: desc,
      metadata: metadata,
    );
  }

  /// Log challenge activities
  static Future<void> logChallengeActivity({
    required ActivityType activityType,
    required String challengeId,
    required String challengeTitle,
    String? courseId,
    String? courseTitle,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    String desc = description ??
        _getDefaultDescription(
            activityType, 'challenge', challengeTitle, courseTitle);

    await logActivity(
      activityType: activityType,
      entityType: EntityType.challenge,
      entityId: challengeId,
      entityTitle: challengeTitle,
      description: desc,
      courseId: courseId,
      metadata: metadata,
    );
  }

  /// Log video activities
  static Future<void> logVideoActivity({
    required ActivityType activityType,
    required String videoId,
    required String videoTitle,
    String? courseId,
    String? courseTitle,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    String desc = description ??
        _getDefaultDescription(activityType, 'video', videoTitle, courseTitle);

    await logActivity(
      activityType: activityType,
      entityType: EntityType.video,
      entityId: videoId,
      entityTitle: videoTitle,
      description: desc,
      courseId: courseId,
      metadata: metadata,
    );
  }

  /// Log forum activities
  static Future<void> logForumActivity({
    required ActivityType activityType,
    required String forumId,
    required String forumTitle,
    String? courseId,
    String? courseTitle,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    String desc = description ??
        _getDefaultDescription(
            activityType, 'forum post', forumTitle, courseTitle);

    await logActivity(
      activityType: activityType,
      entityType: EntityType.forum,
      entityId: forumId,
      entityTitle: forumTitle,
      description: desc,
      courseId: courseId,
      metadata: metadata,
    );
  }

  /// Get teacher activities
  static Future<List<ActivityModel>> getTeacherActivities({
    required String teacherId,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('teacher_activities')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ActivityModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting teacher activities: $e');
      return [];
    }
  }

  /// Get recent activities for a teacher (including course-related activities)
  static Future<List<ActivityModel>> getRecentTeacherActivities({
    required String teacherId,
    required Set<String> teacherCourseIds,
    int limit = 15,
  }) async {
    try {
      List<ActivityModel> activities = [];

      // Get direct teacher activities
      final teacherActivities =
          await getTeacherActivities(teacherId: teacherId, limit: limit);
      activities.addAll(teacherActivities);

      // Get activities related to teacher's courses (for collaborators)
      if (teacherCourseIds.isNotEmpty) {
        final courseActivities = await _firestore
            .collection('teacher_activities')
            .where('courseId', whereIn: teacherCourseIds.toList())
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();

        final courseActivityModels = courseActivities.docs
            .map((doc) => ActivityModel.fromJson({...doc.data(), 'id': doc.id}))
            .where((activity) =>
                activity.teacherId != teacherId) // Exclude own activities
            .toList();

        activities.addAll(courseActivityModels);
      }

      // Sort by timestamp and limit
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities.take(limit).toList();
    } catch (e) {
      print('Error getting recent teacher activities: $e');
      return [];
    }
  }

  /// Get default description for activity
  static String _getDefaultDescription(
      ActivityType activityType, String entityType, String entityTitle,
      [String? courseTitle]) {
    final action = _getActionText(activityType);
    final courseContext = courseTitle != null ? ' in "$courseTitle"' : '';

    return '$action $entityType "$entityTitle"$courseContext';
  }

  /// Get action text for activity type
  static String _getActionText(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.courseCreated:
      case ActivityType.challengeCreated:
      case ActivityType.videoCreated:
      case ActivityType.forumCreated:
        return 'Created';
      case ActivityType.courseUpdated:
      case ActivityType.challengeUpdated:
      case ActivityType.videoUpdated:
      case ActivityType.forumUpdated:
        return 'Updated';
      case ActivityType.courseDeleted:
      case ActivityType.challengeDeleted:
      case ActivityType.videoDeleted:
      case ActivityType.forumDeleted:
        return 'Deleted';
    }
  }

  /// Get activity icon based on entity type
  static String getActivityIcon(EntityType entityType) {
    switch (entityType) {
      case EntityType.course:
        return '📚';
      case EntityType.challenge:
        return '💻';
      case EntityType.video:
        return '🎥';
      case EntityType.forum:
        return '💬';
    }
  }

  /// Get activity color based on activity type
  static int getActivityColor(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.courseCreated:
      case ActivityType.challengeCreated:
      case ActivityType.videoCreated:
      case ActivityType.forumCreated:
        return 0xFF4CAF50; // Green
      case ActivityType.courseUpdated:
      case ActivityType.challengeUpdated:
      case ActivityType.videoUpdated:
      case ActivityType.forumUpdated:
        return 0xFFFF9800; // Orange
      case ActivityType.courseDeleted:
      case ActivityType.challengeDeleted:
      case ActivityType.videoDeleted:
      case ActivityType.forumDeleted:
        return 0xFFF44336; // Red
    }
  }
}
