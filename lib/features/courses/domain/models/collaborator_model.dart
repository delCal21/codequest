import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum CollaboratorRole { coTeacher, assistant, moderator }

class CollaboratorModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final CollaboratorRole role;
  final DateTime addedAt;
  final String addedBy;
  final bool isActive;
  final Map<String, bool> permissions;

  const CollaboratorModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.role,
    required this.addedAt,
    required this.addedBy,
    this.isActive = true,
    this.permissions = const {},
  });

  factory CollaboratorModel.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is DateTime) {
        return value;
      }
      return null;
    }

    return CollaboratorModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userEmail: json['userEmail'] as String,
      role: CollaboratorRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => CollaboratorRole.assistant,
      ),
      addedAt: _parseDate(json['addedAt']) ?? DateTime.now(),
      addedBy: json['addedBy'] as String,
      isActive: json['isActive'] as bool? ?? true,
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'role': role.toString().split('.').last,
      'addedAt': Timestamp.fromDate(addedAt),
      'addedBy': addedBy,
      'isActive': isActive,
      'permissions': permissions,
    };
  }

  CollaboratorModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    CollaboratorRole? role,
    DateTime? addedAt,
    String? addedBy,
    bool? isActive,
    Map<String, bool>? permissions,
  }) {
    return CollaboratorModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      role: role ?? this.role,
      addedAt: addedAt ?? this.addedAt,
      addedBy: addedBy ?? this.addedBy,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
    );
  }

  // Default permissions based on role
  Map<String, bool> get defaultPermissions {
    switch (role) {
      case CollaboratorRole.coTeacher:
        return {
          'manage_content': true,
          'manage_students': true,
          'create_challenges': true,
          'view_analytics': true,
          'manage_collaborators': true,
          'publish_course': true,
        };
      case CollaboratorRole.assistant:
        return {
          'manage_content': true,
          'manage_students': false,
          'create_challenges': true,
          'view_analytics': true,
          'manage_collaborators': false,
          'publish_course': false,
        };
      case CollaboratorRole.moderator:
        return {
          'manage_content': false,
          'manage_students': true,
          'create_challenges': false,
          'view_analytics': true,
          'manage_collaborators': false,
          'publish_course': false,
        };
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        userEmail,
        role,
        addedAt,
        addedBy,
        isActive,
        permissions,
      ];
}
