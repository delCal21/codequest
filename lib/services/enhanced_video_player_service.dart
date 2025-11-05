import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:codequest/services/video_url_service.dart';

class EnhancedVideoPlayerService {
  /// Try multiple methods to play a video
  static Future<bool> playVideo({
    required String videoUrl,
    required String videoTitle,
    required BuildContext context,
  }) async {
    try {
      // Method 1: Try direct video player
      final directPlayerSuccess = await _tryDirectVideoPlayer(
        videoUrl: videoUrl,
        videoTitle: videoTitle,
        context: context,
      );

      if (directPlayerSuccess) return true;

      // Method 2: Try URL launcher with multiple modes
      final urlLauncherSuccess = await _tryUrlLauncher(
        videoUrl: videoUrl,
        context: context,
      );

      if (urlLauncherSuccess) return true;

      // Method 3: Show manual options
      await _showManualOptions(
        videoUrl: videoUrl,
        videoTitle: videoTitle,
        context: context,
      );

      return false;
    } catch (e) {
      print('Enhanced video player error: $e');
      return false;
    }
  }

  /// Try direct video player
  static Future<bool> _tryDirectVideoPlayer({
    required String videoUrl,
    required String videoTitle,
    required BuildContext context,
  }) async {
    try {
      // Check if URL is accessible
      final isAccessible = await VideoUrlService.isUrlAccessible(videoUrl);
      if (!isAccessible) return false;

      // Try to create video player controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        },
      );

      await controller.initialize();

      if (controller.value.isInitialized) {
        // Show video player dialog
        await _showVideoPlayerDialog(
          controller: controller,
          videoTitle: videoTitle,
          context: context,
        );
        return true;
      }

      controller.dispose();
      return false;
    } catch (e) {
      print('Direct video player failed: $e');
      return false;
    }
  }

  /// Try URL launcher with multiple modes
  static Future<bool> _tryUrlLauncher({
    required String videoUrl,
    required BuildContext context,
  }) async {
    try {
      final url = Uri.parse(videoUrl);

      // Try different launch modes
      final modes = [
        LaunchMode.externalApplication,
        LaunchMode.platformDefault,
        LaunchMode.inAppWebView,
      ];

      for (final mode in modes) {
        if (await canLaunchUrl(url)) {
          final launched = await launchUrl(url, mode: mode);
          if (launched) return true;
        }
      }

      return false;
    } catch (e) {
      print('URL launcher failed: $e');
      return false;
    }
  }

  /// Show manual options dialog
  static Future<void> _showManualOptions({
    required String videoUrl,
    required String videoTitle,
    required BuildContext context,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Video Playback Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Unable to automatically open the video. Please choose an option:'),
            const SizedBox(height: 16),
            Text(
              'Video: $videoTitle',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'URL: ${videoUrl.length > 50 ? '${videoUrl.substring(0, 50)}...' : videoUrl}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy URL'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: videoUrl));
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video URL copied to clipboard'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
            onPressed: () async {
              try {
                final url = Uri.parse(videoUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to open browser: $e')),
                  );
                }
              }
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  /// Show video player dialog
  static Future<void> _showVideoPlayerDialog({
    required VideoPlayerController controller,
    required String videoTitle,
    required BuildContext context,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        videoTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Video player
              Expanded(
                child: Chewie(
                  controller: ChewieController(
                    videoPlayerController: controller,
                    autoPlay: true,
                    looping: false,
                    showControls: true,
                    materialProgressColors: ChewieProgressColors(
                      playedColor: Colors.blue,
                      handleColor: Colors.blue,
                      backgroundColor: Colors.grey[300]!,
                      bufferedColor: Colors.grey[300]!,
                    ),
                    errorBuilder: (context, errorMessage) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Error playing video: $errorMessage',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
