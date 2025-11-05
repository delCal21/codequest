import 'package:bloc/bloc.dart';
import 'package:codequest/features/challenges/data/challenge_repository.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

// Events
abstract class ChallengeEvent extends Equatable {
  const ChallengeEvent();

  @override
  List<Object?> get props => [];
}

class LoadChallenges extends ChallengeEvent {
  final bool isAdmin;
  const LoadChallenges({this.isAdmin = false});

  @override
  List<Object?> get props => [isAdmin];
}

class LoadSubmittedChallenges extends ChallengeEvent {
  final String studentId;

  const LoadSubmittedChallenges(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

class CreateChallenge extends ChallengeEvent {
  final String id;
  final String title;
  final String description;
  final String instructions;
  final ChallengeType type;
  final ChallengeDifficulty difficulty;
  final int? timeLimit;
  final double passingScore;
  final PlatformFile? file;
  final String createdBy;
  final String teacherId;
  final String teacherName;
  final List<String> testCases;
  final List<String> questions;
  final List<String> correctAnswers;
  final List<String>? options;
  final int lesson;
  final String? courseId;
  final String? language;
  final List<Map<String, dynamic>>? quizQuestions;
  final List<String>? blanks;
  final List<Map<String, dynamic>>? fillBlankQuestions;
  final List<Map<String, dynamic>>? codingProblems;
  final bool isPublished;

  const CreateChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.type,
    required this.difficulty,
    this.timeLimit,
    required this.passingScore,
    required this.createdBy,
    required this.teacherId,
    required this.teacherName,
    this.file,
    this.testCases = const [],
    this.questions = const [],
    this.correctAnswers = const [],
    this.options,
    this.lesson = 1,
    this.courseId,
    this.language,
    this.quizQuestions,
    this.blanks,
    this.fillBlankQuestions,
    this.codingProblems,
    this.isPublished = true,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        instructions,
        type,
        difficulty,
        timeLimit,
        passingScore,
        file,
        createdBy,
        teacherId,
        teacherName,
        testCases,
        questions,
        correctAnswers,
        options,
        lesson,
        courseId,
        language,
        quizQuestions,
        blanks,
        fillBlankQuestions,
        codingProblems,
        isPublished,
      ];
}

class UpdateChallenge extends ChallengeEvent {
  final ChallengeModel challenge;
  final PlatformFile? file;

  const UpdateChallenge({
    required this.challenge,
    this.file,
  });

  @override
  List<Object?> get props => [challenge, file];
}

class DeleteChallenge extends ChallengeEvent {
  final String challengeId;
  const DeleteChallenge(this.challengeId);

  @override
  List<Object?> get props => [challengeId];
}

class ToggleChallengePublish extends ChallengeEvent {
  final String challengeId;
  final bool isPublished;

  const ToggleChallengePublish(this.challengeId, this.isPublished);

  @override
  List<Object?> get props => [challengeId, isPublished];
}

class SubmitChallenge extends ChallengeEvent {
  final String studentId;
  final String challengeId;
  final PlatformFile submissionFile;

  const SubmitChallenge(this.studentId, this.challengeId, this.submissionFile);

  @override
  List<Object?> get props => [studentId, challengeId, submissionFile];
}

// States
abstract class ChallengeState extends Equatable {
  const ChallengeState();

  @override
  List<Object?> get props => [];
}

class ChallengeInitial extends ChallengeState {}

class ChallengeLoading extends ChallengeState {}

class ChallengeLoaded extends ChallengeState {
  final List<ChallengeModel> challenges;

  const ChallengeLoaded(this.challenges);

  @override
  List<Object?> get props => [challenges];
}

class ChallengeError extends ChallengeState {
  final String message;

  const ChallengeError(this.message);

  @override
  List<Object?> get props => [message];
}

class ChallengeActionSuccess extends ChallengeState {
  final String message;

