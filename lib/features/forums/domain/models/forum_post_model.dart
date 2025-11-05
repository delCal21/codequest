import 'package:equatable/equatable.dart';

class ForumPostModel extends Equatable {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorImage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> likes;
  final List<String> tags;
  final bool isPinned;
  final bool isLocked;
  final String? courseId;
  final int commentCount;

  const ForumPostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorImage,
    required this.createdAt,
    required this.updatedAt,
    this.likes = const [],
    this.tags = const [],
    this.isPinned = false,
    this.isLocked = false,
    this.courseId,
    this.commentCount = 0,
  });

  factory ForumPostModel.fromJson(Map<String, dynamic> json) {
    return ForumPostModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      authorImage: json['authorImage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      likes: List<String>.from(json['likes'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
      isPinned: json['isPinned'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      courseId: json['courseId'] as String?,
      commentCount: json['commentCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorImage': authorImage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'likes': likes,
      'tags': tags,
      'isPinned': isPinned,
      'isLocked': isLocked,
      'courseId': courseId,
      'commentCount': commentCount,
    };
  }

  ForumPostModel copyWith({
    String? id,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    String? authorImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? likes,
    List<String>? tags,
    bool? isPinned,
    bool? isLocked,
    String? courseId,
    int? commentCount,
  }) {
    return ForumPostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImage: authorImage ?? this.authorImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likes: likes ?? this.likes,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      courseId: courseId ?? this.courseId,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    content,
    authorId,
    authorName,
    authorImage,
    createdAt,
    updatedAt,
    likes,
    tags,
    isPinned,
    isLocked,
    courseId,
    commentCount,
  ];
}
