import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/features/videos/presentation/widgets/video_form.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';
import 'package:codequest/features/videos/presentation/bloc/video_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TeacherVideosPage extends StatefulWidget {
  const TeacherVideosPage({super.key});

  @override
  State<TeacherVideosPage> createState() => _TeacherVideosPageState();
}

class _TeacherVideosPageState extends State<TeacherVideosPage> {
  Map<String, CourseModel> _courses = {};
  Map<String, Map<String, bool>> _coursePermissions = {};
  String? _selectedCourseFilter;
  bool _isLoadingCourses = true;
  User? _currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final CollaboratorRepository _collaboratorRepository =
      CollaboratorRepository(FirebaseFirestore.instance);

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
    setState(() {
      _isLoadingCourses = true;
    });
    try {
      // Fetch owned courses
      final ownedCoursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: _currentUser!.uid)
          .get();
      final courses = <String, CourseModel>{};
      final coursePermissions = <String, Map<String, bool>>{};
      for (var doc in ownedCoursesSnapshot.docs) {
        final course = CourseModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
        courses[doc.id] = course;
        coursePermissions[doc.id] = {
          'manage_content': true
        }; // Owner always has permission
      }
      // Fetch collaborated courses
      final collaboratorCourseIds = await _collaboratorRepository
          .getCollaboratorCourses(_currentUser!.uid);
      if (collaboratorCourseIds.isNotEmpty) {
        final collabCoursesSnapshot = await FirebaseFirestore.instance
            .collection('courses')
            .where(FieldPath.documentId, whereIn: collaboratorCourseIds)
            .get();
        for (var doc in collabCoursesSnapshot.docs) {
          final course = CourseModel.fromJson({
            'id': doc.id,
            ...doc.data(),
          });
          courses[doc.id] = course;
          // Get collaborator permissions
          final collaboratorDetails = await _collaboratorRepository
              .getCollaboratorDetails(doc.id, _currentUser!.uid);
          print(
              'DEBUG: Collaborated Course: ${doc.id}, Title: ${course.title}, Permissions: ${collaboratorDetails?.permissions}');
          coursePermissions[doc.id] = collaboratorDetails?.permissions ?? {};
        }
      }
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _coursePermissions = coursePermissions;
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

  Map<String, List<VideoModel>> _getOrganizedVideos(List<VideoModel> videos) {
    final organized = <String, List<VideoModel>>{};

    for (var video in videos) {
      final courseId = video.courseId;
      if (courseId != null && _courses.containsKey(courseId)) {
        organized.putIfAbsent(courseId, () => []);
        organized[courseId]!.add(video);
      }
    }

    return organized;
  }

