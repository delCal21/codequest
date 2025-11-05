import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';

abstract class ForumsRepository {
  Future<List<forum_model.ForumModel>> getForums();
  Future<forum_model.ForumModel> getForum(String id);
  Future<forum_model.ForumModel> createForum(forum_model.ForumModel forum);
  Future<forum_model.ForumModel> updateForum(forum_model.ForumModel forum);
  Future<void> deleteForum(String id);
  Future<List<forum_model.ForumModel>> getForumsByCategory(String category);

  // Comment-related methods
  Future<List<CommentModel>> getComments(String forumId);
  Future<CommentModel> addComment(CommentModel comment);
  Future<CommentModel> likeComment(String commentId, String userId);
  Future<CommentModel> dislikeComment(String commentId, String userId);
}
