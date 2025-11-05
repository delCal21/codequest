import 'package:flutter_test/flutter_test.dart';
import 'package:codequest/features/admin/domain/models/activity_model.dart';

void main() {
  group('ActivityModel Tests', () {
    test('should create ActivityModel with correct values', () {
      final activity = ActivityModel(
        id: 'test-id',
        teacherId: 'teacher-123',
        teacherName: 'John Doe',
        activityType: ActivityType.courseCreated,
        entityType: EntityType.course,
        entityId: 'course-123',
        entityTitle: 'Test Course',
        description: 'Created course "Test Course"',
        timestamp: DateTime.now(),
        courseId: 'course-123',
      );

      expect(activity.id, equals('test-id'));
      expect(activity.teacherId, equals('teacher-123'));
      expect(activity.teacherName, equals('John Doe'));
      expect(activity.activityType, equals(ActivityType.courseCreated));
      expect(activity.entityType, equals(EntityType.course));
      expect(activity.entityId, equals('course-123'));
      expect(activity.entityTitle, equals('Test Course'));
      expect(activity.description, equals('Created course "Test Course"'));
      expect(activity.courseId, equals('course-123'));
    });

    test('should convert to and from JSON correctly', () {
      final originalActivity = ActivityModel(
        id: 'test-id',
        teacherId: 'teacher-123',
        teacherName: 'John Doe',
        activityType: ActivityType.challengeCreated,
        entityType: EntityType.challenge,
        entityId: 'challenge-123',
        entityTitle: 'Test Challenge',
        description: 'Created challenge "Test Challenge" in "Test Course"',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        courseId: 'course-123',
        metadata: {'difficulty': 'easy'},
      );

      final json = originalActivity.toJson();
      final restoredActivity = ActivityModel.fromJson(json);

      expect(restoredActivity.id, equals(originalActivity.id));
      expect(restoredActivity.teacherId, equals(originalActivity.teacherId));
      expect(
          restoredActivity.teacherName, equals(originalActivity.teacherName));
      expect(
          restoredActivity.activityType, equals(originalActivity.activityType));
      expect(restoredActivity.entityType, equals(originalActivity.entityType));
      expect(restoredActivity.entityId, equals(originalActivity.entityId));
      expect(
          restoredActivity.entityTitle, equals(originalActivity.entityTitle));
      expect(
          restoredActivity.description, equals(originalActivity.description));
      expect(restoredActivity.courseId, equals(originalActivity.courseId));
      expect(restoredActivity.metadata, equals(originalActivity.metadata));
    });

    test('should copy with new values correctly', () {
      final originalActivity = ActivityModel(
        id: 'test-id',
        teacherId: 'teacher-123',
        teacherName: 'John Doe',
        activityType: ActivityType.videoCreated,
        entityType: EntityType.video,
        entityId: 'video-123',
        entityTitle: 'Test Video',
        description: 'Created video "Test Video"',
        timestamp: DateTime.now(),
      );

      final updatedActivity = originalActivity.copyWith(
        activityType: ActivityType.videoUpdated,
        description: 'Updated video "Test Video"',
      );

      expect(updatedActivity.id, equals(originalActivity.id));
      expect(updatedActivity.teacherId, equals(originalActivity.teacherId));
      expect(updatedActivity.teacherName, equals(originalActivity.teacherName));
      expect(updatedActivity.activityType, equals(ActivityType.videoUpdated));
      expect(updatedActivity.entityType, equals(originalActivity.entityType));
      expect(updatedActivity.entityId, equals(originalActivity.entityId));
      expect(updatedActivity.entityTitle, equals(originalActivity.entityTitle));
      expect(updatedActivity.description, equals('Updated video "Test Video"'));
      expect(updatedActivity.timestamp, equals(originalActivity.timestamp));
    });
  });

  group('ActivityType Tests', () {
    test('should have all expected activity types', () {
      expect(ActivityType.values.length, equals(12));
      expect(ActivityType.values.contains(ActivityType.courseCreated), isTrue);
      expect(ActivityType.values.contains(ActivityType.courseUpdated), isTrue);
      expect(ActivityType.values.contains(ActivityType.courseDeleted), isTrue);
      expect(
          ActivityType.values.contains(ActivityType.challengeCreated), isTrue);
      expect(
          ActivityType.values.contains(ActivityType.challengeUpdated), isTrue);
      expect(
          ActivityType.values.contains(ActivityType.challengeDeleted), isTrue);
      expect(ActivityType.values.contains(ActivityType.videoCreated), isTrue);
      expect(ActivityType.values.contains(ActivityType.videoUpdated), isTrue);
      expect(ActivityType.values.contains(ActivityType.videoDeleted), isTrue);
      expect(ActivityType.values.contains(ActivityType.forumCreated), isTrue);
      expect(ActivityType.values.contains(ActivityType.forumUpdated), isTrue);
      expect(ActivityType.values.contains(ActivityType.forumDeleted), isTrue);
    });
  });

  group('EntityType Tests', () {
    test('should have all expected entity types', () {
      expect(EntityType.values.length, equals(4));
      expect(EntityType.values.contains(EntityType.course), isTrue);
      expect(EntityType.values.contains(EntityType.challenge), isTrue);
      expect(EntityType.values.contains(EntityType.video), isTrue);
      expect(EntityType.values.contains(EntityType.forum), isTrue);
    });
  });
}
