import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole { admin, teacher, student }

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final List<String> enrolledCourses;
  final Map<String, dynamic> preferences;
  final List<Map<String, dynamic>> recentActivities;
  final User? firebaseUser;
  final DateTime? lastLogin;
  final DateTime? lastLogout;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.enrolledCourses = const [],
    this.preferences = const {},
    this.recentActivities = const [],
    this.firebaseUser,
    this.lastLogin,
    this.lastLogout,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc, {User? firebaseUser}) {
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
      name: data['name'] ?? data['fullName'] ?? '',
      email: data['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            (data['role'] as String? ?? '').toLowerCase(),
        orElse: () => UserRole.student,
      ),
      avatarUrl: data['avatarUrl'],
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      enrolledCourses: List<String>.from(data['enrolledCourses'] ?? []),
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      recentActivities: (data['recentActivities'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      firebaseUser: firebaseUser,
      lastLogin:
          data['lastLogin'] != null ? _parseDate(data['lastLogin']) : null,
      lastLogout:
          data['lastLogout'] != null ? _parseDate(data['lastLogout']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'enrolledCourses': enrolledCourses,
      'preferences': preferences,
      'recentActivities': recentActivities,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (lastLogin != null) 'lastLogin': Timestamp.fromDate(lastLogin!),
      if (lastLogout != null) 'lastLogout': Timestamp.fromDate(lastLogout!),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    List<String>? enrolledCourses,
    Map<String, dynamic>? preferences,
    List<Map<String, dynamic>>? recentActivities,
    User? firebaseUser,
    DateTime? lastLogin,
    DateTime? lastLogout,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      enrolledCourses: enrolledCourses ?? this.enrolledCourses,
      preferences: preferences ?? this.preferences,
      recentActivities: recentActivities ?? this.recentActivities,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      lastLogin: lastLogin ?? this.lastLogin,
      lastLogout: lastLogout ?? this.lastLogout,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        role,
        avatarUrl,
        createdAt,
        updatedAt,
        isActive,
        enrolledCourses,
        preferences,
        recentActivities,
        firebaseUser,
        lastLogin,
        lastLogout,
      ];
}
