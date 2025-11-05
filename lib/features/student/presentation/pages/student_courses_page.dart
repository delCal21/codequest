import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// keep single FirebaseAuth import
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/student/presentation/pages/course_file_viewer_page.dart';

class StudentCoursesPage extends StatefulWidget {
  const StudentCoursesPage({Key? key}) : super(key: key);

  @override
  State<StudentCoursesPage> createState() => _StudentCoursesPageState();
}

class _StudentCoursesPageState extends State<StudentCoursesPage> {
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Helper function to check enrollment status
  Future<Map<String, dynamic>> _checkEnrollmentStatus(
    String courseId,
    String userId,
  ) async {
    try {
      // Check if already enrolled
      final enrollmentQuery = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: userId)
          .where('courseId', isEqualTo: courseId)
          .get();

      final isEnrolled = enrollmentQuery.docs.isNotEmpty;
      final isCompleted =
          isEnrolled && enrollmentQuery.docs.first.data()['completed'] == true;

      return {
        'isEnrolled': isEnrolled,
        'isCompleted': isCompleted,
        'hasPendingRequest': false, // No longer using approval system
      };
    } catch (e) {
      print('Error checking enrollment status: $e');
      return {
        'isEnrolled': false,
        'isCompleted': false,
        'hasPendingRequest': false,
      };
    }
  }

  // Helper function to get course statistics
  Future<Map<String, dynamic>> _getCourseStats(String courseId) async {
    try {
      // Get number of lessons/challenges for this course
      final challengesQuery = await FirebaseFirestore.instance
          .collection('challenges')
          .where('courseId', isEqualTo: courseId)
          .get();

      final lessonCount = challengesQuery.docs.length;

      // Get number of enrolled students for this course
      final enrollmentsQuery = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('courseId', isEqualTo: courseId)
          .get();

      final enrolledCount = enrollmentsQuery.docs.length;

      return {'lessonCount': lessonCount, 'enrolledCount': enrolledCount};
    } catch (e) {
      print('Error getting course stats: $e');
      return {'lessonCount': 0, 'enrolledCount': 0};
    }
  }

  void _scrollToAllCourses() {
    // Scroll to the All Courses section
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in as a student.'));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('courses').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No courses available.'));
            }
            final docs = snapshot.data!.docs;
            final courses =
                docs.map((d) => d.data() as Map<String, dynamic>).toList();

            final filteredCourses = courses.where((c) {
              // Only show published courses (or courses without isPublished field, treated as published)
              final isPublished =
                  c['isPublished'] == null || c['isPublished'] == true;
              final isActive = c['active'] == null || c['active'] == true;
              final matchesSearch = _search.isEmpty ||
                  (c['title']?.toLowerCase().contains(_search.toLowerCase()) ??
                      false) ||
                  (c['courseCode']?.toLowerCase().contains(
                            _search.toLowerCase(),
                          ) ??
                      false);
              return isPublished && isActive && matchesSearch;
            }).toList();

            // For demo, popular = first 5 courses
            final popularCourses = List<Map<String, dynamic>>.from(
              filteredCourses.take(5),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              controller: _scrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          width: constraints.maxWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Welcome',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .get(),
                                      builder: (context, snap) {
                                        final name = snap.hasData
                                            ? (snap.data?.get('name') ??
                                                user.email ??
                                                '')
                                            : '';
                                        return Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width:
                                    44, // Provide a fixed width for the avatar section
                                child: FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .get(),
                                  builder: (context, snap) {
                                    String? image;
                                    if (snap.hasData && snap.data != null) {
                                      try {
                                        image = snap.data!.get('profileImage');
                                      } catch (e) {
                                        image =
                                            null; // or set to a default image URL if you have one
                                      }
                                    } else {
                                      image = null;
                                    }
                                    return CircleAvatar(
                                      radius: 22,
                                      backgroundImage:
                                          image != null && image != ''
                                              ? NetworkImage(image)
                                              : null,
                                      child: image == null || image == ''
                                          ? Text(
                                              (user.displayName != null &&
                                                      user.displayName!
                                                          .isNotEmpty)
                                                  ? user.displayName![0]
                                                      .toUpperCase()
                                                  : (user.email != null &&
                                                          user.email!.isNotEmpty
                                                      ? user.email![0]
                                                          .toUpperCase()
                                                      : '?'),
                                            )
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search any courses',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 18),
                    // Search Results Info
                    if (_search.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Found ${filteredCourses.length} course${filteredCourses.length == 1 ? '' : 's'} for "$_search"',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Popular Courses (only show if no search or search has results)
                    if (_search.isEmpty || filteredCourses.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _search.isEmpty
                                ? 'Popular Course'
                                : 'Search Results',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_search.isEmpty)
                            TextButton(
                              onPressed: _scrollToAllCourses,
                              child: const Text('See all'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
                        child: filteredCourses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No courses found for "$_search"',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Try different keywords',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _search.isEmpty
                                    ? popularCourses.length
                                    : filteredCourses.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, i) {
                                  final c = _search.isEmpty
                                      ? popularCourses[i]
                                      : filteredCourses[i];
                                  final courseId = docs[courses.indexOf(c)].id;
                                  return FutureBuilder<Map<String, dynamic>>(
                                    future: _checkEnrollmentStatus(
                                      courseId,
                                      user.uid,
                                    ),
                                    builder: (context, statusSnapshot) {
                                      final status = statusSnapshot.data ??
                                          {
                                            'isEnrolled': false,
                                            'isCompleted': false,
                                            'hasPendingRequest': false,
                                          };

                                      String buttonText = 'Enroll now';
                                      bool isButtonEnabled = true;
                                      Color buttonColor = const Color(
                                        0xFF2ECC71,
                                      );

                                      if (status['isCompleted']) {
                                        buttonText = 'Completed';
                                        isButtonEnabled = false;
                                        buttonColor = Colors.grey;
                                      } else if (status['isEnrolled']) {
                                        buttonText = 'Enrolled';
                                        isButtonEnabled = false;
                                        buttonColor = const Color.fromARGB(
                                            255, 33, 243, 61);
                                      } else if (status['hasPendingRequest']) {
                                        buttonText = 'Pending';
                                        isButtonEnabled = false;
                                        buttonColor = Colors.orange;
                                      }

                                      return FutureBuilder<
                                          Map<String, dynamic>>(
                                        future: _getCourseStats(courseId),
                                        builder: (context, statsSnapshot) {
                                          final stats = statsSnapshot.data ??
                                              {
                                                'lessonCount': 0,
                                                'enrolledCount': 0,
                                              };

                                          return Container(
                                            width: 220,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey.withAlpha(
                                                    (0.08 * 255).toInt(),
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c['title'] ?? '',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    c['description'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.star,
                                                        color: Colors.amber,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text('5.0'),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${stats['lessonCount']} Lessons',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.people,
                                                        color: Color.fromARGB(
                                                            255, 33, 243, 61),
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${stats['enrolledCount']} Enrolled',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      onPressed: isButtonEnabled
                                                          ? () async {
                                                              try {
                                                                // Check if already enrolled
                                                                final enrollmentQuery =
                                                                    await FirebaseFirestore
                                                                        .instance
                                                                        .collection(
                                                                          'enrollments',
                                                                        )
                                                                        .where(
                                                                          'studentId',
                                                                          isEqualTo:
                                                                              user.uid,
                                                                        )
                                                                        .where(
                                                                          'courseId',
                                                                          isEqualTo:
                                                                              courseId,
                                                                        )
                                                                        .get();

                                                                if (enrollmentQuery
                                                                    .docs
                                                                    .isNotEmpty) {
                                                                  ScaffoldMessenger
                                                                      .of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    const SnackBar(
                                                                      content:
                                                                          Text(
                                                                        'You are already enrolled in this course',
                                                                      ),
                                                                    ),
                                                                  );
                                                                  return;
                                                                }

                                                                // Create enrollment directly
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                  'enrollments',
                                                                )
                                                                    .add({
                                                                  'studentId':
                                                                      user.uid,
                                                                  'courseId':
                                                                      courseId,
                                                                  'enrolledAt':
                                                                      FieldValue
                                                                          .serverTimestamp(),
                                                                  'progress': 0,
                                                                  'status':
                                                                      'active',
                                                                  'completed':
                                                                      false,
                                                                });

                                                                // Update enrollment count
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'courses',
                                                                    )
                                                                    .doc(
                                                                      courseId,
                                                                    )
                                                                    .update({
                                                                  'enrollmentCount':
                                                                      FieldValue
                                                                          .increment(
                                                                    1,
                                                                  ),
                                                                });

                                                                print(
                                                                  'Enrollment created: studentId=${user.uid}, courseId=${courseId}',
                                                                );
                                                                ScaffoldMessenger
                                                                    .of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content:
                                                                        Text(
                                                                      'Successfully enrolled in course!',
                                                                    ),
                                                                  ),
                                                                );
                                                              } catch (e) {
                                                                print(
                                                                  'Error creating enrollment: ${e.toString()}',
                                                                );
                                                                ScaffoldMessenger
                                                                    .of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  SnackBar(
                                                                    content:
                                                                        Text(
                                                                      'Error: ${e.toString()}',
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            }
                                                          : null,
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            buttonColor,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            8,
                                                          ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 10,
                                                        ),
                                                      ),
                                                      child: Text(buttonText),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // All Courses (only show when no search or search has results)
                    if (_search.isEmpty || filteredCourses.isNotEmpty) ...[
                      const Text(
                        'All Courses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredCourses.length,
                        itemBuilder: (context, i) {
                          final c = filteredCourses[i];
                          final courseId = docs[courses.indexOf(c)].id;
                          return FutureBuilder<Map<String, dynamic>>(
                            future: _checkEnrollmentStatus(courseId, user.uid),
                            builder: (context, statusSnapshot) {
                              final status = statusSnapshot.data ??
                                  {
                                    'isEnrolled': false,
                                    'isCompleted': false,
                                    'hasPendingRequest': false,
                                  };
                              return _AllCoursesCard(
                                course: CourseModel.fromJson({
                                  ...c,
                                  'id': courseId,
                                }),
                                isEnrolled: status['isEnrolled'] ?? false,
                                isCompleted: status['isCompleted'] ?? false,
                                onEnroll: (status['isEnrolled'] == true ||
                                        status['isCompleted'] == true)
                                    ? null
                                    : () async {
                                        final enrollmentQuery =
                                            await FirebaseFirestore.instance
                                                .collection('enrollments')
                                                .where('studentId',
                                                    isEqualTo: user.uid)
                                                .where('courseId',
                                                    isEqualTo: courseId)
                                                .get();
                                        if (enrollmentQuery.docs.isNotEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'You are already enrolled in this course')),
                                          );
                                          return;
                                        }
                                        await FirebaseFirestore.instance
                                            .collection('enrollments')
                                            .add({
                                          'studentId': user.uid,
                                          'courseId': courseId,
                                          'enrolledAt':
                                              FieldValue.serverTimestamp(),
                                          'progress': 0,
                                          'status': 'active',
                                          'completed': false,
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Successfully enrolled in course!')),
                                        );
                                        setState(() {});
                                      },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// --- Enhanced All Courses Card ---
class _AllCoursesCard extends StatefulWidget {
  final CourseModel course;
  final bool isEnrolled;
  final bool isCompleted;
  final VoidCallback? onEnroll;
  const _AllCoursesCard({
    required this.course,
    required this.isEnrolled,
    required this.isCompleted,
    this.onEnroll,
    Key? key,
  }) : super(key: key);

  @override
  State<_AllCoursesCard> createState() => _AllCoursesCardState();
}

class _AllCoursesCardState extends State<_AllCoursesCard> {
  bool _showFiles = false;
  double _progress = 0.0;
  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final progressDoc = await FirebaseFirestore.instance
        .collection('progress')
        .doc('${user.uid}_${widget.course.id}')
        .get();
    if (progressDoc.exists) {
      final data = progressDoc.data() as Map<String, dynamic>;
      final completedChallenges = data['completedChallenges'] is List
          ? (data['completedChallenges'] as List).length
          : 0;
      final totalChallengesSnap = await FirebaseFirestore.instance
          .collection('challenges')
          .where('courseId', isEqualTo: widget.course.id)
          .get();
      final totalChallenges = totalChallengesSnap.docs.length;
      if (!mounted) return;
      setState(() {
        _progress =
            totalChallenges > 0 ? completedChallenges / totalChallenges : 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green[50],
                  child: Icon(
                    Icons.menu_book,
                    color: Colors.green[700],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.courseCode.isNotEmpty ? course.courseCode : '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      if (course.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            course.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.isEnrolled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: Colors.green,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Progress: ${(_progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!widget.isEnrolled &&
                    !widget.isCompleted &&
                    widget.onEnroll != null)
                  ElevatedButton.icon(
                    onPressed: widget.onEnroll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Enroll'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                  ),
                if (widget.isEnrolled && course.files.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _showFiles = !_showFiles),
                    icon: Icon(
                        _showFiles ? Icons.expand_less : Icons.attach_file),
                    label: Text(_showFiles ? 'Hide Files' : 'View Files'),
                  ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isCompleted
                        ? Colors.green[100]
                        : widget.isEnrolled
                            ? Colors.blue[100]
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.isCompleted
                        ? 'Completed'
                        : widget.isEnrolled
                            ? 'Enrolled'
                            : 'Available',
                    style: TextStyle(
                      color: widget.isCompleted
                          ? Colors.green[800]
                          : widget.isEnrolled
                              ? Colors.green[800]
                              : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (_showFiles && course.files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: course.files
                      .map<Widget>((file) => Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.insert_drive_file,
                                    color: Colors.green),
                                title: Text(file['name'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CourseFileViewerPage(
                                          fileUrl: file['url'],
                                          fileName: file['name'],
                                          files: course.files,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