  const ChallengeActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class ChallengeBloc extends Bloc<ChallengeEvent, ChallengeState> {
  final ChallengeRepository _challengeRepository;
  final FirebaseStorage _storage;

  ChallengeBloc(this._challengeRepository, this._storage)
      : super(ChallengeInitial()) {
    on<LoadChallenges>(_onLoadChallenges);
    on<LoadSubmittedChallenges>(_onLoadSubmittedChallenges);
    on<CreateChallenge>(_onCreateChallenge);
    on<UpdateChallenge>(_onUpdateChallenge);
    on<DeleteChallenge>(_onDeleteChallenge);
    on<ToggleChallengePublish>(_onToggleChallengePublish);
    on<SubmitChallenge>(_onSubmitChallenge);
  }

  Future<void> _onLoadChallenges(
      LoadChallenges event, Emitter<ChallengeState> emit) async {
    try {
      emit(ChallengeLoading());
      List<ChallengeModel> challenges;
      if (event.isAdmin) {
        challenges = await _challengeRepository.getAllChallenges();
      } else {
        // For teachers, load all challenges so they can see challenges from courses they teach/collaborate on
        // regardless of who created them or their publication status
        challenges = await _challengeRepository.getAllChallenges();
      }
      emit(ChallengeLoaded(challenges));
    } catch (e) {
      emit(ChallengeError(e.toString()));
    }
  }

  Future<void> _onLoadSubmittedChallenges(
      LoadSubmittedChallenges event, Emitter<ChallengeState> emit) async {
    try {
      emit(ChallengeLoading());
      final challenges =
          await _challengeRepository.getSubmittedChallenges(event.studentId);
      emit(ChallengeLoaded(challenges));
    } catch (e) {
      emit(ChallengeError(e.toString()));
    }
  }

  Future<void> _onCreateChallenge(
      CreateChallenge event, Emitter<ChallengeState> emit) async {
    try {
      emit(ChallengeLoading());
      print('Starting challenge creation...');

      // Handle file upload first if it's a coding challenge
      String? fileUrl;
      if (event.type == ChallengeType.coding && event.file != null) {
        try {
          print('Uploading file for coding challenge...');
          print('File details:');
          print('Name: ${event.file!.name}');
          print('Size: ${event.file!.size}');
          print('Extension: ${event.file!.extension}');
          print('Has bytes: ${event.file!.bytes != null}');

          if (event.file!.bytes == null) {
            throw Exception('File data is missing');
          }

          // Create a reference to the file location in Firebase Storage
          final storageRef = _storage.ref();
          final fileRef = storageRef.child('challenges/${event.file!.name}');

          // Check if user is authenticated before uploading
          final auth = FirebaseAuth.instance;
          if (auth.currentUser == null) {
            throw Exception('User must be authenticated to upload files');
          }

          print('User authenticated: ${auth.currentUser!.email}');
          print('Uploading to path: challenges/${event.file!.name}');

          // Upload the file with better error handling
          final uploadTask = fileRef.putData(
            event.file!.bytes!,
            SettableMetadata(
              contentType: 'text/plain', // Default to text/plain
              customMetadata: {
                'challengeId': event.id,
                'fileName': event.file!.name,
                'uploadedBy': auth.currentUser!.uid,
                'uploadedAt': DateTime.now().toIso8601String(),
              },
            ),
          );

          // Wait for the upload to complete with timeout
          final snapshot = await uploadTask.timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              throw Exception('File upload timed out. Please try again.');
            },
          );

          print(
              'File upload completed. Bytes transferred: ${snapshot.bytesTransferred}');

          // Get the download URL with retry logic
          int retryCount = 0;
          const maxRetries = 3;

          while (retryCount < maxRetries) {
            try {
              fileUrl = await fileRef.getDownloadURL();
              print('File URL: $fileUrl');
              break;
            } catch (e) {
              retryCount++;
              if (retryCount >= maxRetries) {
                throw Exception(
                    'Failed to get download URL after $maxRetries attempts: $e');
              }
              print(
                  'Retry $retryCount: Failed to get download URL, retrying...');
              await Future.delayed(Duration(seconds: retryCount));
            }
          }
        } catch (e) {
          print('Error uploading file: $e');
          emit(ChallengeError('Failed to upload file: $e'));
          return;
        }
      }

      // Create the challenge model
      final challenge = ChallengeModel(
        id: event.id,
        title: event.title,
        description: event.description,
        instructions: event.instructions,
        type: event.type,
        difficulty: event.difficulty,
        timeLimit: event.timeLimit ?? 0,
        passingScore: event.passingScore,
        fileUrl: fileUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: event.createdBy,
        teacherId: event.teacherId,
        teacherName: event.teacherName,
        testCases: event.testCases,
        questions: event.questions,
        correctAnswers: event.correctAnswers,
        options: event.options,
        lesson: event.lesson,
        isPublished: event.isPublished,
        courseId: event.courseId,
        language: event.language,
        quizQuestions: event.quizQuestions,
        blanks: event.blanks,
        fillBlankQuestions: event.fillBlankQuestions,
        codingProblems: event.codingProblems,
      );

      print('Creating challenge with data:');
      print('ID: ${challenge.id}');
      print('Title: ${challenge.title}');
      print('Type: ${challenge.type}');
      print('Course ID: ${challenge.courseId}');
      print('Lesson: ${challenge.lesson}');
      print('Language: ${challenge.language}');
      print('File URL: ${challenge.fileUrl}');

      // Create the challenge in Firestore
      await _challengeRepository.createChallenge(challenge);
      print('Challenge created successfully');

      // Reload challenges
      add(const LoadChallenges(isAdmin: true));
    } catch (e) {
      print('Error creating challenge: $e');
      emit(ChallengeError(e.toString()));
    }
  }

