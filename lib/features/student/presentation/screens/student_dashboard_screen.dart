import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/student/presentation/pages/student_challenges_page.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  Future<void> _enrollInCourse(BuildContext context, String courseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to enroll in courses')),
        );
        return;
      }

      // Check if already enrolled
      final enrollmentQuery = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: user.uid)
          .where('courseId', isEqualTo: courseId)
          .get();

      if (enrollmentQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You are already enrolled in this course')),
        );
        return;
      }

      // Create enrollment
      await FirebaseFirestore.instance.collection('enrollments').add({
        'studentId': user.uid,
        'courseId': courseId,
        'enrolledAt': FieldValue.serverTimestamp(),
        'progress': 0,
        'status': 'active',
        'completed': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully enrolled in course')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enrolling in course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Student Dashboard'),
        ),
        body: const Center(
          child: Text('Please log in to view your dashboard'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enrolled Courses Section
            const Text(
              'My Courses',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildEnrolledCoursesSection(user.uid),

            const SizedBox(height: 32),

            // Available Courses Section
            const Text(
              'Available Courses',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAvailableCoursesSection(),

            const SizedBox(height: 32),

            // Challenges Section
            const Text(
              'Coding Challenges',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildChallengesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledCoursesSection(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: userId)
          .orderBy('enrolledAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error.toString()}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('You are not enrolled in any courses yet'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final enrollment = snapshot.data!.docs[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('courses')
                  .doc(enrollment['courseId'])
                  .get(),
              builder: (context, courseSnapshot) {
                if (courseSnapshot.hasError) {
                  return Card(
                    child: ListTile(
                      title: const Text('Error loading course'),
                      subtitle: Text(courseSnapshot.error.toString()),
                    ),
                  );
                }

                if (!courseSnapshot.hasData) {
                  return const Card(
                    child: ListTile(
                      title: Text('Loading course...'),
                    ),
                  );
                }

                final courseData =
                    courseSnapshot.data!.data() as Map<String, dynamic>?;
                if (courseData == null) {
                  return const Card(
                    child: ListTile(
                      title: Text('Course not found'),
                    ),
                  );
                }

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.school),
                    title: Text(courseData['title'] ?? 'Untitled Course'),
                    subtitle: Text(
                        'Enrolled on: ${_formatDate(enrollment['enrolledAt'])}'),
                    trailing: Text('${enrollment['progress']}% Complete'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableCoursesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('isPublished', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error.toString()}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No courses available at the moment'),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
            childAspectRatio:
                MediaQuery.of(context).size.width > 600 ? 1.5 : 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final course = snapshot.data!.docs[index];
            final courseData = course.data() as Map<String, dynamic>?;

            if (courseData == null) {
              return const Card(
                child: Center(
                  child: Text('Invalid course data'),
                ),
              );
            }

            return Card(
              child: InkWell(
                onTap: () {
                  _showCourseDetails(context, course.id, courseData);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseData['title'] ?? 'Untitled Course',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        courseData['description'] ?? 'No description available',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'By: ${courseData['instructorName'] ?? 'Unknown'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            '${courseData['duration'] ?? 'N/A'} hours',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCourseDetails(
      BuildContext context, String courseId, Map<String, dynamic> courseData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseData['title'] ?? 'Untitled Course',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  courseData['description'] ?? 'No description available',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'Instructor: ${courseData['instructorName'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Duration: ${courseData['duration'] ?? 'N/A'} hours',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _enrollInCourse(context, courseId);
                      Navigator.pop(context);
                    },
                    child: const Text('Enroll in Course'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildChallengesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .where('isPublished', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error.toString()}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No challenges available at the moment'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${snapshot.data!.docs.length} challenges available',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentChallengesPage(),
                      ),
                    );
                  },
                  child: const Text('View All Challenges'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
