// keep only one FirebaseAuth import
import 'package:codequest/widgets/certificate_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/student/presentation/pages/course_file_viewer_page.dart';

class StudentMyCoursesPage extends StatelessWidget {
  const StudentMyCoursesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in as a student.'));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('My Courses'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 4),
                  Text(
                    'Keep learning and track your progress!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color.from(
                          alpha: 1, red: 0.494, green: 0.494, blue: 0.494),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('enrollments')
                    .where('studentId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_rounded,
                                size: 80, color: Colors.green[200]),
                            const SizedBox(height: 24),
                            const Text(
                              'No active courses',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'You are not enrolled in any active courses yet.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.explore),
                              label: const Text('Browse Courses'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Filter out completed courses manually since some records might not have the 'completed' field
                  final allEnrollments = snapshot.data!.docs;
                  final activeEnrollments = allEnrollments.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Include if completed is false or if completed field doesn't exist
                    return data['completed'] != true;
                  }).toList();

                  if (activeEnrollments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_rounded,
                                size: 80, color: Colors.green[200]),
                            const SizedBox(height: 24),
                            const Text(
                              'No active courses',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'You are not enrolled in any active courses yet.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.explore),
                              label: const Text('Browse Courses'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final enrollments = activeEnrollments;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    itemCount: enrollments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final courseId = enrollments[index]['courseId'];
                      final enrollmentData =
                          enrollments[index].data() as Map<String, dynamic>;
                      final isCompleted = enrollmentData['completed'] == true;
                      // enrolled by definition of the query; remove unused local
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('courses')
                            .doc(courseId)
                            .get(),
                        builder: (context, courseSnapshot) {
                          if (!courseSnapshot.hasData ||
                              !courseSnapshot.data!.exists) {
                            return const SizedBox();
                          }
                          final courseData = courseSnapshot.data!.data()
                              as Map<String, dynamic>;
                          final course = CourseModel.fromJson(
                              courseData..['id'] = courseSnapshot.data!.id);

                          // --- Progress calculation ---
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('progress')
                                .doc('${user.uid}_$courseId')
                                .get(),
                            builder: (context, progressSnapshot) {
                              final progressData = progressSnapshot.hasData &&
                                      progressSnapshot.data!.exists
                                  ? progressSnapshot.data!.data()
                                      as Map<String, dynamic>?
                                  : null;
                              final completedChallenges =
                                  progressData != null &&
                                          progressData['completedChallenges']
                                              is List
                                      ? List<String>.from(
                                          progressData['completedChallenges'])
                                      : <String>[];
                              return FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('challenges')
                                    .where('courseId', isEqualTo: courseId)
                                    .get(),
                                builder: (context, challengesSnapshot) {
                                  final totalChallenges =
                                      challengesSnapshot.hasData
                                          ? challengesSnapshot.data!.docs.length
                                          : 0;
                                  final percent = totalChallenges > 0
                                      ? completedChallenges.length /
                                          totalChallenges
                                      : 0.0;
                                  // --- Enhanced Card ---
                                  return _StudentCourseCard(
                                    course: course,
                                    isCompleted: isCompleted,
                                    progressPercent: percent,
                                    onContinue: course.files.isNotEmpty
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CourseFileViewerPage(
                                                  fileUrl: course.files[0]
                                                      ['url'],
                                                  fileName: course.files[0]
                                                      ['name'],
                                                  files: course.files,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    onUnenroll: (!isCompleted)
                                        ? () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Unenroll from Course'),
                                                content: const Text(
                                                    'Are you sure you want to unenroll from this course?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, true),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                    child:
                                                        const Text('Unenroll'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              final user = FirebaseAuth
                                                  .instance.currentUser;
                                              if (user == null) return;
                                              final enrollmentQuery =
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('enrollments')
                                                      .where('studentId',
                                                          isEqualTo: user.uid)
                                                      .where('courseId',
                                                          isEqualTo: courseId)
                                                      .get();
                                              for (var doc
                                                  in enrollmentQuery.docs) {
                                                await doc.reference.delete();
                                              }
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'You have been unenrolled from this course.')),
                                              );
                                            }
                                          }
                                        : null,
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Enhanced Student Course Card ---
class _StudentCourseCard extends StatefulWidget {
  final CourseModel course;
  final bool isCompleted;
  final double progressPercent;
  final VoidCallback? onContinue;
  final VoidCallback? onUnenroll;
  const _StudentCourseCard({
    required this.course,
    required this.isCompleted,
    required this.progressPercent,
    this.onContinue,
    this.onUnenroll,
    Key? key,
  }) : super(key: key);

  @override
  State<_StudentCourseCard> createState() => _StudentCourseCardState();
}

class _StudentCourseCardState extends State<_StudentCourseCard> {
  bool _showFiles = false;
  void _openCertificateDialog() {
    // Fallback student name; adjust if you have a user profile handy
    final studentName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Student';
    showDialog(
      context: context,
      builder: (context) => CertificateDialog(
        studentName: studentName,
        courseName: widget.course.title,
        teacherName: widget.course.teacherName,
        courseAuthor: widget.course.teacherName,
        allowDigitalSignature: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 4),
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
                        maxLines: 3,
                        overflow: TextOverflow.visible,
                        softWrap: true,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (course.courseCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tag,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    course.courseCode,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          if (course.teacherName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    course.teacherName,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
            // Removed duplicate status/action row here to avoid showing two badges
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: widget.progressPercent.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: Colors.green,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(widget.progressPercent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions under progress for a cleaner layout
            Row(
              children: [
                if (widget.isCompleted)
                  TextButton.icon(
                    onPressed: _openCertificateDialog,
                    icon: const Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'View Certificate',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                      foregroundColor: Colors.orange,
                    ),
                  ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isCompleted
                        ? Colors.green[100]
                        : Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.isCompleted ? 'Completed' : 'In Progress',
                    style: TextStyle(
                      color: widget.isCompleted
                          ? Colors.green[800]
                          : Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (course.files.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showFiles = !_showFiles),
                    icon: Icon(
                        _showFiles ? Icons.expand_less : Icons.folder_open,
                        size: 14,
                        color: Colors.blue[700]),
                    label: Text(_showFiles ? 'Hide Files' : 'View Files',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        )),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      side: BorderSide(color: Colors.blue[300]!, width: 1),
                      backgroundColor: Colors.blue[50],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                const SizedBox(width: 8),
                if (widget.onUnenroll != null)
                  OutlinedButton.icon(
                    onPressed: widget.onUnenroll,
                    icon: Icon(Icons.exit_to_app,
                        color: Colors.red[700], size: 14),
                    label: Text('Unenroll',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        )),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red[300]!, width: 1),
                      backgroundColor: Colors.red[50],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
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
