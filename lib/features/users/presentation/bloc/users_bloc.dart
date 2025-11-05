import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:codequest/features/users/domain/repositories/users_repository.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';

// Events
abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object> get props => [];
}

class LoadUsers extends UsersEvent {}

class LoadUserActivity extends UsersEvent {
  final String userId;

  const LoadUserActivity(this.userId);

  @override
  List<Object> get props => [userId];
}

class CreateUser extends UsersEvent {
  final UserModel user;

  const CreateUser(this.user);

  @override
  List<Object> get props => [user];
}

class UpdateUser extends UsersEvent {
  final UserModel user;

  const UpdateUser(this.user);

  @override
  List<Object> get props => [user];
}

class DeleteUser extends UsersEvent {
  final String id;

  const DeleteUser(this.id);

  @override
  List<Object> get props => [id];
}

// States
abstract class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object> get props => [];
}

class UsersInitial extends UsersState {}

class UsersLoading extends UsersState {}

class UsersLoaded extends UsersState {
  final List<UserModel> users;
  final List<VideoModel> videos;
  final List<forum_model.ForumModel> forums;
  final List<CommentModel> comments;

  const UsersLoaded({
    required this.users,
    this.videos = const [],
    this.forums = const [],
    this.comments = const [],
  });

  @override
  List<Object> get props => [users, videos, forums, comments];
}

class UsersError extends UsersState {
  final String message;

  const UsersError(this.message);

  @override
  List<Object> get props => [message];
}

// Bloc
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final UsersRepository _usersRepository;

  UsersBloc(this._usersRepository) : super(UsersInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<LoadUserActivity>(_onLoadUserActivity);
    on<CreateUser>(_onCreateUser);
    on<UpdateUser>(_onUpdateUser);
    on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _onLoadUsers(
    LoadUsers event,
    Emitter<UsersState> emit,
  ) async {
    try {
      emit(UsersLoading());
      final users = await _usersRepository.getUsers();
      emit(UsersLoaded(users: users));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<void> _onLoadUserActivity(
    LoadUserActivity event,
    Emitter<UsersState> emit,
  ) async {
    try {
      emit(UsersLoading());
      final videos = await _usersRepository.getUserVideos(event.userId);
      final forums = await _usersRepository.getUserForums(event.userId);
      final comments = await _usersRepository.getUserComments(event.userId);
      emit(UsersLoaded(
        users: const [],
        videos: videos,
        forums: forums,
        comments: comments,
      ));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<void> _onCreateUser(
    CreateUser event,
    Emitter<UsersState> emit,
  ) async {
    try {
      emit(UsersLoading());
      await _usersRepository.createUser(event.user);
      final users = await _usersRepository.getUsers();
      emit(UsersLoaded(users: users));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<void> _onUpdateUser(
    UpdateUser event,
    Emitter<UsersState> emit,
  ) async {
    try {
      emit(UsersLoading());
      await _usersRepository.updateUser(event.user);
      final users = await _usersRepository.getUsers();
      emit(UsersLoaded(users: users));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<void> _onDeleteUser(
    DeleteUser event,
    Emitter<UsersState> emit,
  ) async {
    try {
      emit(UsersLoading());
      await _usersRepository.deleteUser(event.id);
      final users = await _usersRepository.getUsers();
      emit(UsersLoaded(users: users));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<forum_model.ForumModel?> getForumForComment(String forumId) async {
    try {
      return await _usersRepository.getForum(forumId);
    } catch (e) {
      return null;
    }
  }
}
