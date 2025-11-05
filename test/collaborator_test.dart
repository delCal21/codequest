import 'package:flutter_test/flutter_test.dart';
import 'package:codequest/features/courses/domain/models/collaborator_model.dart';

void main() {
  group('CollaboratorModel Tests', () {
    test('should create collaborator with default permissions', () {
      final collaborator = CollaboratorModel(
        id: '1',
        userId: 'user123',
        userName: 'John Doe',
        userEmail: 'john@example.com',
        role: CollaboratorRole.coTeacher,
        addedAt: DateTime.now(),
        addedBy: 'owner123',
      );

      expect(collaborator.id, '1');
      expect(collaborator.userId, 'user123');
      expect(collaborator.userName, 'John Doe');
      expect(collaborator.userEmail, 'john@example.com');
      expect(collaborator.role, CollaboratorRole.coTeacher);
      expect(collaborator.isActive, true);
      expect(collaborator.permissions, {});
    });

    test('should return correct default permissions for coTeacher role', () {
      final collaborator = CollaboratorModel(
        id: '1',
        userId: 'user123',
        userName: 'John Doe',
        userEmail: 'john@example.com',
        role: CollaboratorRole.coTeacher,
        addedAt: DateTime.now(),
        addedBy: 'owner123',
      );

      final permissions = collaborator.defaultPermissions;

      expect(permissions['manage_content'], true);
      expect(permissions['manage_students'], true);
      expect(permissions['create_challenges'], true);
      expect(permissions['view_analytics'], true);
      expect(permissions['manage_collaborators'], true);
      expect(permissions['publish_course'], true);
    });

    test('should return correct default permissions for assistant role', () {
      final collaborator = CollaboratorModel(
        id: '1',
        userId: 'user123',
        userName: 'John Doe',
        userEmail: 'john@example.com',
        role: CollaboratorRole.assistant,
        addedAt: DateTime.now(),
        addedBy: 'owner123',
      );

      final permissions = collaborator.defaultPermissions;

      expect(permissions['manage_content'], true);
      expect(permissions['manage_students'], false);
      expect(permissions['create_challenges'], true);
      expect(permissions['view_analytics'], true);
      expect(permissions['manage_collaborators'], false);
      expect(permissions['publish_course'], false);
    });

    test('should return correct default permissions for moderator role', () {
      final collaborator = CollaboratorModel(
        id: '1',
        userId: 'user123',
        userName: 'John Doe',
        userEmail: 'john@example.com',
        role: CollaboratorRole.moderator,
        addedAt: DateTime.now(),
        addedBy: 'owner123',
      );

      final permissions = collaborator.defaultPermissions;

      expect(permissions['manage_content'], false);
      expect(permissions['manage_students'], true);
      expect(permissions['create_challenges'], false);
      expect(permissions['view_analytics'], true);
      expect(permissions['manage_collaborators'], false);
      expect(permissions['publish_course'], false);
    });

    test('should create collaborator from JSON', () {
      final json = {
        'id': '1',
        'userId': 'user123',
        'userName': 'John Doe',
        'userEmail': 'john@example.com',
        'role': 'coTeacher',
        'addedAt': DateTime.now(),
        'addedBy': 'owner123',
        'isActive': true,
        'permissions': {
          'manage_content': true,
          'manage_students': true,
        },
      };

      final collaborator = CollaboratorModel.fromJson(json);

      expect(collaborator.id, '1');
      expect(collaborator.userId, 'user123');
      expect(collaborator.userName, 'John Doe');
      expect(collaborator.userEmail, 'john@example.com');
      expect(collaborator.role, CollaboratorRole.coTeacher);
      expect(collaborator.isActive, true);
      expect(collaborator.permissions['manage_content'], true);
      expect(collaborator.permissions['manage_students'], true);
    });

    test('should convert collaborator to JSON', () {
      final collaborator = CollaboratorModel(
        id: '1',
        userId: 'user123',
        userName: 'John Doe',
        userEmail: 'john@example.com',
        role: CollaboratorRole.assistant,
        addedAt: DateTime(2023, 1, 1),
        addedBy: 'owner123',
        permissions: {
          'manage_content': true,
          'create_challenges': true,
        },
      );

      final json = collaborator.toJson();

      expect(json['id'], '1');
      expect(json['userId'], 'user123');
      expect(json['userName'], 'John Doe');
      expect(json['userEmail'], 'john@example.com');
      expect(json['role'], 'assistant');
      expect(json['addedBy'], 'owner123');
      expect(json['isActive'], true);
      expect(json['permissions']['manage_content'], true);
      expect(json['permissions']['create_challenges'], true);
    });

    test('should copy collaborator with new values', () {
      final original = CollaboratorModel(
        id: '1',
        userId: 'user123',
        userName: 'John Doe',
        userEmail: 'john@example.com',
        role: CollaboratorRole.coTeacher,
        addedAt: DateTime.now(),
        addedBy: 'owner123',
      );

      final copied = original.copyWith(
        userName: 'Jane Doe',
        role: CollaboratorRole.assistant,
      );

      expect(copied.id, original.id);
      expect(copied.userId, original.userId);
      expect(copied.userName, 'Jane Doe');
      expect(copied.userEmail, original.userEmail);
      expect(copied.role, CollaboratorRole.assistant);
      expect(copied.addedAt, original.addedAt);
      expect(copied.addedBy, original.addedBy);
    });
  });

  group('CollaboratorRole Tests', () {
    test('should have correct enum values', () {
      expect(CollaboratorRole.values.length, 3);
      expect(CollaboratorRole.coTeacher, isA<CollaboratorRole>());
      expect(CollaboratorRole.assistant, isA<CollaboratorRole>());
      expect(CollaboratorRole.moderator, isA<CollaboratorRole>());
    });
  });
}
