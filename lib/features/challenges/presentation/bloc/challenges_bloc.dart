import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/domain/repositories/challenges_repository.dart';

// Events
abstract class ChallengesEvent extends Equatable {
  const ChallengesEvent();

  @override
  List<Object> get props => [];
}

class LoadChallenges extends ChallengesEvent {
  final String? difficulty;
  final String? category;

  const LoadChallenges({this.difficulty, this.category});

  @override
  List<Object> get props => [difficulty ?? '', category ?? ''];
}

class CreateChallenge extends ChallengesEvent {
  final ChallengeModel challenge;

  const CreateChallenge(this.challenge);

  @override
  List<Object> get props => [challenge];
}

class UpdateChallenge extends ChallengesEvent {
  final ChallengeModel challenge;

  const UpdateChallenge(this.challenge);

  @override
  List<Object> get props => [challenge];
}

class DeleteChallenge extends ChallengesEvent {
  final String challengeId;

  const DeleteChallenge(this.challengeId);

  @override
  List<Object> get props => [challengeId];
}

// States
abstract class ChallengesState extends Equatable {
  const ChallengesState();

  @override
  List<Object> get props => [];
}

class ChallengesInitial extends ChallengesState {}

class ChallengesLoading extends ChallengesState {}

class ChallengesLoaded extends ChallengesState {
  final List<ChallengeModel> challenges;

  const ChallengesLoaded(this.challenges);

  @override
  List<Object> get props => [challenges];
}

class ChallengesError extends ChallengesState {
  final String message;

  const ChallengesError(this.message);

  @override
  List<Object> get props => [message];
}

// Bloc
class ChallengesBloc extends Bloc<ChallengesEvent, ChallengesState> {
  final ChallengesRepository _challengesRepository;

  ChallengesBloc(this._challengesRepository) : super(ChallengesInitial()) {
    on<LoadChallenges>(_onLoadChallenges);
    on<CreateChallenge>(_onCreateChallenge);
    on<UpdateChallenge>(_onUpdateChallenge);
    on<DeleteChallenge>(_onDeleteChallenge);
  }

  Future<void> _onLoadChallenges(
    LoadChallenges event,
    Emitter<ChallengesState> emit,
  ) async {
    try {
      emit(ChallengesLoading());
      final challenges = await _challengesRepository.getChallenges(
        difficulty: event.difficulty,
        category: event.category,
      );
      emit(ChallengesLoaded(challenges));
    } catch (e) {
      emit(ChallengesError(e.toString()));
    }
  }

  Future<void> _onCreateChallenge(
    CreateChallenge event,
    Emitter<ChallengesState> emit,
  ) async {
    try {
      emit(ChallengesLoading());
      await _challengesRepository.createChallenge(event.challenge);
      final challenges = await _challengesRepository.getChallenges();
      emit(ChallengesLoaded(challenges));
    } catch (e) {
      emit(ChallengesError(e.toString()));
    }
  }

  Future<void> _onUpdateChallenge(
    UpdateChallenge event,
    Emitter<ChallengesState> emit,
  ) async {
    try {
      emit(ChallengesLoading());
      await _challengesRepository.updateChallenge(event.challenge);
      final challenges = await _challengesRepository.getChallenges();
      emit(ChallengesLoaded(challenges));
    } catch (e) {
      emit(ChallengesError(e.toString()));
    }
  }

  Future<void> _onDeleteChallenge(
    DeleteChallenge event,
    Emitter<ChallengesState> emit,
  ) async {
    try {
      emit(ChallengesLoading());
      await _challengesRepository.deleteChallenge(event.challengeId);
      final challenges = await _challengesRepository.getChallenges();
      emit(ChallengesLoaded(challenges));
    } catch (e) {
      emit(ChallengesError(e.toString()));
    }
  }
}