  Future<void> _onUpdateChallenge(
      UpdateChallenge event, Emitter<ChallengeState> emit) async {
    try {
      emit(ChallengeLoading());

      ChallengeModel updatedChallenge = event.challenge;
      if (event.file != null) {
        // Upload new file
        final fileName = event.file!.name;
        final ref = _storage.ref().child('challenges/$fileName');

        if (event.file!.bytes == null) {
          throw Exception('File bytes are null for upload.');
        }
        await ref.putData(event.file!.bytes!);
        final fileUrl = await ref.getDownloadURL();

        updatedChallenge = updatedChallenge.copyWith(
          fileUrl: fileUrl,
          fileName: fileName,
        );
      }

      await _challengeRepository.updateChallenge(
          updatedChallenge.id, updatedChallenge);
      add(const LoadChallenges(isAdmin: true));
    } catch (e) {
      emit(ChallengeError(e.toString()));
    }
  }

  Future<void> _onDeleteChallenge(
      DeleteChallenge event, Emitter<ChallengeState> emit) async {
    try {
      await _challengeRepository.deleteChallenge(event.challengeId);
      emit(const ChallengeActionSuccess('Challenge deleted successfully!'));
      add(const LoadChallenges(isAdmin: true));
    } catch (e) {
      emit(ChallengeError(e.toString()));
    }
  }

  Future<void> _onToggleChallengePublish(
      ToggleChallengePublish event, Emitter<ChallengeState> emit) async {
    try {
      await _challengeRepository.toggleChallengePublish(
          event.challengeId, event.isPublished);
      emit(ChallengeActionSuccess(event.isPublished
          ? 'Challenge published successfully!'
          : 'Challenge unpublished successfully!'));
      add(const LoadChallenges(isAdmin: true));
    } catch (e) {
      emit(ChallengeError(e.toString()));
    }
  }

  Future<void> _onSubmitChallenge(
      SubmitChallenge event, Emitter<ChallengeState> emit) async {
    try {
      emit(ChallengeLoading());

      // Upload submission file to Firebase Storage
      final fileName = event.submissionFile.name;
      final ref = _storage.ref().child('challenge_submissions/$fileName');

      if (event.submissionFile.bytes == null) {
        throw Exception('File bytes are null for upload.');
      }
      await ref.putData(event.submissionFile.bytes!);
      final fileUrl = await ref.getDownloadURL();

      // Submit challenge
      await _challengeRepository.submitChallenge(
        event.challengeId,
        fileUrl,
      );

      add(LoadSubmittedChallenges(event.studentId));
    } catch (e) {
      emit(ChallengeError(e.toString()));
    }
  }
}
