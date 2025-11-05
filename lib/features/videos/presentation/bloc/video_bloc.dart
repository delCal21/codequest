import 'package:bloc/bloc.dart';
import 'package:codequest/features/videos/data/video_repository.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Events
abstract class VideoEvent extends Equatable {
  const VideoEvent();

  @override
  List<Object?> get props => [];
}

class LoadVideos extends VideoEvent {
  final String? teacherId;
  final bool isAdmin;

  const LoadVideos({this.teacherId, this.isAdmin = false});

  @override
  List<Object?> get props => [teacherId, isAdmin];
}

class LoadWatchedVideos extends VideoEvent {
  final String studentId;

  const LoadWatchedVideos(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

class CreateVideo extends VideoEvent {
  final VideoModel video;
  final PlatformFile selectedFile;

  const CreateVideo(this.video, this.selectedFile);

  @override
  List<Object?> get props => [video, selectedFile];
}

class UpdateVideo extends VideoEvent {
  final String videoId;
  final VideoModel video;
  final PlatformFile? selectedFile;

  const UpdateVideo(this.videoId, this.video, {this.selectedFile});

  @override
  List<Object?> get props => [videoId, video, selectedFile];
}

class DeleteVideo extends VideoEvent {
  final String videoId;

  const DeleteVideo(this.videoId);

  @override
  List<Object?> get props => [videoId];
}

class ToggleVideoPublish extends VideoEvent {
  final String videoId;
  final bool isPublished;

  const ToggleVideoPublish(this.videoId, this.isPublished);

  @override
  List<Object?> get props => [videoId, isPublished];
}

class RecordVideoWatch extends VideoEvent {
  final String studentId;
  final String videoId;

  const RecordVideoWatch(this.studentId, this.videoId);

  @override
  List<Object?> get props => [studentId, videoId];
}

class UpdateWatchProgress extends VideoEvent {
  final String studentId;
  final String videoId;
  final int progress;

  const UpdateWatchProgress(this.studentId, this.videoId, this.progress);

  @override
  List<Object?> get props => [studentId, videoId, progress];
}

// States
abstract class VideoState extends Equatable {
  const VideoState();

  @override
  List<Object?> get props => [];
}

class VideoInitial extends VideoState {}

class VideoLoading extends VideoState {}

class VideoLoaded extends VideoState {
  final List<VideoModel> videos;

  const VideoLoaded(this.videos);

  @override
  List<Object?> get props => [videos];
}

class VideoError extends VideoState {
  final String message;

  const VideoError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class VideoBloc extends Bloc<VideoEvent, VideoState> {
  final VideoRepository _videoRepository;

  VideoBloc(this._videoRepository) : super(VideoInitial()) {
    on<LoadVideos>(_onLoadVideos);
    on<LoadWatchedVideos>(_onLoadWatchedVideos);
    on<CreateVideo>(_onCreateVideo);
    on<UpdateVideo>(_onUpdateVideo);
    on<DeleteVideo>(_onDeleteVideo);
    on<ToggleVideoPublish>(_onToggleVideoPublish);
    on<RecordVideoWatch>(_onRecordVideoWatch);
    on<UpdateWatchProgress>(_onUpdateWatchProgress);
  }

  Future<void> _onLoadVideos(LoadVideos event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());
      List<VideoModel> videos;
      if (event.isAdmin) {
        videos = await _videoRepository.getAllVideos();
      } else if (event.teacherId != null) {
        videos = await _videoRepository.getTeacherVideos(event.teacherId!);
      } else {
        videos = await _videoRepository.getPublishedVideos();
      }
      emit(VideoLoaded(videos));
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> _onLoadWatchedVideos(
      LoadWatchedVideos event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());
      final videos = await _videoRepository.getWatchedVideos(event.studentId);
      emit(VideoLoaded(videos));
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> _onCreateVideo(
      CreateVideo event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());

      final fileName = event.selectedFile.name;
      // Use the same bucket configuration as video_form.dart
      const bucketName = 'codequest-a5317.firebasestorage.app';
      final storage = FirebaseStorage.instanceFor(bucket: bucketName);
      final ref = storage.ref().child('videos/$fileName');

      if (event.selectedFile.bytes == null) {
        throw Exception('File bytes are null for upload.');
      }

      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'originalName': fileName,
          'uploadTime': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final uploadTask = ref.putData(event.selectedFile.bytes!, metadata);
      await uploadTask;
      final fileUrl = await ref.getDownloadURL();

      // Create video with file URL
      final video = event.video.copyWith(
        videoUrl: fileUrl,
        fileName: fileName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _videoRepository.createVideo(video);

      // Load updated video list
      if (video.teacherId.isNotEmpty) {
        final videos = await _videoRepository.getTeacherVideos(video.teacherId);
        emit(VideoLoaded(videos));
      } else {
        final videos = await _videoRepository.getAllVideos();
        emit(VideoLoaded(videos));
      }
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> _onUpdateVideo(
      UpdateVideo event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());

      VideoModel updatedVideo = event.video;
      if (event.selectedFile != null) {
        // Upload new file
        final fileName = event.selectedFile!.name;
        // Use the same bucket configuration as video_form.dart
        const bucketName = 'codequest-a5317.firebasestorage.app';
        final storage = FirebaseStorage.instanceFor(bucket: bucketName);
        final ref = storage.ref().child('videos/$fileName');

        if (event.selectedFile!.bytes == null) {
          throw Exception('File bytes are null for upload.');
        }

        final metadata = SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'originalName': fileName,
            'uploadTime': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );

        final uploadTask = ref.putData(event.selectedFile!.bytes!, metadata);
        await uploadTask;
        final fileUrl = await ref.getDownloadURL();

        updatedVideo = event.video.copyWith(
          videoUrl: fileUrl,
          fileName: fileName,
          updatedAt: DateTime.now(),
        );
      }

      await _videoRepository.updateVideo(event.videoId, updatedVideo);
      add(LoadVideos());
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> _onDeleteVideo(
      DeleteVideo event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());
      await _videoRepository.deleteVideo(event.videoId);
      add(LoadVideos());
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> _onToggleVideoPublish(
      ToggleVideoPublish event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());
      await _videoRepository.toggleVideoPublish(
          event.videoId, event.isPublished);
      add(LoadVideos());
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> _onRecordVideoWatch(
      RecordVideoWatch event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());
      await _videoRepository.recordVideoWatch(event.studentId, event.videoId);
      add(LoadVideos());
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> _onUpdateWatchProgress(
      UpdateWatchProgress event, Emitter<VideoState> emit) async {
    try {
      emit(VideoLoading());
      await _videoRepository.updateWatchProgress(
          event.studentId, event.videoId, event.progress);
      add(LoadVideos());
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }
}
