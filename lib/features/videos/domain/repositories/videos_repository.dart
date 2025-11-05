import 'package:codequest/features/videos/domain/models/video_model.dart';

abstract class VideosRepository {
  Future<List<VideoModel>> getVideos();
  Future<List<VideoModel>> getPublishedVideos();
  Future<List<VideoModel>> getTeacherVideos(String teacherId);
  Future<List<VideoModel>> getWatchedVideos(String studentId);
  Future<VideoModel> getVideo(String videoId);
  Future<void> createVideo(VideoModel video);
  Future<void> updateVideo(VideoModel video);
  Future<void> deleteVideo(String videoId);
  Future<void> toggleVideoPublish(String videoId, bool isPublished);
  Future<void> recordVideoWatch(String studentId, String videoId);
  Future<void> recordVideoDownload(String studentId, String videoId);
  Future<int> getWatchProgress(String studentId, String videoId);
  Future<void> updateWatchProgress(
      String studentId, String videoId, int progress);
  Future<List<VideoModel>> getVideosByCategory(String category);
  Future<List<VideoModel>> getVideosByTag(String tag);
  Future<List<VideoModel>> getVideosByUser(String userId);
}
