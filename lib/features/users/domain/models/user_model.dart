import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole { admin, teacher, student }

class UserModel extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? profileImage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final List<String> enrolledCourses;
  final Map<String, dynamic> preferences;
  final List<Map<String, dynamic>> recentActivities;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.profileImage,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.enrolledCourses = const [],
    this.preferences = const {},
    this.recentActivities = const [],
  });

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        role,
        profileImage,
        createdAt,
        updatedAt,
        isActive,
        enrolledCourses,
        preferences,
        recentActivities,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role.toString().split('.').last,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'enrolledCourses': enrolledCourses,
      'preferences': preferences,
      'recentActivities': recentActivities,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.student,
      ),
      profileImage: json['profileImage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      enrolledCourses:
          List<String>.from(json['enrolledCourses'] as List? ?? []),
      preferences: Map<String, dynamic>.from(json['preferences'] as Map? ?? {}),
      recentActivities: (json['recentActivities'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? profileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    List<String>? enrolledCourses,
    Map<String, dynamic>? preferences,
    List<Map<String, dynamic>>? recentActivities,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      enrolledCourses: enrolledCourses ?? this.enrolledCourses,
      preferences: preferences ?? this.preferences,
      recentActivities: recentActivities ?? this.recentActivities,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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

    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      profileImage: data['profileImage'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == (data['role'] ?? 'student'),
        orElse: () => UserRole.student,
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
      enrolledCourses: List<String>.from(data['enrolledCourses'] ?? []),
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      recentActivities: (data['recentActivities'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'profileImage': profileImage,
      'role': role.toString().split('.').last,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
