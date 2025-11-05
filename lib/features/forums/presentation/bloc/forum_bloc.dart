import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart';
import 'package:codequest/features/forums/data/repositories/forum_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Events
abstract class ForumEvent extends Equatable {
  const ForumEvent();

  @override
  List<Object?> get props => [];
}

class LoadForums extends ForumEvent {
  final String courseId;
  final String? teacherId;
  const LoadForums({required this.courseId, this.teacherId});

  @override
  List<Object?> get props => [courseId, teacherId];
}

class CreateForum extends ForumEvent {
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String courseId;

  const CreateForum({
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.courseId,
  });

  @override
  List<Object?> get props => [title, content, authorId, authorName, courseId];
}

class UpdateForum extends ForumEvent {
  final ForumModel forum;

  const UpdateForum(this.forum);

  @override
  List<Object?> get props => [forum];
}

class DeleteForum extends ForumEvent {
  final String id;

  const DeleteForum(this.id);

  @override
  List<Object?> get props => [id];
}

class LikeForum extends ForumEvent {
  final String forumId;
  final String userId;

  const LikeForum(this.forumId, this.userId);

  @override
  List<Object?> get props => [forumId, userId];
}

class UnlikeForum extends ForumEvent {
  final String forumId;
  final String userId;

  const UnlikeForum(this.forumId, this.userId);

  @override
  List<Object?> get props => [forumId, userId];
}

class ShareForum extends ForumEvent {
  final String forumId;
  final String userId;

  const ShareForum(this.forumId, this.userId);

  @override
  List<Object?> get props => [forumId, userId];
}

class AddReaction extends ForumEvent {
  final String forumId;
  final String userId;
  final String reactionType;

  const AddReaction(this.forumId, this.userId, this.reactionType);

  @override
  List<Object?> get props => [forumId, userId, reactionType];
}

class RemoveReaction extends ForumEvent {
  final String forumId;
  final String userId;

  const RemoveReaction(this.forumId, this.userId);

  @override
  List<Object?> get props => [forumId, userId];
}

class AddComment extends ForumEvent {
  final String forumId;
  final String content;
  final String authorId;
  final String authorName;

  const AddComment({
    required this.forumId,
    required this.content,
    required this.authorId,
    required this.authorName,
  });

  @override
  List<Object?> get props => [forumId, content, authorId, authorName];
}

class UpdateComment extends ForumEvent {
  final String forumId;
  final CommentModel comment;

  const UpdateComment(this.forumId, this.comment);

  @override
  List<Object?> get props => [forumId, comment];
}

class DeleteComment extends ForumEvent {
  final String forumId;
  final String commentId;

  const DeleteComment(this.forumId, this.commentId);

  @override
  List<Object?> get props => [forumId, commentId];
}

class LikeComment extends ForumEvent {
  final String forumId;
  final String commentId;
  final String userId;

  const LikeComment(this.forumId, this.commentId, this.userId);

  @override
  List<Object?> get props => [forumId, commentId, userId];
}

class UnlikeComment extends ForumEvent {
  final String forumId;
  final String commentId;
  final String userId;

  const UnlikeComment(this.forumId, this.commentId, this.userId);

  @override
  List<Object?> get props => [forumId, commentId, userId];
}

// States
abstract class ForumState extends Equatable {
  const ForumState();

  @override
  List<Object?> get props => [];
}

class ForumInitial extends ForumState {}

class ForumLoading extends ForumState {}

class ForumLoaded extends ForumState {
  final List<ForumModel> forums;

  const ForumLoaded(this.forums);

  @override
  List<Object?> get props => [forums];
}

class ForumError extends ForumState {
  final String message;

