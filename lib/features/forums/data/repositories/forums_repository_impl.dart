import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';
import 'package:codequest/features/forums/domain/repositories/forums_repository.dart';
import 'package:codequest/services/activity_service.dart';
import 'package:codequest/features/admin/domain/models/activity_model.dart';

class ForumsRepositoryImpl implements ForumsRepository {
  final FirebaseFirestore _firestore;
  final String _forumsCollection = 'forums';
  final String _commentsCollection = 'comments';

  ForumsRepositoryImpl(this._firestore);

  @override
  Future<List<forum_model.ForumModel>> getForums() async {
    try {
      final snapshot = await _firestore.collection(_forumsCollection).get();
      return snapshot.docs
          .map((doc) => forum_model.ForumModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get forums: $e');
    }
  }

  @override
  Future<forum_model.ForumModel> getForum(String id) async {
    try {
      final doc = await _firestore.collection(_forumsCollection).doc(id).get();
      if (!doc.exists) {
        throw Exception('Forum not found');
      }
      return forum_model.ForumModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get forum: $e');
    }
  }

  @override
  Future<forum_model.ForumModel> createForum(
      forum_model.ForumModel forum) async {
    try {
      final docRef = _firestore.collection(_forumsCollection).doc();
      final newForum = forum.copyWith(id: docRef.id);
      await docRef.set(newForum.toMap());

      // Log activity
      await ActivityService.logForumActivity(
        activityType: ActivityType.forumCreated,
        forumId: docRef.id,
        forumTitle: forum.title,
        courseId: forum.courseId,
      );

      return newForum;
    } catch (e) {
      throw Exception('Failed to create forum: $e');
    }
  }

  @override
  Future<forum_model.ForumModel> updateForum(
      forum_model.ForumModel forum) async {
    try {
      await _firestore
          .collection(_forumsCollection)
          .doc(forum.id)
          .update(forum.toMap());

      // Log activity
      await ActivityService.logForumActivity(
        activityType: ActivityType.forumUpdated,
        forumId: forum.id,
        forumTitle: forum.title,
        courseId: forum.courseId,
      );

      return forum;
    } catch (e) {
      throw Exception('Failed to update forum: $e');
    }
  }

  @override
  Future<void> deleteForum(String id) async {
    try {
      // Get forum data before deletion for activity logging
      final forumDoc =
          await _firestore.collection(_forumsCollection).doc(id).get();
      final forumData = forumDoc.data();

      await _firestore.collection(_forumsCollection).doc(id).delete();
      // Delete all comments associated with this forum
      final commentsSnapshot = await _firestore
          .collection(_commentsCollection)
          .where('forumId', isEqualTo: id)
          .get();
      for (var doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Log activity
      if (forumData != null) {
        await ActivityService.logForumActivity(
          activityType: ActivityType.forumDeleted,
          forumId: id,
          forumTitle: forumData['title'] ?? 'Unknown Forum',
          courseId: forumData['courseId'],
        );
      }
    } catch (e) {
      throw Exception('Failed to delete forum: $e');
    }
  }

  @override
  Future<List<forum_model.ForumModel>> getForumsByCategory(
      String category) async {
    try {
      final snapshot = await _firestore
          .collection(_forumsCollection)
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs
          .map((doc) => forum_model.ForumModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get forums by category: $e');
    }
  }

  @override
  Future<List<CommentModel>> getComments(String forumId) async {
    try {
      final snapshot = await _firestore
          .collection(_commentsCollection)
          .where('forumId', isEqualTo: forumId)
          .orderBy('createdAt', descending: false)
          .get();
      return snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get comments: $e');
    }
  }

  @override
  Future<CommentModel> addComment(CommentModel comment) async {
    try {
      final docRef = _firestore.collection(_commentsCollection).doc();
      final newComment = comment.copyWith(id: docRef.id);
      await docRef.set(newComment.toMap());
      return newComment;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  @override
  Future<CommentModel> likeComment(String commentId, String userId) async {
    try {
      final docRef = _firestore.collection(_commentsCollection).doc(commentId);
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Comment not found');
      }

      final comment = CommentModel.fromFirestore(doc);
      final likes = List<String>.from(comment.likes);
      final dislikes = List<String>.from(comment.dislikes);

      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
        dislikes.remove(userId);
      }

      final updatedComment = comment.copyWith(
        likes: likes,
        dislikes: dislikes,
        updatedAt: DateTime.now(),
      );

      await docRef.update(updatedComment.toMap());
      return updatedComment;
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }

  @override
  Future<CommentModel> dislikeComment(String commentId, String userId) async {
    try {
      final docRef = _firestore.collection(_commentsCollection).doc(commentId);
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Comment not found');
      }

      final comment = CommentModel.fromFirestore(doc);
      final likes = List<String>.from(comment.likes);
      final dislikes = List<String>.from(comment.dislikes);

      if (dislikes.contains(userId)) {
        dislikes.remove(userId);
      } else {
        dislikes.add(userId);
        likes.remove(userId);
      }

      final updatedComment = comment.copyWith(
        likes: likes,
        dislikes: dislikes,
        updatedAt: DateTime.now(),
      );

      await docRef.update(updatedComment.toMap());
      return updatedComment;
    } catch (e) {
      throw Exception('Failed to dislike comment: $e');
    }
  }
}
