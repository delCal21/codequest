import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ForumModel extends Equatable {
  final String id;
  final String courseId;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> likes;
  final List<String> shares;
  final List<CommentModel> comments;
  final Map<String, String> reactions; // userId: reactionType
  final bool isDeleted;

  const ForumModel({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
    this.likes = const [],
    this.shares = const [],
    this.comments = const [],
    this.reactions = const {},
    this.isDeleted = false,
  });

  @override
  List<Object?> get props => [
        id,
        courseId,
        title,
        content,
        authorId,
        authorName,
        createdAt,
        updatedAt,
        likes,
        shares,
        comments,
        reactions,
        isDeleted,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'likes': likes,
      'shares': shares,
      'comments': comments.map((c) => c.toJson()).toList(),
      'reactions': reactions,
      'isDeleted': isDeleted,
    };
  }

  factory ForumModel.fromJson(Map<String, dynamic> json) {
    return ForumModel(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      likes: List<String>.from(json['likes'] as List),
      shares: List<String>.from(json['shares'] as List),
      comments: (json['comments'] as List)
          .map((c) => CommentModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      reactions: Map<String, String>.from(json['reactions'] as Map),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  ForumModel copyWith({
    String? id,
    String? courseId,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? likes,
    List<String>? shares,
    List<CommentModel>? comments,
    Map<String, String>? reactions,
    bool? isDeleted,
  }) {
    return ForumModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      comments: comments ?? this.comments,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  factory ForumModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String && value.isNotEmpty) {
        return DateTime.parse(value);
      }
      return null;
    }

    return ForumModel(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseDateTime(data['updatedAt']),
      likes: List<String>.from(data['likes'] ?? []),
      shares: List<String>.from(data['shares'] ?? []),
      comments: (data['comments'] as List<dynamic>? ?? [])
          .map((c) => CommentModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'likes': likes,
      'shares': shares,
      'comments': comments,
      'reactions': reactions,
      'isDeleted': isDeleted,
    };
  }
}

class CommentModel extends Equatable {
  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> likes;
  final bool isDeleted;

  const CommentModel({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
    this.likes = const [],
    this.isDeleted = false,
  });

  @override
  List<Object?> get props => [
        id,
        content,
        authorId,
        authorName,
        createdAt,
        updatedAt,
        likes,
        isDeleted,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'likes': likes,
      'isDeleted': isDeleted,
    };
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      likes: List<String>.from(json['likes'] as List),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  CommentModel copyWith({
    String? id,
    String? content,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? likes,
    bool? isDeleted,
  }) {
    return CommentModel(
      id: id ?? this.id,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likes: likes ?? this.likes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
