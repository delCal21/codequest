import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a teacher notification for collaborator assignment
  static Future<void> notifyTeacherCollaboratorAssignment({
    required String teacherId,
    required String courseId,
    required String courseTitle,
    required String assignedBy,
    required String assignedByName,
    required String role,
  }) async {
    try {
      await _firestore.collection('teacher_notifications').add({
        'teacherId': teacherId,
        'type': 'collaborator_assigned',
        'courseId': courseId,
        'courseTitle': courseTitle,
        'assignedBy': assignedBy,
        'assignedByName': assignedByName,
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'actionRequired': false,
      });
    } catch (e) {
      print('Error creating teacher collaborator notification: $e');
    }
  }

  /// Create a teacher notification for course assignment by admin
  static Future<void> notifyTeacherCourseAssignment({
    required String teacherId,
    required String courseId,
    required String courseTitle,
    required String assignedBy,
    required String assignedByName,
  }) async {
    try {
      await _firestore.collection('teacher_notifications').add({
        'teacherId': teacherId,
        'type': 'course_assigned',
        'courseId': courseId,
        'courseTitle': courseTitle,
        'assignedBy': assignedBy,
        'assignedByName': assignedByName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'actionRequired': true,
      });
    } catch (e) {
      print('Error creating teacher course assignment notification: $e');
    }
  }

  /// Create a teacher notification for course creation
  static Future<void> notifyTeacherCourseCreated({
    required String teacherId,
    required String courseId,
    required String courseTitle,
  }) async {
    try {
      await _firestore.collection('teacher_notifications').add({
        'teacherId': teacherId,
        'type': 'course_created',
        'courseId': courseId,
        'courseTitle': courseTitle,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'actionRequired': false,
      });
    } catch (e) {
      print('Error creating teacher course creation notification: $e');
    }
  }

  /// Create a teacher notification for account creation by admin
  static Future<void> notifyTeacherAccountCreated({
    required String teacherId,
    required String teacherName,
    required String teacherEmail,
    String? courseTitle,
  }) async {
    try {
      await _firestore.collection('teacher_notifications').add({
        'teacherId': teacherId,
        'type': 'account_created',
        'title': 'Welcome to CodeQuest!',
        'message': courseTitle != null
            ? 'Your teacher account has been created by the administrator and you have been assigned to "$courseTitle". Please check your email for login instructions.'
            : 'Your teacher account has been created by the administrator. Please check your email for login instructions.',
        'teacherName': teacherName,
        'teacherEmail': teacherEmail,
        'courseTitle': courseTitle,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'actionRequired': false,
      });
    } catch (e) {
      print('Error creating teacher account creation notification: $e');
    }
  }

  /// Mark teacher notification as read
  static Future<void> markTeacherNotificationAsRead(
      String notificationId) async {
    try {
      await _firestore
          .collection('teacher_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking teacher notification as read: $e');
    }
  }

  /// Get teacher notifications
  static Stream<QuerySnapshot> getTeacherNotifications(String teacherId) {
    return _firestore
        .collection('teacher_notifications')
        .where('teacherId', isEqualTo: teacherId)
        .limit(50)
        .snapshots();
  }

  /// Get unread teacher notifications count
  static Stream<int> getUnreadTeacherNotificationsCount(String teacherId) {
    return _firestore
        .collection('teacher_notifications')
        .where('teacherId', isEqualTo: teacherId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Clear read teacher notifications
  static Future<void> clearReadTeacherNotifications(String teacherId) async {
    try {
      final query = await _firestore
          .collection('teacher_notifications')
          .where('teacherId', isEqualTo: teacherId)
          .where('read', isEqualTo: true)
          .get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing read teacher notifications: $e');
    }
  }

  /// Delete all notifications for a specific teacher
  static Future<void> deleteTeacherNotifications(String teacherId) async {
    try {
      final query = await _firestore
          .collection('teacher_notifications')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting teacher notifications: $e');
    }
  }

  /// Delete course notifications when a course is deleted
  static Future<void> deleteCourseNotifications(String courseId) async {
    try {
      final querySnapshot = await _firestore
          .collection('teacher_notifications')
          .where('courseId', isEqualTo: courseId)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting course notifications: $e');
    }
  }

  // ==================== ADMIN NOTIFICATIONS ====================
  // These methods are kept for backward compatibility with existing admin features

  /// Get admin notifications stream
  static Stream<QuerySnapshot> getAdminNotifications() {
    return _firestore.collection('notifications').snapshots();
  }

  /// Mark admin notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Clear read admin notifications
  static Future<void> clearReadNotifications() async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('read', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing read notifications: $e');
    }
  }

  /// Create admin notification for course events
  static Future<void> notifyCourseEvent({
    required String type,
    required String courseId,
    required String courseTitle,
    required String teacherId,
    required String teacherName,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error creating course event notification: $e');
    }
  }

  /// Create admin notification for challenge events
  static Future<void> notifyChallengeEvent({
    required String type,
    required String challengeId,
    required String challengeTitle,
    String? courseId,
    String? courseTitle,
    String? userId,
    String? userName,
    Map<String, dynamic>? challengeData,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type,
        'challengeId': challengeId,
        'challengeTitle': challengeTitle,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'userId': userId,
        'userName': userName,
        'challengeData': challengeData,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error creating challenge event notification: $e');
    }
  }

  /// Create admin notification for forum events
  static Future<void> notifyForumEvent({
    required String type,
    required String forumId,
    required String forumTitle,
    required String userId,
    required String userName,
    Map<String, dynamic>? forumData,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type,
        'forumId': forumId,
        'forumTitle': forumTitle,
        'userId': userId,
        'userName': userName,
        'forumData': forumData,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error creating forum event notification: $e');
    }
  }

  /// Create admin notification for video events
  static Future<void> notifyVideoEvent({
    required String type,
    required String videoId,
    required String videoTitle,
    String? courseId,
    String? courseTitle,
    String? userId,
    String? userName,
    Map<String, dynamic>? videoData,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type,
        'videoId': videoId,
        'videoTitle': videoTitle,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'userId': userId,
        'userName': userName,
        'videoData': videoData,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error creating video event notification: $e');
    }
  }
}
