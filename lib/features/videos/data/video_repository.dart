// ... code adapted from course_repository.dart, but for videos ...

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/services/notification_service.dart';
import 'package:codequest/services/activity_service.dart';
import 'package:codequest/features/admin/domain/models/activity_model.dart';

class VideoRepository {
  final FirebaseFirestore _firestore;
  VideoRepository(this._firestore);

  // Get all published videos (for students)
  Future<List<VideoModel>> getPublishedVideos() async {
    final snapshot = await _firestore
        .collection('videos')
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => VideoModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get videos by teacher (for teachers)
  Future<List<VideoModel>> getTeacherVideos(String teacherId) async {
    final snapshot = await _firestore
        .collection('videos')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => VideoModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get videos by course (for students)
  Future<List<VideoModel>> getVideosByCourse(String courseId) async {
    final snapshot = await _firestore
        .collection('videos')
        .where('courseId', isEqualTo: courseId)
        .where('isPublished', isEqualTo: true) // Only show published videos
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => VideoModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get all videos (for admin)
  Future<List<VideoModel>> getAllVideos() async {
    final snapshot = await _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => VideoModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Create new video (for admin/teacher)
  Future<String> createVideo(VideoModel video) async {
    final docRef = await _firestore.collection('videos').add(video.toJson());
    // Create admin notification
    await NotificationService.notifyVideoEvent(
      type: 'created',
      videoId: docRef.id,
      videoTitle: video.title,
      userId: video.teacherId,
      userName: video.teacherName,
      videoData: video.toJson(),
    );

    // Log activity
    await ActivityService.logVideoActivity(
      activityType: ActivityType.videoCreated,
      videoId: docRef.id,
      videoTitle: video.title,
      courseId: video.courseId,
    );

    return docRef.id;
  }

  // Update video (for admin/teacher)
  Future<void> updateVideo(String videoId, VideoModel video) async {
    await _firestore.collection('videos').doc(videoId).update(video.toJson());
    // Create admin notification
    await NotificationService.notifyVideoEvent(
      type: 'updated',
      videoId: videoId,
      videoTitle: video.title,
      userId: video.teacherId,
      userName: video.teacherName,
      videoData: video.toJson(),
    );

    // Log activity
    await ActivityService.logVideoActivity(
      activityType: ActivityType.videoUpdated,
      videoId: videoId,
      videoTitle: video.title,
      courseId: video.courseId,
    );
  }

  // Delete video (for admin)
  Future<void> deleteVideo(String videoId) async {
    // Get video data before deletion for notification
    final videoDoc = await _firestore.collection('videos').doc(videoId).get();
    final videoData = videoDoc.data();
    await _firestore.collection('videos').doc(videoId).delete();
    // Create admin notification
    if (videoData != null) {
      await NotificationService.notifyVideoEvent(
        type: 'deleted',
        videoId: videoId,
        videoTitle: videoData['title'] ?? 'Unknown Video',
        userId: videoData['teacherId'] ?? 'unknown',
        userName: videoData['teacherName'] ?? 'Unknown User',
        videoData: videoData,
      );

      // Log activity
      await ActivityService.logVideoActivity(
        activityType: ActivityType.videoDeleted,
        videoId: videoId,
        videoTitle: videoData['title'] ?? 'Unknown Video',
        courseId: videoData['courseId'],
      );
    }
  }

  // Publish/Unpublish video (for admin/teacher)
  Future<void> toggleVideoPublish(String videoId, bool isPublished) async {
    await _firestore
        .collection('videos')
        .doc(videoId)
        .update({'isPublished': isPublished});
  }

  // Get watched videos (for students)
  Future<List<VideoModel>> getWatchedVideos(String studentId) async {
    final watchHistorySnapshot = await _firestore
        .collection('watch_history')
        .where('studentId', isEqualTo: studentId)
        .get();

    final videoIds = watchHistorySnapshot.docs
        .map((doc) => doc.data()['videoId'] as String)
        .toList();

    if (videoIds.isEmpty) return [];

    final videosSnapshot = await _firestore
        .collection('videos')
        .where(FieldPath.documentId, whereIn: videoIds)
        .get();

    return videosSnapshot.docs
        .map((doc) => VideoModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Record video watch (for students)
  Future<void> recordVideoWatch(String studentId, String videoId) async {
    // Add to watch history
    await _firestore.collection('watch_history').add({
      'studentId': studentId,
      'videoId': videoId,
      'watchedAt': FieldValue.serverTimestamp(),
      'progress': 0,
    });

    // Update view count
    await _firestore.collection('videos').doc(videoId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  // Record video download (for students)
  Future<void> recordVideoDownload(String studentId, String videoId) async {
    // Add to download history
    await _firestore.collection('download_history').add({
      'studentId': studentId,
      'videoId': videoId,
      'downloadedAt': FieldValue.serverTimestamp(),
    });

    // Update download count
    await _firestore.collection('videos').doc(videoId).update({
      'downloadCount': FieldValue.increment(1),
    });
  }

  // Get watch progress (for students)
  Future<int> getWatchProgress(String studentId, String videoId) async {
    final watchHistorySnapshot = await _firestore
        .collection('watch_history')
        .where('studentId', isEqualTo: studentId)
        .where('videoId', isEqualTo: videoId)
        .orderBy('watchedAt', descending: true)
        .limit(1)
        .get();

    if (watchHistorySnapshot.docs.isEmpty) return 0;
    return watchHistorySnapshot.docs.first.data()['progress'] as int? ?? 0;
  }

  // Update watch progress (for students)
  Future<void> updateWatchProgress(
      String studentId, String videoId, int progress) async {
    final watchHistorySnapshot = await _firestore
        .collection('watch_history')
        .where('studentId', isEqualTo: studentId)
        .where('videoId', isEqualTo: videoId)
        .orderBy('watchedAt', descending: true)
        .limit(1)
        .get();

    if (watchHistorySnapshot.docs.isEmpty) {
      // Create new watch history entry
      await _firestore.collection('watch_history').add({
        'studentId': studentId,
        'videoId': videoId,
        'watchedAt': FieldValue.serverTimestamp(),
        'progress': progress,
      });
    } else {
      // Update existing watch history entry
      await _firestore
          .collection('watch_history')
          .doc(watchHistorySnapshot.docs.first.id)
          .update({
        'progress': progress,
        'watchedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get videos by category
  Future<List<VideoModel>> getVideosByCategory(String category) async {
    final snapshot = await _firestore
        .collection('videos')
        .where('category', isEqualTo: category)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => VideoModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get videos by tag
  Future<List<VideoModel>> getVideosByTag(String tag) async {
    final snapshot = await _firestore
        .collection('videos')
        .where('tags', arrayContains: tag)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => VideoModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get video details
  Future<VideoModel?> getVideoById(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) return null;
    return VideoModel.fromJson(doc.data()!..['id'] = doc.id);
  }
}
