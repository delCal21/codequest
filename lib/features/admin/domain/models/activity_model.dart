import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  courseCreated,
  courseUpdated,
  courseDeleted,
  challengeCreated,
  challengeUpdated,
  challengeDeleted,
  videoCreated,
  videoUpdated,
  videoDeleted,
  forumCreated,
  forumUpdated,
  forumDeleted,
}

enum EntityType {
  course,
  challenge,
  video,
  forum,
}

class ActivityModel extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final ActivityType activityType;
  final EntityType entityType;
  final String entityId;
  final String entityTitle;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? courseId; // For activities related to course content

  const ActivityModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.activityType,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    required this.description,
    required this.timestamp,
    this.metadata,
    this.courseId,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
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

    return ActivityModel(
      id: json['id'] as String,
      teacherId: json['teacherId'] as String,
      teacherName: json['teacherName'] as String,
      activityType: ActivityType.values.firstWhere(
        (e) => e.toString().split('.').last == json['activityType'],
        orElse: () => ActivityType.courseCreated,
      ),
      entityType: EntityType.values.firstWhere(
        (e) => e.toString().split('.').last == json['entityType'],
        orElse: () => EntityType.course,
      ),
      entityId: json['entityId'] as String,
      entityTitle: json['entityTitle'] as String,
      description: json['description'] as String,
      timestamp: _parseDate(json['timestamp']) ?? DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      courseId: json['courseId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'activityType': activityType.toString().split('.').last,
      'entityType': entityType.toString().split('.').last,
      'entityId': entityId,
      'entityTitle': entityTitle,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
      'courseId': courseId,
    };
  }

  ActivityModel copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    ActivityType? activityType,
    EntityType? entityType,
    String? entityId,
    String? entityTitle,
    String? description,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? courseId,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      activityType: activityType ?? this.activityType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entityTitle: entityTitle ?? this.entityTitle,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      courseId: courseId ?? this.courseId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        teacherId,
        teacherName,
        activityType,
        entityType,
        entityId,
        entityTitle,
        description,
        timestamp,
        metadata,
        courseId,
      ];
}
