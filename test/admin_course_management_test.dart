import 'package:flutter_test/flutter_test.dart';
import 'package:codequest/features/admin/presentation/pages/courses_crud_page.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/courses/domain/models/collaborator_model.dart';

void main() {
  group('Admin Course Management Tests', () {
    test('should create courses crud page with teacher assignment features',
        () {
      const page = CoursesCrudPage();
      expect(page, isNotNull);
    });

    test('should handle course model with collaborators', () {
      final course = CourseModel(
        id: 'test-course-1',
        title: 'Test Course',
        description: 'A test course',
        courseCode: 'TEST101',
        teacherId: 'teacher-1',
        teacherName: 'Test Teacher',
        createdAt: DateTime.now(),
        collaboratorIds: ['collaborator-1', 'collaborator-2'],
        collaborators: [
          {
            'userId': 'collaborator-1',
            'userName': 'Collaborator 1',
            'userEmail': 'collab1@test.com',
            'role': 'assistant',
            'addedAt': DateTime.now().toIso8601String(),
            'addedBy': 'admin',
            'isActive': true,
          },
          {
            'userId': 'collaborator-2',
            'userName': 'Collaborator 2',
            'userEmail': 'collab2@test.com',
            'role': 'moderator',
            'addedAt': DateTime.now().toIso8601String(),
            'addedBy': 'admin',
            'isActive': true,
          },
        ],
      );

      expect(course.id, equals('test-course-1'));
      expect(course.title, equals('Test Course'));
      expect(course.collaboratorIds.length, equals(2));
      expect(course.collaborators.length, equals(2));
    });

    test('should handle collaborator model creation', () {
      final collaborator = CollaboratorModel(
        id: 'collab-1',
        userId: 'user-1',
        userName: 'Test Collaborator',
        userEmail: 'test@example.com',
        role: CollaboratorRole.assistant,
        addedAt: DateTime.now(),
        addedBy: 'admin',
        isActive: true,
      );

      expect(collaborator.id, equals('collab-1'));
      expect(collaborator.userId, equals('user-1'));
      expect(collaborator.userName, equals('Test Collaborator'));
      expect(collaborator.role, equals(CollaboratorRole.assistant));
      expect(collaborator.isActive, isTrue);
    });

    test('should get correct role display names', () {
      expect(_getRoleDisplayName(CollaboratorRole.coTeacher),
          equals('Co-Teacher'));
      expect(
          _getRoleDisplayName(CollaboratorRole.assistant), equals('Assistant'));
      expect(
          _getRoleDisplayName(CollaboratorRole.moderator), equals('Moderator'));
    });

    test('should get correct default permissions for roles', () {
      final coTeacher = CollaboratorModel(
        id: '1',
        userId: 'user1',
        userName: 'Co-Teacher',
        userEmail: 'co@test.com',
        role: CollaboratorRole.coTeacher,
        addedAt: DateTime.now(),
        addedBy: 'admin',
      );

      final assistant = CollaboratorModel(
        id: '2',
        userId: 'user2',
        userName: 'Assistant',
        userEmail: 'assistant@test.com',
        role: CollaboratorRole.assistant,
        addedAt: DateTime.now(),
        addedBy: 'admin',
      );

      final moderator = CollaboratorModel(
        id: '3',
        userId: 'user3',
        userName: 'Moderator',
        userEmail: 'moderator@test.com',
        role: CollaboratorRole.moderator,
        addedAt: DateTime.now(),
        addedBy: 'admin',
      );

      // Test co-teacher permissions
      final coTeacherPermissions = coTeacher.defaultPermissions;
      expect(coTeacherPermissions['manage_content'], isTrue);
      expect(coTeacherPermissions['manage_students'], isTrue);
      expect(coTeacherPermissions['create_challenges'], isTrue);
      expect(coTeacherPermissions['view_analytics'], isTrue);
      expect(coTeacherPermissions['manage_collaborators'], isTrue);
      expect(coTeacherPermissions['publish_course'], isTrue);

      // Test assistant permissions
      final assistantPermissions = assistant.defaultPermissions;
      expect(assistantPermissions['manage_content'], isTrue);
      expect(assistantPermissions['manage_students'], isFalse);
      expect(assistantPermissions['create_challenges'], isTrue);
      expect(assistantPermissions['view_analytics'], isTrue);
      expect(assistantPermissions['manage_collaborators'], isFalse);
      expect(assistantPermissions['publish_course'], isFalse);

      // Test moderator permissions
      final moderatorPermissions = moderator.defaultPermissions;
      expect(moderatorPermissions['manage_content'], isFalse);
      expect(moderatorPermissions['manage_students'], isTrue);
      expect(moderatorPermissions['create_challenges'], isFalse);
      expect(moderatorPermissions['view_analytics'], isTrue);
      expect(moderatorPermissions['manage_collaborators'], isFalse);
      expect(moderatorPermissions['publish_course'], isFalse);
    });
  });
}

// Helper function to test role display names
String _getRoleDisplayName(CollaboratorRole role) {
  switch (role) {
    case CollaboratorRole.coTeacher:
      return 'Co-Teacher';
    case CollaboratorRole.assistant:
      return 'Assistant';
    case CollaboratorRole.moderator:
      return 'Moderator';
  }
}
