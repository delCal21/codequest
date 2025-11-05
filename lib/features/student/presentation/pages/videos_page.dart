import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/features/videos/data/video_repository.dart';
import 'package:codequest/features/videos/presentation/pages/video_player_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:codequest/services/enhanced_video_player_service.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({Key? key}) : super(key: key);

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  String _search = '';
  String? _selectedCourseId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<String>> _getEnrolledCourseIds(String userId) async {
    final enrollments = await FirebaseFirestore.instance
        .collection('enrollments')
        .where('studentId', isEqualTo: userId)
        .get();
    return enrollments.docs.map((doc) => doc['courseId'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    final videoRepository = VideoRepository(FirebaseFirestore.instance);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in as a student.')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Video Tutorials'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List<String>>(
        future: _getEnrolledCourseIds(user.uid),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoader();
          }
          if (!courseSnapshot.hasData || courseSnapshot.data!.isEmpty) {
            return const Center(
                child: Text('You are not enrolled in any courses.'));
          }
          final enrolledCourseIds = courseSnapshot.data!;
          return FutureBuilder<List<VideoModel>>(
            future: videoRepository.getPublishedVideos(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerLoader();
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error.toString()}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No videos available.'));
              }
              final videos = snapshot.data!
                  .where((video) => enrolledCourseIds.contains(video.courseId))
                  .toList();
              if (videos.isEmpty) {
                return const Center(
                    child:
                        Text('No videos available for your enrolled courses.'));
              }
              // Get course names for filter and grouping
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('courses')
                    .where(FieldPath.documentId, whereIn: enrolledCourseIds)
                    .get(),
                builder: (context, courseSnap) {
                  if (courseSnap.connectionState == ConnectionState.waiting) {
                    return _buildShimmerLoader();
                  }
                  final courseDocs = courseSnap.data?.docs ?? [];
                  final courseNames = {
                    for (var doc in courseDocs) doc.id: doc['title'] ?? doc.id
                  };
                  // Group videos by course
                  final Map<String, List<VideoModel>> courseVideoMap = {};
                  for (var v in videos) {
                    if (v.courseId == null) continue;
                    courseVideoMap.putIfAbsent(v.courseId!, () => []).add(v);
                  }
                  // Filter by search and course
                  List<String> filteredCourseIds = enrolledCourseIds;
                  if (_selectedCourseId != null && _selectedCourseId != '') {
                    filteredCourseIds = [_selectedCourseId!];
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search videos...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0, horizontal: 12),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _search = value.trim();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.filter_list, size: 28),
                              tooltip: 'Filter',
                              onPressed: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setModalState) {
                                        return Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('Filter by',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18)),
                                              const SizedBox(height: 16),
                                              DropdownButtonFormField<String>(
                                                value: _selectedCourseId,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Course',
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: [
                                                  const DropdownMenuItem<
                                                      String>(
                                                    value: null,
                                                    child: Text('All Courses'),
                                                  ),
                                                  ...enrolledCourseIds.map(
                                                      (id) => DropdownMenuItem<
                                                              String>(
                                                            value: id,
                                                            child: Text(
                                                                courseNames[
                                                                        id] ??
                                                                    id),
                                                          )),
                                                ],
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    _selectedCourseId = value;
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 24),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {});
                                                        Navigator.pop(context);
                                                      },
                                                      child:
                                                          const Text('Apply'),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () {
                                                        setModalState(() {
                                                          _selectedCourseId =
                                                              null;
                                                        });
                                                        setState(() {});
                                                        Navigator.pop(context);
                                                      },
                                                      child:
                                                          const Text('Clear'),
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          children: [
                            for (final courseId in filteredCourseIds)
                              if (courseVideoMap[courseId] != null)
                                _buildCourseSection(
                                  context,
                                  courseId,
                                  courseNames[courseId] ?? 'Course',
                                  courseVideoMap[courseId]!,
                                ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCourseSection(BuildContext context, String courseId,
      String courseName, List<VideoModel> videos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            courseName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color.fromARGB(255, 0, 0, 0),
            ),
          ),
        ),
        ...videos
            .where((v) =>
                _search.isEmpty ||
                v.title.toLowerCase().contains(_search.toLowerCase()) ||
                v.description.toLowerCase().contains(_search.toLowerCase()))
            .map((video) => _buildVideoCard(context, video))
            .toList(),
      ],
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoModel video) {
    String date = '';
    try {
      date = DateFormat('MMM d, yyyy').format(video.createdAt);
    } catch (_) {}
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(video: video),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: video.thumbnailUrl != null &&
                          video.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 120,
                              color: Colors.grey[200],
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.videocam,
                                size: 40, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 120,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.videocam,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.30),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Icon(Icons.play_arrow,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (video.duration > 0)
                        Row(
                          children: [
                            const Icon(Icons.timer,
                                size: 15, color: Colors.blueGrey),
                            const SizedBox(width: 3),
                            Text(_formatDuration(video.duration),
                                style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 10),
                          ],
                        ),
                      const Icon(Icons.calendar_today,
                          size: 13, color: Colors.blueGrey),
                      const SizedBox(width: 3),
                      Text(date, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VideoPlayerPage(video: video),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label:
                            const Text('Play', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(video.videoUrl);
                          if (await canLaunchUrl(uri)) {
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Could not open browser to download video.')),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Could not open browser to download video.')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildShimmerLoader() {
    // Simple shimmer/skeleton loader for loading state
    return ListView.builder(
      itemCount: 3,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(vertical: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          height: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 18,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 14,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 80,
                      height: 14,
                      color: Colors.grey[200],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
