import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/courses/data/course_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/presentation/widgets/course_card.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final courseRepository = CourseRepository(FirebaseFirestore.instance);
    final user = FirebaseAuth.instance.currentUser;
    final studentId = user?.uid;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Courses')),
        body: FutureBuilder<List<CourseModel>>(
          future: courseRepository.getPublishedCourses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error.toString()}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No courses available.'));
            }
            final courses = snapshot.data!;
            return ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                if (studentId == null) {
                  // Not logged in, show 0% progress
                  return CourseCard(course: course, progressPercent: 0.0);
                }
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('progress')
                      .doc('${studentId}_${course.id}')
                      .get(),
                  builder: (context, progressSnapshot) {
                    final progressData = progressSnapshot.hasData &&
                            progressSnapshot.data!.exists
                        ? progressSnapshot.data!.data() as Map<String, dynamic>?
                        : null;
                    final completedChallenges = progressData != null &&
                            progressData['completedChallenges'] is List
                        ? List<String>.from(progressData['completedChallenges'])
                        : <String>[];
                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('challenges')
                          .where('courseId', isEqualTo: course.id)
                          .get(),
                      builder: (context, challengesSnapshot) {
                        final totalChallenges = challengesSnapshot.hasData
                            ? challengesSnapshot.data!.docs.length
                            : 0;
                        final percent = totalChallenges > 0
                            ? completedChallenges.length / totalChallenges
                            : 0.0;
                        return CourseCard(
                          course: course,
                          progressPercent: percent,
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
    );
  }
}
