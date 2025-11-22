import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codequest/features/admin/presentation/pages/users_page.dart';
import 'package:codequest/features/admin/presentation/pages/challenges_page.dart';
import 'package:codequest/features/admin/presentation/pages/forums_page.dart';
import 'package:codequest/features/admin/presentation/pages/admin_home_page.dart';
// Removed unused bloc imports after relocating logout to header menu
import 'package:flutter/foundation.dart';
import 'package:codequest/features/admin/presentation/pages/courses_crud_page.dart';
import 'package:codequest/features/videos/presentation/pages/videos_crud_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_panel.dart';
import 'notification_model.dart';
import 'package:codequest/features/admin/presentation/pages/backup_restore_page.dart';
import 'package:codequest/features/admin/presentation/pages/admin_profile_page.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/config/routes.dart';

import 'package:codequest/services/notification_service.dart';
import 'package:codequest/services/report_cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'download_helper.dart' as dl;

// All Users Page that shows both teachers and students
class AllUsersPage extends StatefulWidget {
  const AllUsersPage({super.key});

  @override
  State<AllUsersPage> createState() => _AllUsersPageState();
}

class _AllUsersPageState extends State<AllUsersPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Pagination state
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalItems = 0;

  // Course data cache
  Map<String, Map<String, dynamic>> _studentCourseData = {};

  // Fetch course data for a student
  Future<Map<String, dynamic>> _fetchStudentCourseData(String studentId) async {
    if (_studentCourseData.containsKey(studentId)) {
      return _studentCourseData[studentId]!;
    }

    try {
      // Get enrollments for this student
      final enrollmentsQuery = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: studentId)
          .get();

      List<Map<String, dynamic>> courses = [];
      int completedCourses = 0;
      int totalCourses = enrollmentsQuery.docs.length;

      for (var enrollment in enrollmentsQuery.docs) {
        final enrollmentData = enrollment.data();
        final courseId = enrollmentData['courseId'];
        final isCompleted = enrollmentData['completed'] == true;
        final completedAt = enrollmentData['completedAt'];
        final enrolledAt = enrollmentData['enrolledAt'];

        if (isCompleted) {
          completedCourses++;
        }

        // Get course details
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();

        // Calculate actual progress from progress collection
        int progressPercent = 0;
        if (courseDoc.exists) {
          try {
            // Get progress document
            final progressDoc = await FirebaseFirestore.instance
                .collection('progress')
                .doc('${studentId}_${courseId}')
                .get();

            // Get total challenges for this course
            final challengesQuery = await FirebaseFirestore.instance
                .collection('challenges')
                .where('courseId', isEqualTo: courseId)
                .get();

            final totalChallenges = challengesQuery.docs.length;

            if (progressDoc.exists &&
                progressDoc.data() != null &&
                totalChallenges > 0) {
              final progressData = progressDoc.data()!;
              final completedList = progressData['completedChallenges'];
              if (completedList is List) {
                final completedChallenges = completedList.length;
                progressPercent =
                    ((completedChallenges / totalChallenges) * 100)
                        .round()
                        .clamp(0, 100);
              }
            }
          } catch (e) {
            print('Error calculating progress for course $courseId: $e');
          }

          final courseData = courseDoc.data()!;
          courses.add({
            'courseName': courseData['title'] ?? 'Unknown Course',
            'courseId': courseId,
            'isCompleted': isCompleted,
            'completedAt': completedAt,
            'enrolledAt': enrolledAt,
            'progress': progressPercent,
          });
        }
      }

      final result = {
        'courses': courses,
        'totalCourses': totalCourses,
        'completedCourses': completedCourses,
        'completionRate': totalCourses > 0
            ? (completedCourses / totalCourses * 100).round()
            : 0,
      };

      _studentCourseData[studentId] = result;
      return result;
    } catch (e) {
      print('Error fetching course data for student $studentId: $e');
      return {
        'courses': [],
        'totalCourses': 0,
        'completedCourses': 0,
        'completionRate': 0,
      };
    }
  }

  // Show detailed course information for a student
  Future<void> _showStudentCourseDetails(
      String studentName, String studentId) async {
    final courseData = await _fetchStudentCourseData(studentId);
    final courses = courseData['courses'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Course Details - $studentName'),
        content: SizedBox(
          width: double.maxFinite,
          child: courses.isEmpty
              ? const Text('No courses enrolled')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    final isCompleted = course['isCompleted'] as bool? ?? false;
                    final courseName =
                        course['courseName'] as String? ?? 'Unknown';
                    final progress = course['progress'] as int? ?? 0;
                    final completedAt = course['completedAt'];
                    final enrolledAt = course['enrolledAt'];

                    String statusText = 'In Progress';
                    Color statusColor = Colors.orange;

                    if (isCompleted) {
                      statusText = 'Completed';
                      statusColor = Colors.green;
                    }

                    String dateText = 'N/A';
                    if (completedAt != null) {
                      if (completedAt is Timestamp) {
                        dateText =
                            completedAt.toDate().toString().substring(0, 10);
                      } else if (completedAt is String) {
                        dateText = completedAt.substring(0, 10);
                      }
                    } else if (enrolledAt != null) {
                      if (enrolledAt is Timestamp) {
                        dateText =
                            'Enrolled: ${enrolledAt.toDate().toString().substring(0, 10)}';
                      } else if (enrolledAt is String) {
                        dateText = 'Enrolled: ${enrolledAt.substring(0, 10)}';
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          courseName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: $statusText'),
                            Text('Progress: $progress%'),
                            Text('Date: $dateText'),
                          ],
                        ),
                        trailing: Icon(
                          isCompleted ? Icons.check_circle : Icons.schedule,
                          color: statusColor,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .snapshots(),
          builder: (context, snapshot) {
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 16),
                    Text('Loading users...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              );
            }

            // Handle error state
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading users: ${snapshot.error}',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Handle no data state
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, color: Colors.grey, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'No users found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Users will appear here once they are added to the system',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
            // Pair each user data with its doc reference
            List<Map<String, dynamic>> users = docs
                .map(
                  (doc) => {
                    ...((doc.data() ?? {}) as Map<String, dynamic>),
                    '_reference': doc.reference,
                  },
                )
                .toList();

            // Search and filter logic
            List<Map<String, dynamic>> filteredUsers =
                users.where((u) => (u['deleted'] ?? false) != true).toList();
            if (_searchQuery.isNotEmpty) {
              filteredUsers = filteredUsers
                  .where(
                    (u) =>
                        (u['name'] ?? '').toLowerCase().contains(
                              _searchQuery,
                            ) ||
                        (u['email'] ?? '').toLowerCase().contains(_searchQuery),
                  )
                  .toList();
            }

            // Pagination calculations
            _totalItems = filteredUsers.length;
            final startIndex = (_currentPage - 1) * _itemsPerPage;
            final endIndex = (startIndex + _itemsPerPage) > _totalItems
                ? _totalItems
                : (startIndex + _itemsPerPage);
            final paginatedUsers = startIndex < _totalItems
                ? filteredUsers.sublist(startIndex, endIndex)
                : <Map<String, dynamic>>[];

            return Column(
              children: [
                // Header
                Container(
                  color: Colors.green[500],
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 24,
                  ),
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // Detailed Report Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _generateUsersReport(filteredUsers),
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('Generate Report'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Search bar
                          Container(
                            width: 180,
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
                                color: Colors.green,
                                width: 1.2,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search users...',
                                hintStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.green,
                                  size: 18,
                                ),
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
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.green,
                                    width: 1.2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.green,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 14,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.trim().toLowerCase();
                                  _currentPage = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Removed temporary debug info bar
                // Users table
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DataTable(
                            headingRowColor: MaterialStateProperty.all(
                                const Color(0xFFEFF7ED)),
                            dataRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                                    (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.green[100];
                              }
                              return null;
                            }),
                            headingRowHeight: 40,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 45,
                            headingTextStyle: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'NotoSans',
                            ),
                            columns: const [
                              DataColumn(
                                  label: Text('Name',
                                      style: TextStyle(fontSize: 16))),
                              DataColumn(
                                  label: Text('Courses',
                                      style: TextStyle(fontSize: 16))),
                              DataColumn(
                                  label: Text('Progress',
                                      style: TextStyle(fontSize: 16))),
                              DataColumn(
                                  label: Text('Completed',
                                      style: TextStyle(fontSize: 16))),
                              DataColumn(
                                  label: Text('Last Activity',
                                      style: TextStyle(fontSize: 16))),
                            ],
                            rows: paginatedUsers.map((user) {
                              final userId = user['_reference']?.id ?? '';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      (user['name'] ?? 'N/A').toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    FutureBuilder<Map<String, dynamic>>(
                                      future: _fetchStudentCourseData(userId),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          );
                                        }

                                        if (snapshot.hasError) {
                                          return const Text('Error',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red));
                                        }

                                        final data = snapshot.data ?? {};
                                        final courses =
                                            data['courses'] as List<dynamic>? ??
                                                [];
                                        final totalCourses =
                                            data['totalCourses'] ?? 0;

                                        if (totalCourses == 0) {
                                          return const Text('No courses',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey));
                                        }

                                        return Text(
                                          '${courses.length} enrolled',
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    FutureBuilder<Map<String, dynamic>>(
                                      future: _fetchStudentCourseData(userId),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          );
                                        }

                                        if (snapshot.hasError) {
                                          return const Text('Error',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red));
                                        }

                                        final data = snapshot.data ?? {};
                                        final completionRate =
                                            data['completionRate'] ?? 0;

                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$completionRate%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: completionRate == 100
                                                    ? Colors.green
                                                    : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            SizedBox(
                                              width: 30,
                                              height: 4,
                                              child: LinearProgressIndicator(
                                                value: completionRate / 100,
                                                backgroundColor:
                                                    Colors.grey[300],
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  completionRate == 100
                                                      ? Colors.green
                                                      : Colors.orange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    FutureBuilder<Map<String, dynamic>>(
                                      future: _fetchStudentCourseData(userId),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          );
                                        }

                                        if (snapshot.hasError) {
                                          return const Text('Error',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red));
                                        }

                                        final data = snapshot.data ?? {};
                                        final completedCourses =
                                            data['completedCourses'] ?? 0;
                                        final totalCourses =
                                            data['totalCourses'] ?? 0;

                                        return Text(
                                          '$completedCourses/$totalCourses',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: completedCourses ==
                                                        totalCourses &&
                                                    totalCourses > 0
                                                ? Colors.green
                                                : Colors.black87,
                                            fontWeight: completedCourses ==
                                                        totalCourses &&
                                                    totalCourses > 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    FutureBuilder<Map<String, dynamic>>(
                                      future: _fetchStudentCourseData(userId),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          );
                                        }

                                        if (snapshot.hasError) {
                                          return const Text('Error',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red));
                                        }

                                        final data = snapshot.data ?? {};
                                        final courses =
                                            data['courses'] as List<dynamic>? ??
                                                [];

                                        if (courses.isEmpty) {
                                          return const Text('N/A',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey));
                                        }

                                        // Find the most recent activity
                                        DateTime? mostRecent;
                                        for (var course in courses) {
                                          final completedAt =
                                              course['completedAt'];
                                          final enrolledAt =
                                              course['enrolledAt'];

                                          DateTime? courseDate;
                                          if (completedAt != null) {
                                            if (completedAt is Timestamp) {
                                              courseDate = completedAt.toDate();
                                            } else if (completedAt is String) {
                                              try {
                                                courseDate =
                                                    DateTime.parse(completedAt);
                                              } catch (e) {
                                                // Ignore parsing errors
                                              }
                                            }
                                          } else if (enrolledAt != null) {
                                            if (enrolledAt is Timestamp) {
                                              courseDate = enrolledAt.toDate();
                                            } else if (enrolledAt is String) {
                                              try {
                                                courseDate =
                                                    DateTime.parse(enrolledAt);
                                              } catch (e) {
                                                // Ignore parsing errors
                                              }
                                            }
                                          }

                                          if (courseDate != null &&
                                              (mostRecent == null ||
                                                  courseDate
                                                      .isAfter(mostRecent))) {
                                            mostRecent = courseDate;
                                          }
                                        }

                                        if (mostRecent == null) {
                                          return const Text('N/A',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey));
                                        }

                                        return Text(
                                          '${mostRecent.year}-${mostRecent.month.toString().padLeft(2, '0')}-${mostRecent.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          // Pagination controls
                          if (_totalItems > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 16, right: 20, bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: _currentPage > 1
                                        ? () => setState(() => _currentPage--)
                                        : null,
                                    child: const Text('Previous',
                                        style: TextStyle(fontSize: 14)),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Page $_currentPage of ${(_totalItems / _itemsPerPage).ceil()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: _currentPage <
                                            (_totalItems / _itemsPerPage).ceil()
                                        ? () => setState(() => _currentPage++)
                                        : null,
                                    child: const Text('Next',
                                        style: TextStyle(fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Fetch course data for all students in the report
  Future<Map<String, Map<String, dynamic>>> _fetchAllStudentsCourseData(
      List<Map<String, dynamic>> users) async {
    final Map<String, Map<String, dynamic>> allCourseData = {};

    for (final user in users) {
      final userId = user['_reference']?.id ?? '';
      if (userId.isNotEmpty) {
        try {
          // Get enrollments for this student
          final enrollmentsQuery = await FirebaseFirestore.instance
              .collection('enrollments')
              .where('studentId', isEqualTo: userId)
              .get();

          List<Map<String, dynamic>> courses = [];
          int completedCourses = 0;
          int totalCourses = enrollmentsQuery.docs.length;

          for (var enrollment in enrollmentsQuery.docs) {
            final enrollmentData = enrollment.data();
            final courseId = enrollmentData['courseId'];
            final isCompleted = enrollmentData['completed'] == true;
            final completedAt = enrollmentData['completedAt'];
            final enrolledAt = enrollmentData['enrolledAt'];

            if (isCompleted) {
              completedCourses++;
            }

            // Get course details
            final courseDoc = await FirebaseFirestore.instance
                .collection('courses')
                .doc(courseId)
                .get();

            // Calculate actual progress from progress collection
            int progressPercent = 0;
            if (courseDoc.exists) {
              try {
                // Get progress document
                final progressDoc = await FirebaseFirestore.instance
                    .collection('progress')
                    .doc('${userId}_${courseId}')
                    .get();

                // Get total challenges for this course
                final challengesQuery = await FirebaseFirestore.instance
                    .collection('challenges')
                    .where('courseId', isEqualTo: courseId)
                    .get();

                final totalChallenges = challengesQuery.docs.length;

                if (progressDoc.exists &&
                    progressDoc.data() != null &&
                    totalChallenges > 0) {
                  final progressData = progressDoc.data()!;
                  final completedList = progressData['completedChallenges'];
                  if (completedList is List) {
                    final completedChallenges = completedList.length;
                    progressPercent =
                        ((completedChallenges / totalChallenges) * 100)
                            .round()
                            .clamp(0, 100);
                  }
                }
              } catch (e) {
                print('Error calculating progress for course $courseId: $e');
              }

              final courseData = courseDoc.data()!;
              courses.add({
                'courseName': courseData['title'] ?? 'Unknown Course',
                'courseId': courseId,
                'isCompleted': isCompleted,
                'completedAt': completedAt,
                'enrolledAt': enrolledAt,
                'progress': progressPercent,
              });
            }
          }

          allCourseData[userId] = {
            'courses': courses,
            'totalCourses': totalCourses,
            'completedCourses': completedCourses,
            'completionRate': totalCourses > 0
                ? (completedCourses / totalCourses * 100).round()
                : 0,
          };
        } catch (e) {
          print('Error fetching course data for student $userId: $e');
          allCourseData[userId] = {
            'courses': [],
            'totalCourses': 0,
            'completedCourses': 0,
            'completionRate': 0,
          };
        }
      }
    }

    return allCourseData;
  }

  Future<void> _generateUsersReport(List<Map<String, dynamic>> users) async {
    // Check cache first
    final cacheService = ReportCacheService();
    final cacheKey = cacheService.generateCacheKey(
      reportType: 'students_report',
      filters: {
        'userCount': users.length,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/
            (1000 * 60 * 5), // 5-minute cache window
      },
      dataVersion: 3, // Updated version to include course data
    );

    final cachedData = cacheService.getCachedReport(cacheKey);
    if (cachedData != null) {
      // Use cached report
      final now = DateTime.now();
      dl.downloadPdfForPlatform(context, cachedData, now);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Students report loaded from cache! (${(cachedData.length / 1024).toStringAsFixed(1)} KB)'),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // For very large datasets, offer a quick summary report instead
    if (users.length > 1000) {
      final shouldGenerateSummary = await _showLargeDatasetDialog(users.length);
      if (shouldGenerateSummary == true) {
        await _generateQuickSummaryReport(users);
        return;
      } else if (shouldGenerateSummary == false) {
        return; // User cancelled
      }
    }

    // Show progress dialog with timeout
    bool isCancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FastReportProgressDialog(
        totalUsers: users.length,
        onCancel: () {
          isCancelled = true;
          Navigator.of(context).pop();
        },
      ),
    );

    try {
      // Fetch course data for all students
      final courseData = await _fetchAllStudentsCourseData(users);

      // Optimize data preparation - simplified and faster processing
      final List<Map<String, dynamic>> cleaned = users.map((u) {
        final userId = u['_reference']?.id ?? '';
        final studentCourseData = courseData[userId] ??
            {
              'courses': [],
              'totalCourses': 0,
              'completedCourses': 0,
              'completionRate': 0,
            };

        // Simplified date processing for started date
        String started = 'N/A';
        final createdAt = u['createdAt'];
        if (createdAt is Timestamp) {
          started = createdAt.toDate().toString().substring(0, 10);
        } else if (createdAt is String && createdAt.length >= 10) {
          started = createdAt.substring(0, 10);
        }

        // Process finished date
        String finished = 'N/A';
        final finishedAt =
            u['finishedAt'] ?? u['completedAt'] ?? u['lastLoginAt'];
        if (finishedAt is Timestamp) {
          finished = finishedAt.toDate().toString().substring(0, 10);
        } else if (finishedAt is String && finishedAt.length >= 10) {
          finished = finishedAt.substring(0, 10);
        }

        // Get course information
        final courses = studentCourseData['courses'] as List<dynamic>? ?? [];
        final totalCourses = studentCourseData['totalCourses'] ?? 0;
        final completedCourses = studentCourseData['completedCourses'] ?? 0;
        final completionRate = studentCourseData['completionRate'] ?? 0;

        // Find most recent activity
        String lastActivity = 'N/A';
        DateTime? mostRecent;
        for (var course in courses) {
          final completedAt = course['completedAt'];
          final enrolledAt = course['enrolledAt'];

          DateTime? courseDate;
          if (completedAt != null) {
            if (completedAt is Timestamp) {
              courseDate = completedAt.toDate();
            } else if (completedAt is String) {
              try {
                courseDate = DateTime.parse(completedAt);
              } catch (e) {
                // Ignore parsing errors
              }
            }
          } else if (enrolledAt != null) {
            if (enrolledAt is Timestamp) {
              courseDate = enrolledAt.toDate();
            } else if (enrolledAt is String) {
              try {
                courseDate = DateTime.parse(enrolledAt);
              } catch (e) {
                // Ignore parsing errors
              }
            }
          }

          if (courseDate != null &&
              (mostRecent == null || courseDate.isAfter(mostRecent))) {
            mostRecent = courseDate;
          }
        }

        if (mostRecent != null) {
          lastActivity =
              '${mostRecent.year}-${mostRecent.month.toString().padLeft(2, '0')}-${mostRecent.day.toString().padLeft(2, '0')}';
        }

        return {
          'name': (u['name'] ?? 'N/A').toString(),
          'started': started,
          'finished': finished,
          'courses': totalCourses,
          'progress': completionRate,
          'completed': '$completedCourses/$totalCourses',
          'lastActivity': lastActivity,
        };
      }).toList();

      final args = {
        'users': cleaned,
        'totalCount': cleaned.length,
        // Enable fast mode for better performance (very aggressive threshold)
        'fastMode': cleaned.length > 50,
      };

      // Use timeout for report generation
      final List<int> bytes =
          await _generateReportWithTimeout(args, isCancelled);

      if (isCancelled || !mounted) return;
      Navigator.of(context).pop(); // Close progress dialog

      final now = DateTime.now();
      dl.downloadPdfForPlatform(context, bytes, now);

      // Cache the generated report
      cacheService.cacheReport(cacheKey, Uint8List.fromList(bytes));

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Students report generated successfully! (${(bytes.length / 1024).toStringAsFixed(1)} KB)'),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted && !isCancelled) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating students report: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Show dialog for large datasets offering summary report
  Future<bool?> _showLargeDatasetDialog(int userCount) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Large Dataset Detected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have $userCount students. Generating a full report may take several minutes.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose an option:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• Quick Summary: Fast overview (recommended)'),
            const Text('• Full Report: Complete detailed report'),
            const Text('• Cancel: Return without generating'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]),
            child: const Text('Quick Summary'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, null),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
            child: const Text('Full Report'),
          ),
        ],
      ),
    );
  }

  // Generate quick summary report for large datasets
  Future<void> _generateQuickSummaryReport(
      List<Map<String, dynamic>> users) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Generating Quick Summary...'),
          ],
        ),
      ),
    );

    try {
      // Generate summary statistics
      final stats = _calculateUserStats(users);

      // Create simple summary PDF
      final bytes = await _generateSummaryPdf(stats);

      if (!mounted) return;
      Navigator.of(context).pop();

      final now = DateTime.now();
      dl.downloadPdfForPlatform(context, bytes, now);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Summary report generated! (${(bytes.length / 1024).toStringAsFixed(1)} KB)'),
          backgroundColor: Colors.green[600],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating summary: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  // Generate report with timeout
  Future<List<int>> _generateReportWithTimeout(
      Map<String, dynamic> args, bool isCancelled) async {
    const timeout = Duration(seconds: 15); // Further reduced timeout

    try {
      return await Future.any([
        compute(_buildUsersPdfBytes, args),
        Future.delayed(timeout, () {
          if (isCancelled) throw Exception('Cancelled');
          throw Exception(
              'Report generation timed out after ${timeout.inSeconds} seconds');
        }),
      ]);
    } catch (e) {
      if (isCancelled) {
        throw Exception('Report generation cancelled');
      }
      rethrow;
    }
  }

  // Calculate user statistics for summary report
  Map<String, dynamic> _calculateUserStats(List<Map<String, dynamic>> users) {
    int teachers = 0;
    int students = 0;
    int started = 0;
    int finished = 0;

    for (final user in users) {
      if (user['role'] == 'teacher') {
        teachers++;
      } else if (user['role'] == 'student') {
        students++;
      }

      // Check if user has started (has createdAt)
      final createdAt = user['createdAt'];
      if (createdAt != null) {
        started++;
      }

      // Check if user has finished (has finishedAt, completedAt, or lastLoginAt)
      final finishedAt =
          user['finishedAt'] ?? user['completedAt'] ?? user['lastLoginAt'];
      if (finishedAt != null) {
        finished++;
      }
    }

    return {
      'total': users.length,
      'teachers': teachers,
      'students': students,
      'started': started,
      'finished': finished,
      'generatedAt': DateTime.now(),
    };
  }

  // Generate simple summary PDF
  Future<List<int>> _generateSummaryPdf(Map<String, dynamic> stats) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final PdfGraphics g = page.graphics;

    final PdfFont titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    g.drawString('CodeQuest - Student Summary Report', titleFont,
        bounds: const Rect.fromLTWH(50, 50, 500, 30));
    g.drawString(
        'Generated: ${stats['generatedAt'].toString().substring(0, 19)}',
        bodyFont,
        bounds: const Rect.fromLTWH(50, 80, 500, 20));

    double y = 120;
    g.drawString('Total Students: ${stats['total']}', bodyFont,
        bounds: Rect.fromLTWH(50, y, 500, 20));
    y += 30;
    g.drawString('Teachers: ${stats['teachers']}', bodyFont,
        bounds: Rect.fromLTWH(50, y, 500, 20));
    y += 30;
    g.drawString('Students: ${stats['students']}', bodyFont,
        bounds: Rect.fromLTWH(50, y, 500, 20));
    y += 30;
    g.drawString('Started Students: ${stats['started']}', bodyFont,
        bounds: Rect.fromLTWH(50, y, 500, 20));
    y += 30;
    g.drawString('Finished Students: ${stats['finished']}', bodyFont,
        bounds: Rect.fromLTWH(50, y, 500, 20));

    final bytes = await document.save();
    document.dispose();
    return bytes;
  }

  void _showPdfPreviewDialog(
    BuildContext context,
    List<int> pdfBytes,
    DateTime timestamp,
  ) {}

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue[600], size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.blue[600])),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _downloadPdf(List<int> pdfBytes, DateTime timestamp) {
    dl.downloadPdfForPlatform(context, pdfBytes, timestamp);
  }

  Future<void> _handleTeacherStatusChange(
    DocumentReference docRef,
    Map<String, dynamic> user,
  ) async {
    final isCurrentlyActive = user['active'] ?? true;
    final teacherId = user['id'] ?? docRef.id;
    final teacherName = user['name'] ?? 'Unknown Teacher';

    // If setting to inactive, check for assigned courses
    if (isCurrentlyActive) {
      // Check if teacher has assigned courses
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (coursesSnapshot.docs.isNotEmpty) {
        // Teacher has courses, show reassignment dialog
        final shouldReassign = await _showCourseReassignmentDialog(
          teacherName,
          coursesSnapshot.docs,
        );

        if (shouldReassign == null) {
          // User cancelled
          return;
        }

        if (shouldReassign) {
          // User chose to reassign courses - show course selection dialog
          final selectedCourses = await _showCourseSelectionDialog(
            teacherName,
            coursesSnapshot.docs,
          );

          if (selectedCourses != null && selectedCourses.isNotEmpty) {
            // Reassign selected courses to different teachers
            await _reassignSelectedCourses(
              teacherId,
              teacherName,
              selectedCourses,
            );
          } else {
            // If none selected, assign all courses to current admin
            await _assignCoursesToAdmin(coursesSnapshot.docs);
          }
        } else {
          // Auto-assign courses to current admin
          await _assignCoursesToAdmin(coursesSnapshot.docs);
        }
        // If shouldReassign is false, user chose to keep courses unassigned
      }
    }

    // Update teacher status
    await docRef.update({'active': !isCurrentlyActive});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Teacher status updated to ${!isCurrentlyActive ? 'Active' : 'Inactive'}',
        ),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {});
  }

  Future<bool?> _showCourseReassignmentDialog(
    String teacherName,
    List<QueryDocumentSnapshot> courses,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Teacher Has Assigned Courses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The teacher "$teacherName" has ${courses.length} assigned course${courses.length == 1 ? '' : 's'}.',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              'What would you like to do with these courses?',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Courses:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...courses.take(3).map((course) {
                    final courseData = course.data() as Map<String, dynamic>;
                    final courseTitle =
                        courseData['title'] ?? 'Untitled Course';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.book, size: 16, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              courseTitle,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (courses.length > 3)
                    Text(
                      '... and ${courses.length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Assign to Admin
            child: Text(
              'Assign to Admin',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // Reassign courses
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Reassign Courses'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null), // Cancel
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Show dialog to select which courses to reassign
  Future<List<QueryDocumentSnapshot>?> _showCourseSelectionDialog(
    String teacherName,
    List<QueryDocumentSnapshot> courses,
  ) async {
    if (courses.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No courses found for $teacherName'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return null;
    }

    final selectedCourses = <QueryDocumentSnapshot>[];

    return await showDialog<List<QueryDocumentSnapshot>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.blue[600], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Courses to Reassign',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select which courses from $teacherName to reassign:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final courseDoc = courses[index];
                      final courseData =
                          courseDoc.data() as Map<String, dynamic>;
                      final courseTitle =
                          courseData['title'] ?? 'Untitled Course';
                      final isSelected = selectedCourses.contains(courseDoc);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: isSelected ? 4 : 1,
                        color: isSelected ? Colors.blue[50] : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue[300]!
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedCourses.add(courseDoc);
                              } else {
                                selectedCourses.remove(courseDoc);
                              }
                            });
                          },
                          title: Text(
                            courseTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          subtitle: Text(
                            'Course ID: ${courseDoc.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          secondary: Icon(
                            Icons.book,
                            color: Colors.blue[600],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: selectedCourses.isEmpty
                          ? null
                          : () => Navigator.pop(context, selectedCourses),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                          'Reassign ${selectedCourses.length} Course${selectedCourses.length == 1 ? '' : 's'}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced reassignment: Allow assigning different courses to different teachers
  Future<void> _reassignSelectedCourses(
    String teacherId,
    String teacherName,
    List<QueryDocumentSnapshot> selectedCourses,
  ) async {
    // Get all active teachers
    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('active', isEqualTo: true)
        .get();

    if (teachersSnapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('No active teachers found to reassign courses to.'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    // Filter out the current teacher
    final availableTeachers =
        teachersSnapshot.docs.where((doc) => doc.id != teacherId).toList();

    if (availableTeachers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'No other active teachers available to reassign courses to.'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    // Map to store course assignments: courseId -> teacherId
    final Map<String, String> courseAssignments = {};
    final Map<String, String> teacherNames = {};

    // Initialize teacher names map
    for (final teacherDoc in availableTeachers) {
      final teacherData = teacherDoc.data();
      teacherNames[teacherDoc.id] = teacherData['name'] ?? 'Unknown';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.blue[600], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Assign Courses to Teachers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Assign each course from $teacherName to a different teacher:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                // Course assignment list
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectedCourses.length,
                    itemBuilder: (context, index) {
                      final courseDoc = selectedCourses[index];
                      final courseData =
                          courseDoc.data() as Map<String, dynamic>;
                      final courseTitle =
                          courseData['title'] ?? 'Untitled Course';
                      final assignedTeacherId = courseAssignments[courseDoc.id];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.book,
                                      color: Colors.blue[600], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      courseTitle,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  if (assignedTeacherId != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Assign to:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: availableTeachers.map((teacherDoc) {
                                  final teacherData = teacherDoc.data();
                                  final teacherName =
                                      teacherData['name'] ?? 'Unknown';
                                  final isSelected =
                                      assignedTeacherId == teacherDoc.id;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        courseAssignments[courseDoc.id] =
                                            teacherDoc.id;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue[100]
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.blue[300]!
                                              : Colors.grey[300]!,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: isSelected
                                                ? Colors.blue[200]
                                                : Colors.grey[200],
                                            child: Text(
                                              teacherName.isNotEmpty
                                                  ? teacherName[0].toUpperCase()
                                                  : 'T',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isSelected
                                                    ? Colors.blue[800]
                                                    : Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            teacherName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isSelected
                                                  ? Colors.blue[800]
                                                  : Colors.grey[700],
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Summary
                if (courseAssignments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assignment Summary:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...courseAssignments.entries.map((entry) {
                          final courseDoc = selectedCourses.firstWhere(
                            (doc) => doc.id == entry.key,
                          );
                          final courseData =
                              courseDoc.data() as Map<String, dynamic>;
                          final courseTitle =
                              courseData['title'] ?? 'Untitled Course';
                          final teacherName =
                              teacherNames[entry.value] ?? 'Unknown';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_forward,
                                    size: 14, color: Colors.blue[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$courseTitle → $teacherName',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: courseAssignments.length !=
                              selectedCourses.length
                          ? null
                          : () async {
                              try {
                                final admin = FirebaseAuth.instance.currentUser;
                                String assignedByName = 'Admin';
                                if (admin != null) {
                                  try {
                                    final doc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(admin.uid)
                                        .get();
                                    final data = doc.data();
                                    assignedByName = (data != null
                                            ? (data['name'] as String?)
                                            : null) ??
                                        admin.displayName ??
                                        admin.email ??
                                        'Admin';
                                  } catch (_) {
                                    assignedByName = admin.displayName ??
                                        admin.email ??
                                        'Admin';
                                  }
                                }

                                // Reassign each course to its assigned teacher
                                for (final entry in courseAssignments.entries) {
                                  final courseId = entry.key;
                                  final teacherId = entry.value;
                                  final teacherName =
                                      teacherNames[teacherId] ?? 'Unknown';

                                  await FirebaseFirestore.instance
                                      .collection('courses')
                                      .doc(courseId)
                                      .update({
                                    'teacherId': teacherId,
                                    'teacherName': teacherName,
                                    'assignedBy': admin?.uid,
                                    'assignedByName': assignedByName,
                                    'assignedAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                }

                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Successfully reassigned ${selectedCourses.length} course${selectedCourses.length == 1 ? '' : 's'} to different teachers',
                                    ),
                                    backgroundColor: Colors.green[600],
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Error reassigning courses: $e'),
                                    backgroundColor: Colors.red[600],
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Assign ${courseAssignments.length}/${selectedCourses.length} Courses',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _assignCoursesToAdmin(
    List<QueryDocumentSnapshot> courses,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No admin user is currently signed in.'),
            backgroundColor: Colors.red[600],
          ),
        );
        return;
      }

      String adminName = currentUser.displayName ?? '';
      if (adminName.isEmpty) {
        try {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          final data = adminDoc.data();
          adminName = (data != null ? (data['name'] as String?) : null) ??
              currentUser.email ??
              'Admin';
        } catch (_) {
          adminName = currentUser.email ?? 'Admin';
        }
      }

      for (final courseDoc in courses) {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseDoc.id)
            .update({
          'teacherId': currentUser.uid,
          'teacherName': adminName,
          'assignedBy': currentUser.uid,
          'assignedByName': adminName,
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Assigned ${courses.length} course${courses.length == 1 ? '' : 's'} to $adminName (Admin).'),
          backgroundColor: Colors.green[600],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning courses to admin: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }
}

// Fast progress dialog widget for report generation
class _FastReportProgressDialog extends StatefulWidget {
  final int totalUsers;
  final VoidCallback onCancel;

  const _FastReportProgressDialog({
    required this.totalUsers,
    required this.onCancel,
  });

  @override
  State<_FastReportProgressDialog> createState() =>
      _FastReportProgressDialogState();
}

class _FastReportProgressDialogState extends State<_FastReportProgressDialog> {
  String _currentStep = 'Preparing data...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _simulateProgress();
  }

  void _simulateProgress() async {
    final steps = [
      'Preparing data...',
      'Processing student information...',
      'Generating PDF document...',
      'Finalizing report...',
    ];

    for (int i = 0; i < steps.length; i++) {
      if (mounted) {
        setState(() {
          _currentStep = steps[i];
          _progress = (i + 1) / steps.length;
        });
      }
      await Future.delayed(const Duration(milliseconds: 300)); // Faster updates
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Generating Report...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing ${widget.totalUsers} students',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take up to 30 seconds...',
            style: TextStyle(fontSize: 10, color: Colors.orange[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}

// Progress dialog widget for report generation
class _ReportProgressDialog extends StatefulWidget {
  final int totalUsers;
  final VoidCallback onCancel;

  const _ReportProgressDialog({
    required this.totalUsers,
    required this.onCancel,
  });

  @override
  State<_ReportProgressDialog> createState() => _ReportProgressDialogState();
}

class _ReportProgressDialogState extends State<_ReportProgressDialog> {
  String _currentStep = 'Preparing data...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _simulateProgress();
  }

  void _simulateProgress() async {
    final steps = [
      'Preparing data...',
      'Processing student information...',
      'Generating PDF document...',
      'Finalizing report...',
    ];

    for (int i = 0; i < steps.length; i++) {
      if (mounted) {
        setState(() {
          _currentStep = steps[i];
          _progress = (i + 1) / steps.length;
        });
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Generating Report...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing ${widget.totalUsers} students',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}

// Top-level function for compute to generate PDF bytes off the UI thread
Future<List<int>> _buildUsersPdfBytes(Map<String, dynamic> args) async {
  final List<dynamic> users = args['users'] as List<dynamic>;
  final int totalCount = args['totalCount'] as int;
  final bool fastMode = (args['fastMode'] as bool?) ?? false;

  final PdfDocument document = PdfDocument();

  // Optimize page settings for better performance
  document.pageSettings.margins.left = 0;
  document.pageSettings.margins.right = 0;
  document.pageSettings.margins.top = 0;
  document.pageSettings.margins.bottom = 40;

  // Pre-create minimal fonts for maximum speed
  final PdfFont gridFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
  final PdfFont gridHeaderFont = fastMode
      ? gridFont
      : PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
  final PdfFont headerTitle = fastMode
      ? gridFont
      : PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
  final PdfFont headerMeta =
      fastMode ? gridFont : PdfStandardFont(PdfFontFamily.helvetica, 10);
  final PdfFont footerFont = gridFont; // Reuse gridFont for footer
  final PdfFont sectionTitle = gridHeaderFont; // Reuse gridHeaderFont
  final PdfFont bodyFont = gridFont; // Reuse gridFont for body

  // Header template (skip when fastMode)
  if (!fastMode) {
    document.template.top =
        PdfPageTemplateElement(const Rect.fromLTWH(0, 0, 595, 50));
    final PdfPageTemplateElement? topTemplate = document.template.top;
    if (topTemplate != null) {
      final PdfGraphics header = topTemplate.graphics;
      header.drawRectangle(
        brush: PdfSolidBrush(PdfColor(239, 248, 243)),
        bounds: const Rect.fromLTWH(0, 0, 595, 50),
      );
      final now = DateTime.now();
      header.drawString(
        'CodeQuest - Students Management Report',
        headerTitle,
        bounds: const Rect.fromLTWH(20, 8, 470, 24),
      );
      header.drawString(
        'Generated on: ${now.toString().substring(0, 19)}',
        headerMeta,
        bounds: const Rect.fromLTWH(20, 30, 300, 16),
      );
    }
  }

  // Footer template (skip when fastMode)
  if (!fastMode) {
    document.template.bottom =
        PdfPageTemplateElement(const Rect.fromLTWH(0, 0, 595, 40));
    final PdfPageTemplateElement? bottomTemplate = document.template.bottom;
    if (bottomTemplate != null) {
      final PdfGraphics footer = bottomTemplate.graphics;
      footer.drawLine(
        PdfPen(PdfColor(210, 210, 210)),
        const Offset(20, 6),
        const Offset(575, 6),
      );
      // Add DMMMSU-NLUC-CIS on the left side instead of pagination
      footer.drawString(
        'DMMMSU-NLUC-CIS',
        footerFont,
        bounds: const Rect.fromLTWH(20, 16, 200, 20),
      );
    }
  }

  // First page (header template is already applied when not in fast mode)
  final PdfPage firstPage = document.pages.add();
  // No extra title/date text here; keep only the header and start the table below it

  // Pre-calculate statistics for better performance
  int startedCount = 0;
  int finishedCount = 0;

  for (final user in users) {
    final userMap = user as Map<String, dynamic>;
    final started = userMap['started'] as String?;
    final finished = userMap['finished'] as String?;

    if (started != null && started != 'N/A') {
      startedCount++;
    }
    if (finished != null && finished != 'N/A') {
      finishedCount++;
    }
  }

  // Prepare summary values (drawn at the bottom of the table on the last page)

  // Create optimized grid with course data columns
  final PdfGrid grid = PdfGrid();
  grid.columns.add(count: 6);
  grid.style = PdfGridStyle(
    cellPadding: fastMode
        ? PdfPaddings(left: 2, right: 2, top: 2, bottom: 2)
        : PdfPaddings(left: 6, right: 6, top: 6, bottom: 6),
    font: gridFont,
  );
  // Expand to fit available width with relative distribution
  final double contentWidth =
      firstPage.getClientSize().width - 40; // 20px margins
  grid.columns[0].width = contentWidth * 0.25; // Name
  grid.columns[1].width = contentWidth * 0.15; // Courses
  grid.columns[2].width = contentWidth * 0.15; // Progress
  grid.columns[3].width = contentWidth * 0.15; // Completed
  grid.columns[4].width = contentWidth * 0.15; // Last Activity
  grid.columns[5].width = contentWidth * 0.15; // Started

  // Add header row
  final PdfGridRow headerRow = grid.headers.add(1)[0];
  headerRow.cells[0].value = 'Name';
  headerRow.cells[1].value = 'Courses';
  headerRow.cells[2].value = 'Progress';
  headerRow.cells[3].value = 'Completed';
  headerRow.cells[4].value = 'Last Activity';
  headerRow.cells[5].value = 'Started';

  // Professional header style: light green background when not in fast mode
  headerRow.style = PdfGridRowStyle(
    font: gridHeaderFont,
    textBrush: PdfSolidBrush(PdfColor(0, 0, 0)),
    backgroundBrush:
        fastMode ? null : PdfSolidBrush(PdfColor(235, 247, 238)), // soft green
  );

  // Set header alignment (simplified in fast mode)
  for (int i = 0; i < headerRow.cells.count; i++) {
    headerRow.cells[i].stringFormat =
        PdfStringFormat(alignment: PdfTextAlignment.center);
    // Skip borders in fast mode for better performance
    if (!fastMode) {
      headerRow.cells[i].style = PdfGridCellStyle(
        borders: PdfBorders(
          left: PdfPen(PdfColor(0, 0, 0), width: 1),
          right: PdfPen(PdfColor(0, 0, 0), width: 1),
          top: PdfPen(PdfColor(0, 0, 0), width: 1),
          bottom: PdfPen(PdfColor(0, 0, 0), width: 1),
        ),
      );
    }
  }

  // Ultra-fast data row processing
  for (int i = 0; i < users.length; i++) {
    final user = users[i] as Map<String, dynamic>;
    final PdfGridRow row = grid.rows.add();

    row.cells[0].value = user['name'] ?? 'N/A';
    row.cells[1].value = user['courses']?.toString() ?? '0';
    row.cells[2].value = '${user['progress'] ?? 0}%';
    row.cells[3].value = user['completed'] ?? '0/0';
    row.cells[4].value = user['lastActivity'] ?? 'N/A';
    row.cells[5].value = user['started'] ?? 'N/A';

    // Skip styling in fast mode for maximum speed
    if (!fastMode) {
      // Set cell alignment only when not in fast mode
      row.cells[0].stringFormat =
          PdfStringFormat(alignment: PdfTextAlignment.left); // Name
      row.cells[1].stringFormat =
          PdfStringFormat(alignment: PdfTextAlignment.center); // Courses
      row.cells[2].stringFormat =
          PdfStringFormat(alignment: PdfTextAlignment.center); // Progress
      row.cells[3].stringFormat =
          PdfStringFormat(alignment: PdfTextAlignment.center); // Completed
      row.cells[4].stringFormat =
          PdfStringFormat(alignment: PdfTextAlignment.center); // Last Activity
      row.cells[5].stringFormat =
          PdfStringFormat(alignment: PdfTextAlignment.center); // Started

      // Add minimal styling only when not in fast mode
      for (int c = 0; c < row.cells.count; c++) {
        row.cells[c].style = PdfGridCellStyle(
          borders: PdfBorders(
            left: PdfPen(PdfColor(220, 220, 220), width: 0.5),
            right: PdfPen(PdfColor(220, 220, 220), width: 0.5),
            top: PdfPen(PdfColor(220, 220, 220), width: 0.5),
            bottom: PdfPen(PdfColor(220, 220, 220), width: 0.5),
          ),
          backgroundBrush:
              (i % 2 == 1) ? PdfSolidBrush(PdfColor(250, 250, 250)) : null,
        );
      }
    }
  }

  // Draw grid to auto-fit width. Use layout result to continue if multiple pages.
  final PdfLayoutResult result = grid.draw(
    page: firstPage,
    bounds: const Rect.fromLTWH(20, 25, 555, 0),
  )!;

  // Move summary directly after the table; if no space, create a new page
  PdfPage summaryPage = result.page;
  double summaryY = result.bounds.bottom + 20;
  final double maxY = summaryPage.getClientSize().height - 60;
  if (summaryY > maxY) {
    summaryPage = document.pages.add();
    summaryY = 40;
  }
  final PdfGraphics lg = summaryPage.graphics;
  lg.drawLine(
    PdfPen(PdfColor(210, 210, 210)),
    Offset(20, summaryY - 10),
    Offset(summaryPage.size.width - 20, summaryY - 10),
  );
  lg.drawString('Summary', sectionTitle,
      bounds: Rect.fromLTWH(20, summaryY, 200, 20));
  lg.drawString('Total Students: $totalCount', bodyFont,
      bounds: Rect.fromLTWH(20, summaryY + 18, 250, 16));
  lg.drawString('Started: $startedCount', bodyFont,
      bounds: Rect.fromLTWH(220, summaryY + 18, 200, 16));
  lg.drawString('Finished: $finishedCount', bodyFont,
      bounds: Rect.fromLTWH(380, summaryY + 18, 200, 16));

  // Save and dispose
  final bytes = await document.save();
  document.dispose();
  return bytes;
}

class AdminDashboardPage extends StatefulWidget {
  final int initialIndex;
  const AdminDashboardPage({super.key, this.initialIndex = 0});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  final _pages = [
    const AdminHomePage(),
    const CoursesCrudPage(),
    const ChallengesPage(),
    const VideosCrudPage(),
    const ForumsPage(),
    const AllUsersPage(),
    const UsersPage(),
  ];
  final _labels = [
    'Dashboard',
    'Courses',
    'Challenges',
    'Videos',
    'Forums',
    'Students',
    'Teachers',
    'Backup & Restore',
  ];
  final _icons = [
    Icons.dashboard_rounded,
    Icons.menu_book_rounded,
    Icons.code_rounded,
    Icons.video_library_rounded,
    Icons.forum_rounded,
    Icons.people_rounded,
    Icons.school_rounded,
    Icons.backup,
  ];
  final _descriptions = [
    'Overview & Analytics',
    'Manage Courses & Assign Teachers',
    'Coding Challenges',
    'Video Content',
    'Forum Discussions',
    'All Students Management',
    'Teacher Management',
    'Backup and Restore Data',
  ];

  Stream<List<AdminNotification>> get _notificationsStream =>
      NotificationService.getAdminNotifications().map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => AdminNotification.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ),
            )
            .toList(),
      );

  @override
  Widget build(BuildContext context) {
    // Respect initial index when the page is first shown
    if (_selectedIndex == 0 && widget.initialIndex != 0) {
      _selectedIndex = widget.initialIndex;
    }
    if (!kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.computer, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available only on web platform',
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          if (isWide) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNavigation(),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo and Brand Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/CIS SEAL2.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CodeQuest',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.green[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FirebaseAuth.instance.currentUser?.displayName ??
                            'Admin User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Administrator',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation Menu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      'MAIN NAVIGATION',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    _labels.length,
                    (index) => _buildNavItem(index),
                  ),
                  const SizedBox(height: 24),
                  // Removed ACCOUNT section header
                  const SizedBox(height: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _icons[index],
            color: isSelected ? Colors.green[600] : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Text(
          _labels[index],
          style: TextStyle(
            color: isSelected ? Colors.green[700] : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          _descriptions[index],
          style: TextStyle(
            color: isSelected ? Colors.green[500] : Colors.grey[500],
            fontSize: 12,
          ),
        ),
        onTap: () {
          if (index == _labels.length - 1) {
            // Backup & Restore navigation
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const BackupRestorePage(),
              ),
            );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // _buildLogoutItem removed; logout available in header settings menu

  Widget _buildTopBar() {
    return StreamBuilder<List<AdminNotification>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;
        final currentUser = FirebaseAuth.instance.currentUser;
        final adminName = currentUser?.displayName ?? 'Admin User';
        final adminEmail = currentUser?.email ?? '';
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Page Title
              Text(
                _labels[_selectedIndex],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // User Menu
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => NotificationPanel(
                          notifications: notifications,
                          onMarkRead: (id) {
                            NotificationService.markNotificationAsRead(id);
                          },
                          onClose: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 4,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Settings menu: Admin Profile + Logout (professional)
                  PopupMenuButton<String>(
                    tooltip: 'Settings',
                    icon: Icon(Icons.settings_rounded,
                        size: 22, color: Colors.grey[700]),
                    splashRadius: 22,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 8),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.green[100],
                                  child: Icon(Icons.person,
                                      color: Colors.green[700], size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(adminName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      if (adminEmail.isNotEmpty)
                                        Text(adminEmail,
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: const [
                            Icon(Icons.account_circle_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Admin Profile'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 18, color: Colors.red[600]),
                            const SizedBox(width: 8),
                            Text('Logout',
                                style: TextStyle(color: Colors.red[700])),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'profile') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AdminProfilePage(),
                          ),
                        );
                      } else if (value == 'logout') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.logout,
                                    color: Colors.red[600], size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  'Confirm Logout',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            content: const Text(
                              'Are you sure you want to logout?',
                              style: TextStyle(fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.of(context)
                                      .pop(); // Close dialog first
                                  context
                                      .read<AuthBloc>()
                                      .add(SignOutRequested());
                                  if (context.mounted) {
                                    Navigator.pushReplacementNamed(
                                        context, AppRouter.login);
                                  }
                                },
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...List.generate(
                  _labels.length,
                  (index) => SizedBox(
                    width: 80, // Fixed width to prevent overflow
                    child: _buildBottomNavItem(index),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[index],
              color: isSelected ? Colors.green[600] : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              _labels[index],
              style: TextStyle(
                color: isSelected ? Colors.green[600] : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
