import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CommentModel extends Equatable {
  final String id;
  final String forumId;
  final String userId;
  final String userFullName;
  final String? userAvatarUrl;
  final String content;
  final String? parentCommentId;
  final List<String> likes;
  final List<String> dislikes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommentModel({
    required this.id,
    required this.forumId,
    required this.userId,
    required this.userFullName,
    this.userAvatarUrl,
    required this.content,
    this.parentCommentId,
    required this.likes,
    required this.dislikes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else if (value == null) {
        return DateTime.now();
      }
      return DateTime.now();
    }

    return CommentModel(
      id: doc.id,
      forumId: data['forumId'] as String,
      userId: data['userId'] as String,
      userFullName: data['userFullName'] as String,
      userAvatarUrl: data['userAvatarUrl'] as String?,
      content: data['content'] as String,
      parentCommentId: data['parentCommentId'] as String?,
      likes: List<String>.from(data['likes'] ?? []),
      dislikes: List<String>.from(data['dislikes'] ?? []),
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'forumId': forumId,
      'userId': userId,
      'userFullName': userFullName,
      'userAvatarUrl': userAvatarUrl,
      'content': content,
      'parentCommentId': parentCommentId,
      'likes': likes,
      'dislikes': dislikes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CommentModel copyWith({
    String? id,
    String? forumId,
    String? userId,
    String? userFullName,
    String? userAvatarUrl,
    String? content,
    String? parentCommentId,
    List<String>? likes,
    List<String>? dislikes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      forumId: forumId ?? this.forumId,
      userId: userId ?? this.userId,
      userFullName: userFullName ?? this.userFullName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      content: content ?? this.content,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        forumId,
        userId,
        userFullName,
        userAvatarUrl,
        content,
        parentCommentId,
        likes,
        dislikes,
        createdAt,
        updatedAt,
      ];
}