  Future<void> _deleteVideo(VideoModel video) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${video.title}"? This action cannot be undone and will also delete the video file from storage.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // Only delete if user confirmed
    if (confirmed == true) {
      try {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(video.id)
            .delete();

        // Delete from Firebase Storage
        await FirebaseStorage.instance.refFromURL(video.videoUrl).delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video "${video.title}" deleted successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting video: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getCourseColor(String courseId) {
    final colors = [
      Colors.blue,
      Colors.blue[700],
      Colors.blue[600],
      Colors.blue[500],
      Colors.blue[400],
      Colors.blue[300],
      Colors.indigo,
      Colors.indigo[600],
      Colors.indigo[500],
      Colors.indigo[400],
    ];

    if (courseId == 'unassigned') return Colors.grey;

    final index = courseId.hashCode % colors.length;
    return colors[index] ?? Colors.blue;
  }

  Widget _buildCourseSection(String courseId, List<VideoModel> videos) {
    final course = _courses[courseId];
    final courseName = course?.title ?? 'Unknown Course';
    final courseColor = _getCourseColor(courseId);
    final permissions = _coursePermissions[courseId] ?? {};
    final canUpload = permissions['manage_content'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: courseColor.withOpacity(0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: courseColor.withOpacity(0.2),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Icon(
                    Icons.school,
                    color: courseColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: courseColor,
                          fontFamily: 'NotoSans',
                        ),
                      ),
                      Text(
                        '${videos.length} video${videos.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: courseColor.withOpacity(0.8),
                          fontFamily: 'NotoSans',
                        ),
                      ),
                    ],
                  ),
                ),
                if (canUpload)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: courseColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          contentPadding: EdgeInsets.zero,
                          content: SizedBox(
                            width: 500,
                            child: VideoForm(preSelectedCourseId: courseId),
                          ),
                        ),
                      );
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.video_file,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video.title,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'NotoSans',
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'By: ${video.teacherName}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontFamily: 'NotoSans',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  contentPadding: EdgeInsets.zero,
                                  content: SizedBox(
                                    width: 500,
                                    child: VideoForm(video: video),
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteVideo(video),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        title: const Text(
          '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSans',
          ),
        ),
        actions: [
          // Search Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Container(
                width: isWide ? 180 : 120,
                constraints: const BoxConstraints(maxWidth: 200),
                margin: const EdgeInsets.only(right: 16),
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
                  border:
                      Border.all(color: const Color(0xFF58B74A), width: 1.2),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search videos...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.black, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.green[300], size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              tooltip: 'Clear search',
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF58B74A), width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF58B74A), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF58B74A), width: 2),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              );
            },
          ),
          // Add Video Button - positioned like in challenges page
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 15, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
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
          ),
        ],
      ),
      body: _isLoadingCourses
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _courses.isEmpty
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('videos')
                      .where('courseId', whereIn: _courses.keys.toList())
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error.toString()}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final videos = snapshot.data?.docs.map((doc) {
                      return VideoModel.fromJson({
                        'id': doc.id,
                        ...doc.data() as Map<String, dynamic>,
                      });
                    }).toList() ??
                    [];

                final filteredVideos = videos.where((video) {
                  final title = video.title.toLowerCase();
                  final description = video.description.toLowerCase();
                  final matchesSearch = _searchQuery.isEmpty ||
                      title.contains(_searchQuery) ||
                      description.contains(_searchQuery);
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

                // Handle empty state
                if (filteredVideos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No videos found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }

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
                                    MaterialStateProperty.resolveWith<Color?>(
                                        (states) => Colors.green[50]),
                                dataRowColor:
                                    MaterialStateProperty.resolveWith<Color?>(
                                        (states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.green[100];
                                  }
                                  return Colors.white;
                                }),
                                headingTextStyle: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'NotoSans',
                                ),
                                columns: const [
                                  DataColumn(label: Text('Title')),
                                  DataColumn(label: Text('Description')),
                                  DataColumn(label: Text('Course')),
                                  DataColumn(label: Text('Uploaded')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: paginated.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final video = entry.value;
                                  final courseName =
                                      _courses[video.courseId]?.title ??
                                          'Unknown';
                                  return DataRow(
                                    color: MaterialStateProperty.resolveWith<
                                        Color?>((states) {
                                      return index % 2 == 0
                                          ? Colors.white
                                          : const Color.fromARGB(
                                              255, 255, 255, 255);
                                    }),
                                    cells: [
                                      DataCell(SizedBox(
                                        width: 220,
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
                                      DataCell(Text(video.createdAt != null
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
                                              fontSize: 12, // Smaller label
                                            ),
                                          ),
                                          const SizedBox(
                                              width: 8), // Reduced spacing
                                          Transform.scale(
                                            scale: 0.8, // Smaller switch
                                            child: Switch(
                                              value: video.isPublished,
                                              activeColor: Colors.green,
                                              inactiveThumbColor:
                                                  Colors.grey[400],
                                              inactiveTrackColor:
                                                  Colors.grey[300],
                                              onChanged: (bool value) async {
                                                bool wasMounted = mounted;
                                                await FirebaseFirestore.instance
                                                    .collection('videos')
                                                    .doc(video.id)
                                                    .update(
                                                        {'isPublished': value});
                                                if (!wasMounted || !mounted)
                                                  return;
                                                setState(() {});
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      value
                                                          ? 'Set to Published'
                                                          : 'Set to Unpublished',
                                                    ),
                                                    backgroundColor: value
                                                        ? Colors.green[600]
                                                        : Colors.grey[600],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      )),
                                      DataCell(Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            tooltip: 'Edit',
                                            onPressed: () async {
                                              await showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  content: SizedBox(
                                                    width: 500,
                                                    child:
                                                        VideoForm(video: video),
                                                  ),
                                                ),
                                              );
                                              setState(() {});
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            tooltip: 'Delete',
                                            onPressed: () =>
                                                _deleteVideo(video),
                                          ),
                                        ],
                                      )),
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
    );
  }
}
