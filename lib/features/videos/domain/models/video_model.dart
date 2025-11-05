import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String teacherId;
  final String teacherName;
  final String videoUrl;
  final String fileName;
  final String mediaType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublished;
  final int duration; // in seconds
  final String? thumbnailUrl;
  final List<String>? tags;
  final String? category;
  final int? viewCount;
  final int? downloadCount;
  final Map<String, dynamic>? metadata;
  final String? courseId;

  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.teacherId,
    required this.teacherName,
    required this.videoUrl,
    required this.fileName,
    required this.mediaType,
    required this.createdAt,
    required this.updatedAt,
    this.isPublished = false,
    this.duration = 0,
    this.thumbnailUrl,
    this.tags,
    this.category,
    this.viewCount = 0,
    this.downloadCount = 0,
    this.metadata,
    this.courseId,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
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

    return VideoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      teacherId: json['teacherId'] as String,
      teacherName: json['teacherName'] as String,
      videoUrl: json['videoUrl'] as String,
      fileName: json['fileName'] as String,
      mediaType: json['mediaType'] as String,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
      isPublished: json['isPublished'] as bool? ?? false,
      duration: json['duration'] as int? ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      category: json['category'] as String?,
      viewCount: json['viewCount'] as int? ?? 0,
      downloadCount: json['downloadCount'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
      courseId: json['courseId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'videoUrl': videoUrl,
      'fileName': fileName,
      'mediaType': mediaType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPublished': isPublished,
      'duration': duration,
      'thumbnailUrl': thumbnailUrl,
      'tags': tags,
      'category': category,
      'viewCount': viewCount,
      'downloadCount': downloadCount,
      'metadata': metadata,
      'courseId': courseId,
    };
  }

  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? teacherId,
    String? teacherName,
    String? videoUrl,
    String? fileName,
    String? mediaType,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublished,
    int? duration,
    String? thumbnailUrl,
    List<String>? tags,
    String? category,
    int? viewCount,
    int? downloadCount,
    Map<String, dynamic>? metadata,
    String? courseId,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      videoUrl: videoUrl ?? this.videoUrl,
      fileName: fileName ?? this.fileName,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublished: isPublished ?? this.isPublished,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      viewCount: viewCount ?? this.viewCount,
      downloadCount: downloadCount ?? this.downloadCount,
      metadata: metadata ?? this.metadata,
      courseId: courseId ?? this.courseId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        teacherId,
        teacherName,
        videoUrl,
        fileName,
        mediaType,
        createdAt,
        updatedAt,
        isPublished,
        duration,
        thumbnailUrl,
        tags,
        category,
        viewCount,
        downloadCount,
        metadata,
        courseId,
      ];
}
