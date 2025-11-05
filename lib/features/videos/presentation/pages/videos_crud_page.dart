import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/features/videos/presentation/widgets/video_form.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';

class VideosCrudPage extends StatefulWidget {
  const VideosCrudPage({super.key});

  @override
  State<VideosCrudPage> createState() => _VideosCrudPageState();
}

class _VideosCrudPageState extends State<VideosCrudPage> {
  Map<String, CourseModel> _courses = {};
  String? _selectedCourseFilter;
  bool _isLoadingCourses = true;
  User? _currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // Removed unused permissions map and collaborator repository to satisfy lints

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    if (_currentUser == null) return;
    if (!mounted) return;
    setState(() {
      _isLoadingCourses = true;
    });
    try {
      // Fetch all courses for admin
      final coursesSnapshot =
          await FirebaseFirestore.instance.collection('courses').get();
      final courses = <String, CourseModel>{};
      for (var doc in coursesSnapshot.docs) {
        final course = CourseModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
        courses[doc.id] = course;
      }
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _isLoadingCourses = false;
      });
    } catch (e) {
      print('Error loading courses: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingCourses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            color: Colors.green[500],
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 24),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    fontFamily: 'NotoSans',
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                            color: const Color(0xFF58B74A), width: 1.2),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search videos...',
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color: const Color.fromARGB(255, 0, 0, 0)),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.black, size: 18),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Color(0xFF58B74A), width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Color(0xFF58B74A), width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Color(0xFF58B74A), width: 2),
                            ),
                          ),
                          onSubmitted: (value) {
                            if (!mounted) return;
                            setState(() {
                              _searchQuery = value.trim().toLowerCase();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Removed DropdownButtonFormField for course filter and its SizedBox spacing
                    // Add Video button (replaces IconButton)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (context) => const AlertDialog(
                            contentPadding: EdgeInsets.zero,
                            content: SizedBox(
                              width: 500,
                              child: VideoForm(),
                            ),
                          ),
                        );
                        if (!mounted) return;
                        setState(() {});
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        elevation: 2,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingCourses
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _courses.isEmpty
                        ? const Stream.empty()
                        : FirebaseFirestore.instance
                            .collection('videos')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                'Error:  [1m${snapshot.error.toString()} [0m'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final videos = snapshot.data!.docs.map((doc) {
                        return VideoModel.fromJson({
                          'id': doc.id,
                          ...doc.data() as Map<String, dynamic>,
                        });
                      }).toList();

                      if (_selectedCourseFilter != null) {
                        videos.retainWhere(
                            (v) => v.courseId == _selectedCourseFilter);
                      }

                      final filteredVideos = videos.where((video) {
                        final courseName =
                            _courses[video.courseId]?.title ?? '';
                        final courseCode =
                            _courses[video.courseId]?.courseCode ?? '';
                        final combined = [
                          video.title,
                          video.description,
                          video.teacherId,
                          video.teacherName,
                          video.videoUrl,
                          video.fileName,
                          video.mediaType,
                          video.createdAt.toString(),
                          video.updatedAt.toString(),
                          video.isPublished ? 'published' : 'unpublished',
                          video.duration.toString(),
                          video.thumbnailUrl ?? '',
                          ...(video.tags ?? []),
                          video.category ?? '',
                          video.viewCount?.toString() ?? '',
                          video.downloadCount?.toString() ?? '',
                          ...(video.metadata?.values
                                  .map((e) => e.toString())
                                  .toList() ??
                              []),
                          video.courseId ?? '',
                          courseName,
                          courseCode,
                        ].join(' ').toLowerCase();
                        final matchesSearch = _searchQuery.isEmpty ||
                            combined.contains(_searchQuery);
                        return matchesSearch;
                      }).toList();

                      // Pagination logic
                      int _currentPage = 0;
                      const int _pageSize = 10;
                      int start = _currentPage * _pageSize;
                      int end = (start + _pageSize) > filteredVideos.length
                          ? filteredVideos.length
                          : (start + _pageSize);
                      List paginated = filteredVideos.sublist(start, end);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: DataTable(
                                      headingRowColor:
                                          MaterialStateProperty.all(
                                              const Color(0xFFEFF7ED)),
                                      dataRowColor: MaterialStateProperty
                                          .resolveWith<Color?>(
                                              (Set<MaterialState> states) {
                                        if (states
                                            .contains(MaterialState.selected)) {
                                          return Colors.green[100];
                                        }
                                        return null;
                                      }),
                                      headingTextStyle: const TextStyle(
                                        color: Color.fromARGB(255, 0, 0, 0),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'NotoSans',
                                      ),
                                      columns: const [
                                        DataColumn(
                                            label: Text('Title',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15))),
                                        DataColumn(
                                            label: Text('Description',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15))),
                                        DataColumn(
                                            label: Text('Course',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15))),
                                        DataColumn(
                                            label: Text('Created',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15))),
                                        DataColumn(
                                            label: Text('Status',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15))),
                                        // Removed Actions column
                                      ],
                                      rows: paginated
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final index = entry.key;
                                        final video = entry.value;
                                        final courseName =
                                            _courses[video.courseId]?.title ??
                                                'Unknown';
                                        return DataRow(
                                          color: MaterialStateProperty
                                              .resolveWith<Color?>((states) {
                                            return index % 2 == 0
                                                ? Colors.white
                                                : const Color.fromARGB(
                                                    255, 255, 255, 255);
                                          }),
                                          cells: [
                                            DataCell(SizedBox(
                                              width: 120,
                                              child: Text(video.title),
                                            )),
                                            DataCell(SizedBox(
                                              width: 180,
                                              child: Text(
                                                video.description ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )),
                                            DataCell(SizedBox(
                                              width: 120,
                                              child: Text(courseName),
                                            )),
                                            DataCell(Text(
                                                video.createdAt != null
                                                    ? video.createdAt
                                                        .toString()
                                                        .substring(0, 10)
                                                    : 'N/A')),
                                            DataCell(Row(
                                              children: [
                                                Text(
                                                  video.isPublished
                                                      ? 'Published'
                                                      : 'Unpublished',
                                                  style: TextStyle(
                                                    color: video.isPublished
                                                        ? Colors.green[700]
                                                        : Colors.grey[600],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize:
                                                        10, // Even smaller label
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width:
                                                        6), // Further reduced spacing
                                                Transform.scale(
                                                  scale:
                                                      0.6, // Even smaller switch
                                                  child: Switch(
                                                    value: video.isPublished,
                                                    activeColor: Colors.green,
                                                    inactiveThumbColor:
                                                        Colors.grey[400],
                                                    inactiveTrackColor:
                                                        Colors.grey[300],
                                                    onChanged:
                                                        (bool value) async {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('videos')
                                                          .doc(video.id)
                                                          .update({
                                                        'isPublished': value
                                                      });
                                                      if (!mounted) return;
                                                      setState(() {});
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            value
                                                                ? 'Set to Published'
                                                                : 'Set to Unpublished',
                                                          ),
                                                          backgroundColor: value
                                                              ? Colors
                                                                  .green[600]
                                                              : Colors
                                                                  .grey[600],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            )),
                                            // Removed actions cell
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 16, right: 20, bottom: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _currentPage > 0
                                            ? () {
                                                setState(() {
                                                  _currentPage--;
                                                });
                                              }
                                            : null,
                                        child: const Text('Previous'),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Page ${_currentPage + 1} of ${((filteredVideos.length / _pageSize).ceil()).clamp(1, 999)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton(
                                        onPressed: end < filteredVideos.length
                                            ? () {
                                                setState(() {
                                                  _currentPage++;
                                                });
                                              }
                                            : null,
                                        child: const Text('Next'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
