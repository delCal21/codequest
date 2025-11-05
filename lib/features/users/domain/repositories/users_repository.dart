import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';

abstract class UsersRepository {
  Future<List<UserModel>> getUsers();
  Future<UserModel> getUser(String id);
  Future<UserModel> createUser(UserModel user);
  Future<UserModel> updateUser(UserModel user);
  Future<void> deleteUser(String id);
  Future<List<VideoModel>> getUserVideos(String userId);
  Future<List<forum_model.ForumModel>> getUserForums(String userId);
  Future<List<CommentModel>> getUserComments(String userId);
  Future<forum_model.ForumModel> getForum(String forumId);
  Future<List<UserModel>> getUsersByRole(String role);
  Future<void> updateUserPreferences(
      String userId, Map<String, dynamic> preferences);
}
