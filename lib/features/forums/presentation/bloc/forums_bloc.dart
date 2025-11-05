import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';
import 'package:codequest/features/forums/domain/repositories/forums_repository.dart';

// Events
abstract class ForumsEvent extends Equatable {
  const ForumsEvent();

  @override
  List<Object?> get props => [];
}

class LoadForums extends ForumsEvent {}

class CreateForum extends ForumsEvent {
  final forum_model.ForumModel forum;

  const CreateForum(this.forum);

  @override
  List<Object?> get props => [forum];
}

class UpdateForum extends ForumsEvent {
  final forum_model.ForumModel forum;

  const UpdateForum(this.forum);

  @override
  List<Object?> get props => [forum];
}

class DeleteForum extends ForumsEvent {
  final String forumId;

  const DeleteForum(this.forumId);

  @override
  List<Object?> get props => [forumId];
}

class LoadComments extends ForumsEvent {
  final String forumId;

  const LoadComments(this.forumId);

  @override
  List<Object?> get props => [forumId];
}

class AddComment extends ForumsEvent {
  final CommentModel comment;

  const AddComment(this.comment);

  @override
  List<Object?> get props => [comment];
}

class LikeComment extends ForumsEvent {
  final String commentId;
  final String userId;

  const LikeComment({
    required this.commentId,
    required this.userId,
  });

  @override
  List<Object?> get props => [commentId, userId];
}

class DislikeComment extends ForumsEvent {
  final String commentId;
  final String userId;

  const DislikeComment({
    required this.commentId,
    required this.userId,
  });

  @override
  List<Object?> get props => [commentId, userId];
}

// States
abstract class ForumsState extends Equatable {
  const ForumsState();

  @override
  List<Object?> get props => [];
}

class ForumsInitial extends ForumsState {}

class ForumsLoading extends ForumsState {}

class ForumsLoaded extends ForumsState {
  final List<forum_model.ForumModel> forums;
  final List<CommentModel> comments;

  const ForumsLoaded({
    this.forums = const [],
    this.comments = const [],
  });

  @override
  List<Object?> get props => [forums, comments];
}

class ForumsError extends ForumsState {
  final String message;

  const ForumsError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class ForumsBloc extends Bloc<ForumsEvent, ForumsState> {
  final ForumsRepository _forumsRepository;

  ForumsBloc({required ForumsRepository forumsRepository})
      : _forumsRepository = forumsRepository,
        super(ForumsInitial()) {
    on<LoadForums>(_onLoadForums);
    on<CreateForum>(_onCreateForum);
    on<UpdateForum>(_onUpdateForum);
    on<DeleteForum>(_onDeleteForum);
    on<LoadComments>(_onLoadComments);
    on<AddComment>(_onAddComment);
    on<LikeComment>(_onLikeComment);
    on<DislikeComment>(_onDislikeComment);
  }

  Future<void> _onLoadForums(
    LoadForums event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      final forums = await _forumsRepository.getForums();
      emit(ForumsLoaded(forums: forums));
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }

  Future<void> _onCreateForum(
    CreateForum event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      await _forumsRepository.createForum(event.forum);
      final forums = await _forumsRepository.getForums();
      emit(ForumsLoaded(forums: forums));
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }

  Future<void> _onUpdateForum(
    UpdateForum event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      await _forumsRepository.updateForum(event.forum);
      final forums = await _forumsRepository.getForums();
      emit(ForumsLoaded(forums: forums));
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }

  Future<void> _onDeleteForum(
    DeleteForum event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      await _forumsRepository.deleteForum(event.forumId);
      final forums = await _forumsRepository.getForums();
      emit(ForumsLoaded(forums: forums));
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }

  Future<void> _onLoadComments(
    LoadComments event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      final comments = await _forumsRepository.getComments(event.forumId);
      if (state is ForumsLoaded) {
        emit(ForumsLoaded(
          forums: (state as ForumsLoaded).forums,
          comments: comments.cast<CommentModel>(),
        ));
      } else {
        final forums = await _forumsRepository.getForums();
        emit(ForumsLoaded(
            forums: forums, comments: comments.cast<CommentModel>()));
      }
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }

  Future<void> _onAddComment(
    AddComment event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      await _forumsRepository.addComment(event.comment);
      if (state is ForumsLoaded) {
        final comments = await _forumsRepository.getComments(
          event.comment.forumId,
        );
        emit(ForumsLoaded(
          forums: (state as ForumsLoaded).forums,
          comments: comments.cast<CommentModel>(),
        ));
      }
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }

  Future<void> _onLikeComment(
    LikeComment event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      await _forumsRepository.likeComment(event.commentId, event.userId);
      if (state is ForumsLoaded) {
        final comments = await _forumsRepository.getComments(
          (state as ForumsLoaded).comments.first.forumId,
        );
        emit(ForumsLoaded(
          forums: (state as ForumsLoaded).forums,
          comments: comments.cast<CommentModel>(),
        ));
      }
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }

  Future<void> _onDislikeComment(
    DislikeComment event,
    Emitter<ForumsState> emit,
  ) async {
    try {
      emit(ForumsLoading());
      await _forumsRepository.dislikeComment(event.commentId, event.userId);
      if (state is ForumsLoaded) {
        final comments = await _forumsRepository.getComments(
          (state as ForumsLoaded).comments.first.forumId,
        );
        emit(ForumsLoaded(
          forums: (state as ForumsLoaded).forums,
          comments: comments.cast<CommentModel>(),
        ));
      }
    } catch (e) {
      emit(ForumsError(e.toString()));
    }
  }
}
