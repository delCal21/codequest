import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/courses/presentation/bloc/course_bloc.dart';
import 'package:codequest/features/courses/presentation/widgets/course_card.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_course_upload_page.dart';

class CourseList extends StatefulWidget {
  final bool isAdmin;
  final String? teacherId;
  final String? studentId;
  final bool showEnrolledOnly;

  const CourseList({
    Key? key,
    this.isAdmin = false,
    this.teacherId,
    this.studentId,
    this.showEnrolledOnly = false,
  }) : super(key: key);

  @override
  State<CourseList> createState() => _CourseListState();
}

class _CourseListState extends State<CourseList> {
  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() {
    if (widget.showEnrolledOnly && widget.studentId != null) {
      context.read<CourseBloc>().add(LoadEnrolledCourses(widget.studentId!));
    } else {
      context.read<CourseBloc>().add(LoadCourses(
            teacherId: widget.teacherId,
            isAdmin: widget.isAdmin,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseBloc, CourseState>(
      builder: (context, state) {
        if (state is CourseLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is CourseError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadCourses,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (state is CourseLoaded) {
          if (state.courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No courses found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  if (!widget.showEnrolledOnly)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeacherCourseUploadPage(
                              courseBloc: context.read<CourseBloc>(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Course'),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadCourses();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.courses.length,
              itemBuilder: (context, index) {
                final course = state.courses[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CourseCard(
                    course: course,
                    onTap: () {
                      // TODO: Implement navigation to course details or other actions
                      print('Course tapped: ${course.title}');
                    },
                  ),
                );
              },
            ),
          );
        }

        return const Center(child: Text('No courses available'));
      },
    );
  }
}
