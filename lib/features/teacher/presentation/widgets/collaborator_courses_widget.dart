import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';

class CollaboratorCoursesWidget extends StatefulWidget {
  const CollaboratorCoursesWidget({Key? key}) : super(key: key);

  @override
  State<CollaboratorCoursesWidget> createState() =>
      _CollaboratorCoursesWidgetState();
}

class _CollaboratorCoursesWidgetState extends State<CollaboratorCoursesWidget> {
  final CollaboratorRepository _collaboratorRepository =
      CollaboratorRepository(FirebaseFirestore.instance);
  List<Map<String, dynamic>> _collaboratorCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollaboratorCourses();
  }

  Future<void> _loadCollaboratorCourses() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final courseIds =
          await _collaboratorRepository.getCollaboratorCourses(currentUser.uid);

      if (courseIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _collaboratorCourses = [];
          _isLoading = false;
        });
        return;
      }

      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where(FieldPath.documentId, whereIn: courseIds)
          .get();

      final courses = <Map<String, dynamic>>[];
      for (var doc in coursesSnapshot.docs) {
        final courseData = doc.data();
        final collaboratorDetails = await _collaboratorRepository
            .getCollaboratorDetails(doc.id, currentUser.uid);

        courses.add({
          'id': doc.id,
          'title': courseData['title'],
          'description': courseData['description'],
          'teacherName': courseData['teacherName'],
          'createdAt': courseData['createdAt'],
          'role':
              collaboratorDetails?.role.toString().split('.').last ?? 'Unknown',
          'permissions': collaboratorDetails?.permissions ?? {},
        });
      }

      setState(() {
        _collaboratorCourses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading collaborator courses: $e')),
        );
      }
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'coteacher':
        return 'Co-Teacher';
      case 'assistant':
        return 'Assistant';
      case 'moderator':
        return 'Moderator';
      default:
        return 'Collaborator';
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'coteacher':
        return Colors.green;
      case 'assistant':
        return Colors.blue;
      case 'moderator':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_collaboratorCourses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple[600]),
                const SizedBox(width: 12),
                Text(
                  'Collaborator Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'You are not collaborating on any courses yet.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.purple[600]),
              const SizedBox(width: 12),
              Text(
                'Collaborator Courses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[600],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.purple[600]),
                tooltip: 'Refresh',
                onPressed: _loadCollaboratorCourses,
              ),
              const Spacer(),
              Text(
                '${_collaboratorCourses.length} course${_collaboratorCourses.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _collaboratorCourses.length,
            itemBuilder: (context, index) {
              final course = _collaboratorCourses[index];
              final createdAt = (course['createdAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _getRoleColor(course['role']).withOpacity(0.1),
                    child: Icon(
                      Icons.school,
                      color: _getRoleColor(course['role']),
                    ),
                  ),
                  title: Text(
                    course['title'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Owner: ${course['teacherName']}'),
                      Text(
                        'Role: ${_getRoleDisplayName(course['role'])}',
                        style: TextStyle(
                          color: _getRoleColor(course['role']),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          'Created: ${createdAt.toLocal().toString().substring(0, 10)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      // Handle course actions based on permissions
                      final permissions =
                          course['permissions'] as Map<String, bool>;

                      switch (value) {
                        case 'view':
                          // Navigate to course view
                          break;
                        case 'challenges':
                          if (permissions['create_challenges'] == true) {
                            // Navigate to challenges
                          }
                          break;
                        case 'students':
                          if (permissions['manage_students'] == true) {
                            // Navigate to students
                          }
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final permissions =
                          course['permissions'] as Map<String, bool>;
                      final items = <PopupMenuEntry<String>>[];

                      items.add(
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility),
                              SizedBox(width: 8),
                              Text('View Course'),
                            ],
                          ),
                        ),
                      );

                      if (permissions['create_challenges'] == true) {
                        items.add(
                          const PopupMenuItem(
                            value: 'challenges',
                            child: Row(
                              children: [
                                Icon(Icons.code),
                                SizedBox(width: 8),
                                Text('Manage Challenges'),
                              ],
                            ),
                          ),
                        );
                      }

                      if (permissions['manage_students'] == true) {
                        items.add(
                          const PopupMenuItem(
                            value: 'students',
                            child: Row(
                              children: [
                                Icon(Icons.people),
                                SizedBox(width: 8),
                                Text('Manage Students'),
                              ],
                            ),
                          ),
                        );
                      }

                      return items;
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
