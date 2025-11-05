import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/config/routes.dart';
import 'package:codequest/features/teacher/presentation/widgets/stats_card.dart';
import 'package:codequest/features/teacher/presentation/widgets/teacher_pie_chart.dart';
import 'package:codequest/features/teacher/presentation/pages/student_progress_page.dart';
import 'package:codequest/features/teacher/presentation/widgets/notification_helper_stub.dart'
    if (dart.library.html) 'package:codequest/features/teacher/presentation/widgets/web_notification_helper.dart'
    if (dart.library.io) 'package:codequest/features/teacher/presentation/widgets/mobile_notification_helper.dart';
import 'package:codequest/features/teacher/presentation/widgets/teacher_enrollment_subject_chart.dart';
import 'package:codequest/features/teacher/presentation/widgets/teacher_student_report.dart';

class TeacherHomePage extends StatelessWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    print('DEBUG: TeacherHomePage build called for user: ${currentUser?.uid}');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Removed Modern Header Section (Welcome Banner)
                // const SizedBox(height: 32),

                // Statistics Grid
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('courses')
                      .where('teacherId', isEqualTo: currentUser?.uid)
                      .snapshots(),
                  builder: (context, courseSnapshot) {
                    final teacherCourses = courseSnapshot.data?.docs ?? [];
                    final teacherCourseIds =
                        teacherCourses.map((doc) => doc.id).toSet();
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('courses')
                          .where('collaboratorIds',
                              arrayContains: currentUser?.uid)
                          .snapshots(),
                      builder: (context, collaboratorSnapshot) {
                        final collaboratorCourses =
                            collaboratorSnapshot.data?.docs ?? [];
                        for (var doc in collaboratorCourses) {
                          teacherCourseIds.add(doc.id);
                        }
                        final courseCount = teacherCourseIds.length;

                        // Build map of courseId -> course title for labeling subjects
                        final Map<String, String> courseIdToTitle = {};
                        for (final d in teacherCourses) {
                          final data = d.data() as Map<String, dynamic>;
                          courseIdToTitle[d.id] =
                              (data['title'] ?? data['courseCode'] ?? d.id)
                                  .toString();
                        }
                        for (final d in collaboratorCourses) {
                          final data = d.data() as Map<String, dynamic>;
                          courseIdToTitle[d.id] =
                              (data['title'] ?? data['courseCode'] ?? d.id)
                                  .toString();
                        }

                        print(
                            'DEBUG: Found ${courseCount} courses for teacher');
                        print('DEBUG: Teacher course IDs: $teacherCourseIds');

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('enrollments')
                              .snapshots(),
                          builder: (context, enrollmentSnapshot) {
                            int enrolledStudentsCount = 0;
                            if (enrollmentSnapshot.hasData) {
                              final enrollments =
                                  enrollmentSnapshot.data?.docs ?? [];
                              enrolledStudentsCount =
                                  enrollments.where((enrollment) {
                                final enrollmentData =
                                    enrollment.data() as Map<String, dynamic>?;
                                if (enrollmentData == null) return false;
                                final courseId = enrollmentData['courseId'];
                                return courseId != null &&
                                    courseId is String &&
                                    teacherCourseIds.contains(courseId);
                              }).length;
                            }

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('challenges')
                                  .where('courseId',
                                      whereIn: teacherCourseIds.isNotEmpty
                                          ? teacherCourseIds.toList()
                                          : ['_'])
                                  .snapshots(),
                              builder: (context, challengeSnapshot) {
                                int challengeCount = 0;
                                if (challengeSnapshot.hasData) {
                                  challengeCount =
                                      challengeSnapshot.data!.docs.length;
                                }

                                return Column(
                                  children: [
                                    GridView.count(
                                      crossAxisCount: 4,
                                      childAspectRatio: 2.5,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 20,
                                      mainAxisSpacing: 20,
                                      children: [
                                        StatsCard(
                                          title: 'My Courses',
                                          value: courseCount.toString(),
                                          icon: Icons.menu_book_rounded,
                                          cardColor: Colors.green[200]!,
                                          textColor: Colors.grey[800]!,
                                          iconColor: Colors.grey[600]!,
                                          labelColor: Colors.grey[800]!,
                                          moreInfoColor: Colors.grey[800]!,
                                          moreInfoText: 'View all courses',
                                          onTap: () => Navigator.pushNamed(
                                              context,
                                              AppRouter.teacherDashboard),
                                        ),
                                        StatsCard(
                                          title: 'Enrolled Students',
                                          value:
                                              enrolledStudentsCount.toString(),
                                          icon: Icons.people_rounded,
                                          cardColor: Colors.blue[200]!,
                                          textColor: Colors.grey[800]!,
                                          iconColor: Colors.grey[600]!,
                                          labelColor: Colors.grey[800]!,
                                          moreInfoColor: Colors.grey[800]!,
                                          moreInfoText: 'View students',
                                          onTap: () => Navigator.pushNamed(
                                              context,
                                              AppRouter.teacherDashboard),
                                        ),
                                        StatsCard(
                                          title: 'Challenges',
                                          value: challengeCount.toString(),
                                          icon: Icons.code_rounded,
                                          cardColor: Colors.amber[200]!,
                                          textColor: Colors.grey[800]!,
                                          iconColor: Colors.grey[600]!,
                                          labelColor: Colors.grey[800]!,
                                          moreInfoColor: Colors.grey[800]!,
                                          moreInfoText: 'View challenges',
                                          onTap: () => Navigator.pushNamed(
                                              context,
                                              AppRouter.teacherDashboard),
                                        ),
                                        StatsCard(
                                          title: 'Student Progress',
                                          value:
                                              enrolledStudentsCount.toString(),
                                          icon: Icons.trending_up_rounded,
                                          cardColor: Colors.purple[200]!,
                                          textColor: Colors.grey[800]!,
                                          iconColor: Colors.grey[600]!,
                                          labelColor: Colors.grey[800]!,
                                          moreInfoColor: Colors.grey[800]!,
                                          moreInfoText: 'View activity',
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const StudentProgressPage(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    // Charts Section
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide =
                                            constraints.maxWidth > 400;
                                        final overview = TeacherPieChart(
                                            courses: courseCount,
                                            challenges: challengeCount,
                                            students: enrolledStudentsCount);
                                        final enrollBySubject =
                                            TeacherEnrollmentSubjectChart(
                                          teacherCourseIds: teacherCourseIds,
                                          courseIdToTitle: courseIdToTitle,
                                        );
                                        return isWide
                                            ? Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(child: overview),
                                                  const SizedBox(width: 15),
                                                  Expanded(
                                                      child: enrollBySubject),
                                                ],
                                              )
                                            : Column(
                                                children: [
                                                  overview,
                                                  const SizedBox(height: 24),
                                                  enrollBySubject,
                                                ],
                                              );
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    // Student Report with filters
                                    TeacherStudentReport(
                                      teacherCourseIds: teacherCourseIds,
                                      courseIdToTitle: courseIdToTitle,
                                      hideStatus: true,
                                      hideCategory: true,
                                      hideEmail: true,
                                      disableClickableNames: true,
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                );
                              },
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
          // Listen for new notifications and show platform notification
          if (currentUser != null)
            Positioned(
              left: 0,
              top: 0,
              child: SizedBox.shrink(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: currentUser.uid)
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          String? title;
                          String? body;
                          if (data['type'] == 'collaborator_added') {
                            title = 'Added as Collaborator';
                            body =
                                'You have been added as a collaborator to the course "${data['courseTitle'] != null ? data['courseTitle'].toString() : 'Untitled'}".';
                          }
                          if (title != null && body != null) {
                            showPlatformNotification(title, body);
                            doc.reference.update({'read': true});
                          }
                        }
                      });
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
