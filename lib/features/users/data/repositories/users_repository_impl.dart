import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:codequest/features/users/domain/repositories/users_repository.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';

class UsersRepositoryImpl implements UsersRepository {
  final FirebaseFirestore _firestore;
  final String _usersCollection = 'users';
  final String _videosCollection = 'videos';
  final String _forumsCollection = 'forums';
  final String _commentsCollection = 'comments';

  UsersRepositoryImpl(this._firestore);

  @override
  Future<List<UserModel>> getUsers() async {
    try {
      final snapshot = await _firestore.collection(_usersCollection).get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  @override
  Future<UserModel> getUser(String id) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(id).get();
      if (!doc.exists) {
        throw Exception('User not found');
      }
      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  @override
  Future<UserModel> createUser(UserModel user) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc();
      final newUser = user.copyWith(id: docRef.id);
      await docRef.set(newUser.toMap());
      return newUser;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  @override
  Future<UserModel> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.id)
          .update(user.toMap());
      return user;
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    try {
      await _firestore.collection(_usersCollection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  @override
  Future<List<VideoModel>> getUserVideos(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_videosCollection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return VideoModel.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get user videos: $e');
    }
  }

  @override
  Future<List<forum_model.ForumModel>> getUserForums(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_forumsCollection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => forum_model.ForumModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user forums: $e');
    }
  }

  @override
  Future<List<CommentModel>> getUserComments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_commentsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user comments: $e');
    }
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: role)
          .get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users by role: $e');
    }
  }

  @override
  Future<void> updateUserPreferences(
      String userId, Map<String, dynamic> preferences) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({'preferences': preferences});
    } catch (e) {
      throw Exception('Failed to update user preferences: $e');
    }
  }

  @override
  Future<forum_model.ForumModel> getForum(String forumId) async {
    try {
      final doc =
          await _firestore.collection(_forumsCollection).doc(forumId).get();
      if (!doc.exists) {
        throw Exception('Forum not found');
      }
      return forum_model.ForumModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get forum: $e');
    }
  }
}
