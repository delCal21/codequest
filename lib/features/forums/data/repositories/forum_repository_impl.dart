import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart';
import 'package:codequest/services/notification_service.dart';

class ForumRepositoryImpl {
  final FirebaseFirestore _firestore;
  final String _collection = 'forums';

  ForumRepositoryImpl(this._firestore);

  FirebaseFirestore get firestore => _firestore;

  Future<List<ForumModel>> getForums(String courseId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isDeleted', isEqualTo: false)
          .where('courseId', isEqualTo: courseId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ForumModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get forums: $e');
    }
  }

  Future<ForumModel> getForum(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) {
        throw Exception('Forum not found');
      }
      return ForumModel.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to get forum: $e');
    }
  }

  Future<ForumModel> createForum(ForumModel forum) async {
    try {
      final docRef =
          await _firestore.collection(_collection).add(forum.toJson());

      // Create admin notification
      await NotificationService.notifyForumEvent(
        type: 'created',
        forumId: docRef.id,
        forumTitle: forum.title,
        userId: forum.authorId,
        userName: forum.authorName,
        forumData: forum.toJson(),
      );

      return forum.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create forum: $e');
    }
  }

  Future<void> updateForum(ForumModel forum) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(forum.id)
          .update(forum.toJson());

      // Create admin notification
      await NotificationService.notifyForumEvent(
        type: 'updated',
        forumId: forum.id,
        forumTitle: forum.title,
        userId: forum.authorId,
        userName: forum.authorName,
        forumData: forum.toJson(),
      );
    } catch (e) {
      throw Exception('Failed to update forum: $e');
    }
  }

  Future<void> deleteForum(String id) async {
    try {
      // Get forum data before deletion for notification
      final forumDoc = await _firestore.collection(_collection).doc(id).get();
      final forumData = forumDoc.data();

      await _firestore
          .collection(_collection)
          .doc(id)
          .update({'isDeleted': true});

      // Create admin notification
      if (forumData != null) {
        await NotificationService.notifyForumEvent(
          type: 'deleted',
          forumId: id,
          forumTitle: forumData['title'] ?? 'Unknown Forum',
          userId: forumData['authorId'] ?? 'unknown',
          userName: forumData['authorName'] ?? 'Unknown User',
          forumData: forumData,
        );
      }
    } catch (e) {
      throw Exception('Failed to delete forum: $e');
    }
  }

  Future<void> likeForum(String forumId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(forumId).update({
        'likes': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      throw Exception('Failed to like forum: $e');
    }
  }

  Future<void> unlikeForum(String forumId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(forumId).update({
        'likes': FieldValue.arrayRemove([userId])
      });
    } catch (e) {
      throw Exception('Failed to unlike forum: $e');
    }
  }

  Future<void> shareForum(String forumId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(forumId).update({
        'shares': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      throw Exception('Failed to share forum: $e');
    }
  }

  Future<void> addReaction(
      String forumId, String userId, String reactionType) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(forumId)
          .update({'reactions.$userId': reactionType});
    } catch (e) {
      throw Exception('Failed to add reaction: $e');
    }
  }

  Future<void> removeReaction(String forumId, String userId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(forumId)
          .update({'reactions.$userId': FieldValue.delete()});
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  Future<void> addComment(String forumId, CommentModel comment) async {
    try {
      await _firestore.collection(_collection).doc(forumId).update({
        'comments': FieldValue.arrayUnion([comment.toJson()])
      });
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  Future<void> updateComment(String forumId, CommentModel comment) async {
    try {
      final forum = await getForum(forumId);
      final updatedComments = forum.comments.map((c) {
        return c.id == comment.id ? comment : c;
      }).toList();
      await _firestore.collection(_collection).doc(forumId).update(
          {'comments': updatedComments.map((c) => c.toJson()).toList()});
    } catch (e) {
      throw Exception('Failed to update comment: $e');
    }
  }

  Future<void> deleteComment(String forumId, String commentId) async {
    try {
      final forum = await getForum(forumId);
      final updatedComments = forum.comments.map((c) {
        return c.id == commentId ? c.copyWith(isDeleted: true) : c;
      }).toList();
      await _firestore.collection(_collection).doc(forumId).update(
          {'comments': updatedComments.map((c) => c.toJson()).toList()});
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<void> likeComment(
      String forumId, String commentId, String userId) async {
    try {
      final forum = await getForum(forumId);
      final updatedComments = forum.comments.map((c) {
        if (c.id == commentId) {
          final likes = List<String>.from(c.likes)..add(userId);
          return c.copyWith(likes: likes);
        }
        return c;
      }).toList();
      await _firestore.collection(_collection).doc(forumId).update(
          {'comments': updatedComments.map((c) => c.toJson()).toList()});
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }

  Future<void> unlikeComment(
      String forumId, String commentId, String userId) async {
    try {
      final forum = await getForum(forumId);
      final updatedComments = forum.comments.map((c) {
        if (c.id == commentId) {
          final likes = List<String>.from(c.likes)..remove(userId);
          return c.copyWith(likes: likes);
        }
        return c;
      }).toList();
      await _firestore.collection(_collection).doc(forumId).update(
          {'comments': updatedComments.map((c) => c.toJson()).toList()});
    } catch (e) {
      throw Exception('Failed to unlike comment: $e');
    }
  }

  /// Duplicate all forums created by an admin to a teacher
  Future<void> duplicateAdminForumsToTeacher({
    required String adminId,
    required String teacherId,
    required String teacherName,
  }) async {
    final forumsCollection = _firestore.collection(_collection);
    // Fetch all forums created by the admin
    final adminForums =
        await forumsCollection.where('authorId', isEqualTo: adminId).get();
    print('Duplicating forums for adminId: $adminId');
    print('Found \\${adminForums.docs.length} forums');
    for (final doc in adminForums.docs) {
      final data = doc.data();
      // Remove the id so Firestore generates a new one
      data.remove('id');
      // Set teacher as the new author
      data['authorId'] = teacherId;
      data['authorName'] = teacherName;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = null;
      data['likes'] = <String>[];
      data['shares'] = <String>[];
      data['reactions'] = <String, String>{};
      data['comments'] = <dynamic>[];
      data['isDeleted'] = false;
      await forumsCollection.add(data);
      print('Duplicated forum: ' + (data['title'] ?? 'Untitled'));
    }
  }

  /// Get forums for a course authored by either the teacher or any admin
  Future<List<ForumModel>> getForumsForTeacherAndAdmins(
      String courseId, String teacherId, List<String> adminIds) async {
    try {
      final authorIds = [teacherId, ...adminIds];
      final snapshot = await _firestore
          .collection(_collection)
          .where('isDeleted', isEqualTo: false)
          .where('courseId', isEqualTo: courseId)
          .where('authorId', whereIn: authorIds)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ForumModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get forums for teacher and admins: $e');
    }
  }

  /// Fetch all admin user IDs from the users collection
  static Future<List<String>> getAdminUserIds(
      FirebaseFirestore firestore) async {
    final snapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Get all forums for a course, regardless of authorId
  Future<List<ForumModel>> getForumsForCourse(String courseId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isDeleted', isEqualTo: false)
          .where('courseId', isEqualTo: courseId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ForumModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get forums for course: $e');
    }
  }
}
