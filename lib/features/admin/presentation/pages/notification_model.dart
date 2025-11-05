import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  // Full raw document data for richer detail rendering
  final Map<String, dynamic> data;

  AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.data = const {},
  });

  factory AdminNotification.fromMap(String id, Map<String, dynamic> data) {
    final type = (data['type'] as String?) ?? '';
    return AdminNotification(
      id: id,
      title: (data['title'] as String?) ?? _deriveTitleFromType(type),
      message: (data['message'] as String?) ?? _generateMessage(data, type),
      timestamp: (data['timestamp'] is DateTime)
          ? data['timestamp']
          : (data['timestamp'] is Timestamp)
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
      isRead: (data['read'] as bool?) ?? false,
      data: Map<String, dynamic>.from(data),
    );
  }

  static String _generateMessage(Map<String, dynamic> data, String type) {
    // Generate professional, contextual messages based on notification type
    switch (type) {
      case 'course_created':
        final teacherName = data['teacherName'] as String? ?? 'Unknown Teacher';
        return 'A new course has been created by $teacherName';

      case 'course_updated':
        final teacherName = data['teacherName'] as String? ?? 'Unknown Teacher';
        return 'Course content has been modified by $teacherName';

      case 'course_deleted':
        final teacherName = data['teacherName'] as String? ?? 'Unknown Teacher';
        return 'Course has been removed by $teacherName';

      case 'challenge_created':
        final courseTitle = data['courseTitle'] as String?;
        if (courseTitle != null) {
          return 'A new challenge has been added to the course';
        }
        return 'A new challenge has been created';

      case 'challenge_submitted':
        return 'A student has submitted their solution';

      case 'challenge_completed':
        return 'A student has successfully completed this challenge';

      case 'forum_post_created':
        return 'A new discussion has been started';

      case 'video_uploaded':
        final courseTitle = data['courseTitle'] as String?;
        if (courseTitle != null) {
          return 'New video content has been added to the course';
        }
        return 'A new video has been uploaded';

      case 'user_registered':
        return 'A new user has joined the platform';

      case 'challenge_deleted':
        return 'A challenge has been removed from the system';

      case 'video_deleted':
        return 'A video has been removed from the system';

      default:
        // Generic message for unknown types
        if (type.isNotEmpty) {
          return 'A system event has occurred';
        }
        return 'New notification received';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      ...data,
    };
  }

  static String _deriveTitleFromType(dynamic type) {
    final t = (type as String?) ?? '';
    if (t.isEmpty) return 'Notification';

    // Professional title mappings
    const titleMap = {
      'course_created': 'Course Created',
      'course_updated': 'Course Updated',
      'course_deleted': 'Course Removed',
      'challenge_created': 'Challenge Created',
      'challenge_submitted': 'Challenge Submission',
      'challenge_completed': 'Challenge Completed',
      'challenge_deleted': 'Challenge Removed',
      'forum_post_created': 'Forum Post',
      'video_uploaded': 'Video Uploaded',
      'video_deleted': 'Video Removed',
      'user_registered': 'New Registration',
    };

    if (titleMap.containsKey(t)) {
      return titleMap[t]!;
    }

    // Fallback: format generic type names
    return t
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
        .join(' ');
  }
}
