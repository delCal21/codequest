import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String courseCode;
  final String teacherId;
  final String teacherName;
  final List<Map<String, dynamic>> files; // List of files (url, name, type)
  final DateTime createdAt;
  final bool isPublished;
  final int duration; // in hours
  final String? thumbnailUrl;
  final List<String>? prerequisites;
  final String? category;
  final int? enrollmentCount;
  final List<String> collaboratorIds; // New field for collaborator IDs
  final List<Map<String, dynamic>>
      collaborators; // New field for collaborator details

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.courseCode,
    required this.teacherId,
    required this.teacherName,
    this.files = const [],
    required this.createdAt,
    this.isPublished = false,
    this.duration = 0,
    this.thumbnailUrl,
    this.prerequisites,
    this.category,
    this.enrollmentCount,
    this.collaboratorIds = const [],
    this.collaborators = const [],
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
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

    return CourseModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      files: (json['files'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      isPublished: json['isPublished'] as bool? ?? false,
      duration: json['duration'] as int? ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      prerequisites: (json['prerequisites'] as List<dynamic>?)?.cast<String>(),
      category: json['category'] as String?,
      enrollmentCount: json['enrollmentCount'] as int?,
      collaboratorIds:
          (json['collaboratorIds'] as List<dynamic>?)?.cast<String>() ?? [],
      collaborators: (json['collaborators'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'courseCode': courseCode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'files': files,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublished': isPublished,
      'duration': duration,
      'thumbnailUrl': thumbnailUrl,
      'prerequisites': prerequisites,
      'category': category,
      'enrollmentCount': enrollmentCount,
      'collaboratorIds': collaboratorIds,
      'collaborators': collaborators,
    };
  }

  CourseModel copyWith({
    String? id,
    String? title,
    String? description,
    String? courseCode,
    String? teacherId,
    String? teacherName,
    List<Map<String, dynamic>>? files,
    DateTime? createdAt,
    bool? isPublished,
    int? duration,
    String? thumbnailUrl,
    List<String>? prerequisites,
    String? category,
    int? enrollmentCount,
    List<String>? collaboratorIds,
    List<Map<String, dynamic>>? collaborators,
  }) {
    return CourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      courseCode: courseCode ?? this.courseCode,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      files: files ?? this.files,
      createdAt: createdAt ?? this.createdAt,
      isPublished: isPublished ?? this.isPublished,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      prerequisites: prerequisites ?? this.prerequisites,
      category: category ?? this.category,
      enrollmentCount: enrollmentCount ?? this.enrollmentCount,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      collaborators: collaborators ?? this.collaborators,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        courseCode,
        teacherId,
        teacherName,
        files,
        createdAt,
        isPublished,
        duration,
        thumbnailUrl,
        prerequisites,
        category,
        enrollmentCount,
        collaboratorIds,
        collaborators,
      ];
}
