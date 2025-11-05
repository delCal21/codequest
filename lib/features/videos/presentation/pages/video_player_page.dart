import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:codequest/services/video_url_service.dart';

class VideoPlayerPage extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerPage({super.key, required this.video});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.video.mediaType == 'mp4') {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      // Validate video URL
      if (widget.video.videoUrl.isEmpty) {
        throw Exception('Video URL is empty');
      }

      print('Initializing video player with URL: ${widget.video.videoUrl}');

      // Validate URL format
      if (!VideoUrlService.isValidUrl(widget.video.videoUrl)) {
        throw Exception('Invalid video URL format: ${widget.video.videoUrl}');
      }

      // Test URL accessibility
      print('Testing URL accessibility...');
      final isAccessible =
          await VideoUrlService.isUrlAccessible(widget.video.videoUrl);
      if (!isAccessible) {
        // Try to get comprehensive debug information
        final debugInfo = await VideoUrlService.debugVideo(widget.video.id);
        print('Comprehensive debug info: $debugInfo');

        // Try to refresh the URL automatically
        print('Attempting to refresh video URL...');
        final refreshSuccess =
            await VideoUrlService.refreshVideoUrlInDatabase(widget.video.id);
        if (refreshSuccess) {
          print('URL refreshed successfully, reloading video...');
          // Reload the page with refreshed data
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(video: widget.video),
              ),
            );
            return;
          }
        }

        throw Exception(
            'Video URL is not accessible: ${widget.video.videoUrl}');
      }
      print(
          'URL is accessible, proceeding with video player initialization...');

      // Dispose previous controllers if they exist
      if (_videoPlayerController != null) {
        _videoPlayerController!.dispose();
        _videoPlayerController = null;
      }
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }

      // Create new video player controller
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        },
      );

      // Initialize the controller
      await _videoPlayerController!.initialize();

      // Check if the video actually loaded
      if (!_videoPlayerController!.value.isInitialized) {
        throw Exception('Video player failed to initialize');
      }

      if (!mounted) return;

      // Create Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor:
              Theme.of(context).primaryColor.withAlpha((0.1 * 255).toInt()),
          handleColor:
              Theme.of(context).primaryColor.withAlpha((0.1 * 255).toInt()),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 42),
                const SizedBox(height: 16),
                Text(
                  'Error loading video: [1m${errorMessage.toString()}[0m',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.red, fontFamily: 'NotoSans'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitialized = false;
                      _errorMessage = null;
                    });
                    _initializePlayer();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      print('Error initializing video player: ${e.toString()}');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: [1m${e.toString()}[0m'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          if (widget.video.mediaType == 'mp4')
            if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading video: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.red, fontFamily: 'NotoSans'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If the video URL is valid but won\'t play, try using the "Open in Browser" button or copy the URL to open in another app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontFamily: 'NotoSans',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isInitialized = false;
                            _errorMessage = null;
                          });
                          _initializePlayer();
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Open in Browser'),
                        onPressed: () async {
                          try {
                            final url = Uri.parse(widget.video.videoUrl);

                            // Try different launch modes
                            bool launched = false;

                            // First try with external application
                            if (await canLaunchUrl(url)) {
                              launched = await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }

                            // If that fails, try with platform default
                            if (!launched && await canLaunchUrl(url)) {
                              launched = await launchUrl(
                                url,
                                mode: LaunchMode.platformDefault,
                              );
                            }

                            // If still fails, try with inAppWebView
                            if (!launched && await canLaunchUrl(url)) {
                              launched = await launchUrl(
                                url,
                                mode: LaunchMode.inAppWebView,
                              );
                            }

                            if (!launched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Could not open video URL. Please try copying the URL manually.'),
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening URL: $e'),
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh URL'),
                        onPressed: () async {
                          setState(() {
                            _isInitialized = false;
                            _errorMessage = null;
                          });
                          await _initializePlayer();
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Get Fresh URL'),
                        onPressed: () async {
                          try {
                            // Try to get a fresh URL from Firebase Storage
                            final fileName = widget.video.fileName;
                            if (fileName.isNotEmpty) {
                              final freshUrl =
                                  await VideoUrlService.getFreshDownloadUrl(
                                      'videos/$fileName');
                              if (freshUrl != null) {
                                // Update the video model with fresh URL
                                final updatedVideo =
                                    widget.video.copyWith(videoUrl: freshUrl);
                                // Navigate to new video player with fresh URL
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        VideoPlayerPage(video: updatedVideo),
                                  ),
                                );
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Could not get fresh URL')),
                                  );
                                }
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No file name available')),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Error getting fresh URL: $e')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Debug Info'),
                        onPressed: () async {
                          try {
                            final debugInfo = await VideoUrlService.debugVideo(
                                widget.video.id);
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Video Debug Information'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            'Video ID: ${debugInfo['videoId']}'),
                                        const SizedBox(height: 8),
                                        Text(
                                            'Exists in DB: ${debugInfo['exists']}'),
                                        const SizedBox(height: 8),
                                        if (debugInfo['urlInfo'] != null) ...[
                                          const Text('URL Information:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              'URL: ${debugInfo['urlInfo']['url']}'),
                                          Text(
                                              'Valid: ${debugInfo['urlInfo']['isValid']}'),
                                          Text(
                                              'Accessible: ${debugInfo['urlInfo']['isAccessible']}'),
                                          Text(
                                              'Status Code: ${debugInfo['urlInfo']['statusCode']}'),
                                          if (debugInfo['urlInfo']['error'] !=
                                              null)
                                            Text(
                                                'Error: ${debugInfo['urlInfo']['error']}'),
                                          const SizedBox(height: 8),
                                        ],
                                        if (debugInfo['storageInfo'] !=
                                            null) ...[
                                          const Text('Storage Information:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              'Exists: ${debugInfo['storageInfo']['exists']}'),
                                          if (debugInfo['storageInfo']
                                              ['exists']) ...[
                                            Text(
                                                'Size: ${debugInfo['storageInfo']['size']} bytes'),
                                            Text(
                                                'Content Type: ${debugInfo['storageInfo']['contentType']}'),
                                            Text(
                                                'Created: ${debugInfo['storageInfo']['timeCreated']}'),
                                          ] else ...[
                                            Text(
                                                'Error: ${debugInfo['storageInfo']['error']}'),
                                          ],
                                          const SizedBox(height: 8),
                                        ],
                                        if (debugInfo['errors'] != null &&
                                            (debugInfo['errors'] as List)
                                                .isNotEmpty) ...[
                                          const Text('Errors:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red)),
                                          ...(debugInfo['errors'] as List).map(
                                              (error) => Text('• $error',
                                                  style: const TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        final success = await VideoUrlService
                                            .refreshVideoUrlInDatabase(
                                                widget.video.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(success
                                                  ? 'URL refreshed successfully'
                                                  : 'Failed to refresh URL'),
                                              backgroundColor: success
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          );
                                          if (success) {
                                            Navigator.of(context)
                                                .pushReplacement(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    VideoPlayerPage(
                                                        video: widget.video),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Refresh URL'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Debug error: $e')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy URL'),
                        onPressed: () async {
                          try {
                            await Clipboard.setData(
                                ClipboardData(text: widget.video.videoUrl));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Video URL copied to clipboard'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to copy URL: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
            else if (_isInitialized && _chewieController != null)
              Expanded(
                child: Center(
                  child: Chewie(controller: _chewieController!),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
          else
            Expanded(
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    final url = Uri.parse(widget.video.videoUrl);
                    if (await canLaunchUrl(url)) {
                      final launched = await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Could not open video URL')),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Could not open video URL')),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                // Tags removed: no tags to display
              ],
            ),
          ),
        ],
      ),
    );
  }
}
