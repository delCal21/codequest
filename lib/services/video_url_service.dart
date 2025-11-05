import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoUrlService {
  /// Test if a video URL is accessible
  static Future<bool> isUrlAccessible(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('URL accessibility test failed: $e');
      return false;
    }
  }

  /// Validate video URL format
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.scheme.startsWith('http');
    } catch (e) {
      return false;
    }
  }

  /// Get a fresh download URL for a Firebase Storage reference
  static Future<String?> getFreshDownloadUrl(String path) async {
    try {
      const bucketName = 'codequest-a5317.firebasestorage.app';
      final storage = FirebaseStorage.instanceFor(bucket: bucketName);
      final ref = storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting fresh download URL: $e');
      return null;
    }
  }

  /// Refresh video URL in the database
  static Future<bool> refreshVideoUrlInDatabase(String videoId) async {
    try {
      // Get video document
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!videoDoc.exists) {
        print('Video document not found: $videoId');
        return false;
      }

      final videoData = videoDoc.data()!;
      final fileName = videoData['fileName'] as String?;

      if (fileName == null || fileName.isEmpty) {
        print('No fileName found for video: $videoId');
        return false;
      }

      // Get fresh URL
      final freshUrl = await getFreshDownloadUrl('videos/$fileName');
      if (freshUrl == null) {
        print('Could not get fresh URL for video: $videoId');
        return false;
      }

      // Update the video document with fresh URL
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .update({
        'videoUrl': freshUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Successfully refreshed URL for video: $videoId');
      return true;
    } catch (e) {
      print('Error refreshing video URL in database: $e');
      return false;
    }
  }

  /// Get comprehensive debug information for a video
  static Future<Map<String, dynamic>> debugVideo(String videoId) async {
    final result = <String, dynamic>{
      'videoId': videoId,
      'exists': false,
      'videoData': null,
      'urlInfo': null,
      'storageInfo': null,
      'errors': <String>[],
    };

    try {
      // Get video from database
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!videoDoc.exists) {
        result['errors'].add('Video document not found in database');
        return result;
      }

      result['exists'] = true;
      result['videoData'] = videoDoc.data();

      final videoData = videoDoc.data()!;
      final videoUrl = videoData['videoUrl'] as String?;
      final fileName = videoData['fileName'] as String?;

      if (videoUrl == null || videoUrl.isEmpty) {
        result['errors'].add('No videoUrl found in database');
        return result;
      }

      // Debug URL
      result['urlInfo'] = await debugVideoUrl(videoUrl);

      // Check storage file
      if (fileName != null && fileName.isNotEmpty) {
        try {
          const bucketName = 'codequest-a5317.firebasestorage.app';
          final storage = FirebaseStorage.instanceFor(bucket: bucketName);
          final ref = storage.ref().child('videos/$fileName');

          final metadata = await ref.getMetadata();
          result['storageInfo'] = {
            'exists': true,
            'size': metadata.size,
            'contentType': metadata.contentType,
            'timeCreated': metadata.timeCreated?.toIso8601String(),
            'updated': metadata.updated?.toIso8601String(),
          };
        } catch (e) {
          result['storageInfo'] = {
            'exists': false,
            'error': e.toString(),
          };
          result['errors'].add('Storage file not accessible: $e');
        }
      } else {
        result['errors'].add('No fileName found in database');
      }
    } catch (e) {
      result['errors'].add('Database error: $e');
    }

    return result;
  }

  /// Debug video URL information
  static Future<Map<String, dynamic>> debugVideoUrl(String url) async {
    final result = <String, dynamic>{
      'url': url,
      'isValid': isValidUrl(url),
      'isAccessible': false,
      'statusCode': null,
      'error': null,
    };

    if (!result['isValid']) {
      result['error'] = 'Invalid URL format';
      return result;
    }

    try {
      final response = await http.head(Uri.parse(url));
      result['statusCode'] = response.statusCode;
      result['isAccessible'] = response.statusCode == 200;
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }
}