  const ForumError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class ForumBloc extends Bloc<ForumEvent, ForumState> {
  final ForumRepositoryImpl _repository;

  ForumBloc(this._repository) : super(ForumInitial()) {
    on<LoadForums>(_onLoadForums);
    on<CreateForum>(_onCreateForum);
    on<UpdateForum>(_onUpdateForum);
    on<DeleteForum>(_onDeleteForum);
    on<LikeForum>(_onLikeForum);
    on<UnlikeForum>(_onUnlikeForum);
    on<ShareForum>(_onShareForum);
    on<AddReaction>(_onAddReaction);
    on<RemoveReaction>(_onRemoveReaction);
    on<AddComment>(_onAddComment);
    on<UpdateComment>(_onUpdateComment);
    on<DeleteComment>(_onDeleteComment);
    on<LikeComment>(_onLikeComment);
    on<UnlikeComment>(_onUnlikeComment);
  }

  Future<void> _onLoadForums(LoadForums event, Emitter<ForumState> emit) async {
    try {
      emit(ForumLoading());
      // Get admin IDs
      final adminIds =
          await ForumRepositoryImpl.getAdminUserIds(FirebaseFirestore.instance);
      // You may want to get teacherId from the authenticated user context
      // For now, assume teacherId is available (replace with actual logic)
      final teacherId = event.teacherId ?? '';
      final forums = await _repository.getForumsForTeacherAndAdmins(
          event.courseId, teacherId, adminIds);
      emit(ForumLoaded(forums));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onCreateForum(
      CreateForum event, Emitter<ForumState> emit) async {
    try {
      final forum = ForumModel(
        id: '',
        courseId: event.courseId,
        title: event.title,
        content: event.content,
        authorId: event.authorId,
        authorName: event.authorName,
        createdAt: DateTime.now(),
      );
      await _repository.createForum(forum);
      add(LoadForums(courseId: event.courseId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onUpdateForum(
      UpdateForum event, Emitter<ForumState> emit) async {
    try {
      await _repository.updateForum(event.forum);
      add(LoadForums(courseId: event.forum.courseId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onDeleteForum(
      DeleteForum event, Emitter<ForumState> emit) async {
    try {
      await _repository.deleteForum(event.id);
      add(LoadForums(courseId: event.id));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onLikeForum(LikeForum event, Emitter<ForumState> emit) async {
    try {
      await _repository.likeForum(event.forumId, event.userId);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onUnlikeForum(
      UnlikeForum event, Emitter<ForumState> emit) async {
    try {
      await _repository.unlikeForum(event.forumId, event.userId);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onShareForum(ShareForum event, Emitter<ForumState> emit) async {
    try {
      await _repository.shareForum(event.forumId, event.userId);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onAddReaction(
      AddReaction event, Emitter<ForumState> emit) async {
    try {
      await _repository.addReaction(
          event.forumId, event.userId, event.reactionType);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onRemoveReaction(
      RemoveReaction event, Emitter<ForumState> emit) async {
    try {
      await _repository.removeReaction(event.forumId, event.userId);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onAddComment(AddComment event, Emitter<ForumState> emit) async {
    try {
      final comment = CommentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: event.content,
        authorId: event.authorId,
        authorName: event.authorName,
        createdAt: DateTime.now(),
      );
      await _repository.addComment(event.forumId, comment);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onUpdateComment(
      UpdateComment event, Emitter<ForumState> emit) async {
    try {
      await _repository.updateComment(event.forumId, event.comment);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onDeleteComment(
      DeleteComment event, Emitter<ForumState> emit) async {
    try {
      await _repository.deleteComment(event.forumId, event.commentId);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onLikeComment(
      LikeComment event, Emitter<ForumState> emit) async {
    try {
      await _repository.likeComment(
          event.forumId, event.commentId, event.userId);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }

  Future<void> _onUnlikeComment(
      UnlikeComment event, Emitter<ForumState> emit) async {
    try {
      await _repository.unlikeComment(
          event.forumId, event.commentId, event.userId);
      add(LoadForums(courseId: event.forumId));
    } catch (e) {
      emit(ForumError(e.toString()));
    }
  }
}
