import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';
import 'package:codequest/features/teacher/presentation/pages/cheating_logs_page.dart';

class TeacherStudentsPage extends StatefulWidget {
  const TeacherStudentsPage({super.key});

  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  String _searchQuery = '';
  final CollaboratorRepository _collaboratorRepository =
      CollaboratorRepository(FirebaseFirestore.instance);
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
  }

  Widget _buildStudentsTable(List<_StudentRowData> filteredRows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = filteredRows.length;
        final maxPage = total == 0 ? 0 : ((total - 1) ~/ _pageSize);
        final currentPage = _currentPage > maxPage ? maxPage : _currentPage;
        final startIndex = currentPage * _pageSize;
        final endIndex = (startIndex + _pageSize).clamp(0, total);
        final visibleRows = filteredRows.sublist(startIndex, endIndex);

        Widget buildPager() {
          final totalPages = ((total / _pageSize).ceil()).clamp(1, 999);
          final pageLabel = 'Page ${currentPage + 1} of $totalPages';
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: currentPage > 0
                    ? () => setState(() => _currentPage -= 1)
                    : null,
                child: const Text('Previous'),
              ),
              const SizedBox(width: 16),
              Text(pageLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: currentPage < maxPage
                    ? () => setState(() => _currentPage += 1)
                    : null,
                child: const Text('Next'),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 12,
                    dataRowMinHeight: 38,
                    dataRowMaxHeight: 44,
                    headingRowHeight: 44,
                    horizontalMargin: 12,
                    headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                        (states) => Colors.green[50]),
                    headingTextStyle: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'NotoSans',
                    ),
                    columns: const [
                      DataColumn(
                          label: Text('Student Name',
                              style: TextStyle(fontSize: 13))),
                      DataColumn(
                          label:
                              Text('Course', style: TextStyle(fontSize: 13))),
                      DataColumn(
                          label: Text('Enrollment Date',
                              style: TextStyle(fontSize: 13))),
                      DataColumn(
                          label:
                              Text('Progress', style: TextStyle(fontSize: 13))),
                      DataColumn(
                          label:
                              Text('Status', style: TextStyle(fontSize: 13))),
                    ],
                    rows: visibleRows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      return DataRow(
                        color:
                            MaterialStateProperty.resolveWith<Color?>((states) {
                          return index % 2 == 0
                              ? Colors.white
                              : const Color.fromARGB(255, 255, 255, 255);
                        }),
                        cells: [
                          DataCell(SizedBox(
                            width: 140,
                            child: Text(row.studentName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          )),
                          DataCell(SizedBox(
                            width: 140,
                            child: Text(row.courseTitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          )),
                          DataCell(Text(row.enrolledAt ?? '-',
                              style: const TextStyle(fontSize: 13))),
                          DataCell(Text(
                              row.completed ? '100%' : '${row.progress}%',
                              style: const TextStyle(fontSize: 13))),
                          DataCell(
                            row.completed
                                ? const Text('Completed',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13))
                                : const Text('In Progress',
                                    style: TextStyle(
                                        color: Colors.green, fontSize: 13)),
                          ),
                          // Remarks Summary and Actions removed as requested
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 16),
              child:
                  Align(alignment: Alignment.centerRight, child: buildPager()),
            ),
          ],
        );
      },
    );
  }

  Future<Set<String>> _getAllTeacherCourseIds(String teacherId) async {
    // Get courses where teacher is the main teacher
    final ownedCoursesSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: teacherId)
        .get();
    final ownedCourseIds =
        ownedCoursesSnapshot.docs.map((doc) => doc.id).toSet();
    // Get courses where teacher is a collaborator
    final collaboratorCourseIds =
        await _collaboratorRepository.getCollaboratorCourses(teacherId);
    return {...ownedCourseIds, ...collaboratorCourseIds};
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in.'));
    }
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: const Text(''),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CheatingLogsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.security, size: 18),
              label: const Text(
                'Cheating Logs',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
                shadowColor: Colors.red.shade300,
              ),
            ),
          ),
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by student name',
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
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
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
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                        _currentPage = 0;
                      });
                    },
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<Set<String>>(
                future: _getAllTeacherCourseIds(currentUser.uid),
                builder: (context, courseIdsSnapshot) {
                  if (courseIdsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!courseIdsSnapshot.hasData ||
                      courseIdsSnapshot.data!.isEmpty) {
                    return Center(child: Text('No courses found.'));
                  }
                  final allCourseIds = courseIdsSnapshot.data!;
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('enrollments')
                        .where('courseId', whereIn: allCourseIds.toList())
                        .snapshots(),
                    builder: (context, enrollmentSnapshot) {
                      if (enrollmentSnapshot.hasError) {
                        return Center(child: Text('Error loading enrollments'));
                      }
                      if (enrollmentSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!enrollmentSnapshot.hasData ||
                          enrollmentSnapshot.data!.docs.isEmpty) {
                        return Center(child: Text('No enrolled students.'));
                      }
                      final enrollments = enrollmentSnapshot.data!.docs;
                      return FutureBuilder<List<_StudentRowData>>(
                        future: _fetchStudentRows(enrollments),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final rows = snapshot.data!;
                          final filteredRows = _searchQuery.isEmpty
                              ? rows
                              : rows
                                  .where((row) => row.studentName
                                      .toLowerCase()
                                      .contains(_searchQuery))
                                  .toList();
                          if (filteredRows.isEmpty) {
                            return const Center(
                                child: Text('No students match your search.'));
                          }
                          return _buildStudentsTable(filteredRows);
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

  Future<List<_StudentRowData>> _fetchStudentRows(
      List<QueryDocumentSnapshot> enrollments) async {
    List<_StudentRowData> rows = [];
    for (final enrollment in enrollments) {
      final studentId = enrollment['studentId'];
      final courseId = enrollment['courseId'];
      final enrolledAtRaw = enrollment['enrolledAt'];
      DateTime? enrolledAt;
      if (enrolledAtRaw is Timestamp) {
        enrolledAt = enrolledAtRaw.toDate();
      } else if (enrolledAtRaw is String) {
        enrolledAt = DateTime.tryParse(enrolledAtRaw);
      } else if (enrolledAtRaw is DateTime) {
        enrolledAt = enrolledAtRaw;
      }
      final completed = enrollment['completed'] ?? false;
      String studentName = 'Unknown Student';
      String courseTitle = 'Unknown Course';
      int progress = 0;
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        if (userSnap.exists) {
          studentName = (userSnap.data() as Map<String, dynamic>)['fullName'] ??
              'Unknown Student';
        }
        final courseSnap = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();
        if (courseSnap.exists) {
          courseTitle = (courseSnap.data() as Map<String, dynamic>)['title'] ??
              'Unknown Course';
        }
        final challengesQuery = await FirebaseFirestore.instance
            .collection('challenges')
            .where('courseId', isEqualTo: courseId)
            .get();
        final totalChallenges = challengesQuery.docs.length;
        int completedChallenges = 0;
        if (totalChallenges > 0) {
          final progressDoc = await FirebaseFirestore.instance
              .collection('progress')
              .doc(studentId + '_' + courseId)
              .get();
          if (progressDoc.exists && progressDoc.data() != null) {
            final data = progressDoc.data()!;
            final completedList = data['completedChallenges'];
            if (completedList is List) {
              completedChallenges = completedList.length;
            }
          }
          progress = ((completedChallenges / totalChallenges) * 100)
              .round()
              .clamp(0, 100);
        }
      } catch (_) {}
      rows.add(_StudentRowData(
        studentName: studentName,
        courseTitle: courseTitle,
        enrolledAt:
            enrolledAt != null ? enrolledAt.toString().substring(0, 10) : '-',
        progress: progress,
        completed: progress == 100,
        studentId: studentId,
        courseId: courseId,
      ));
    }
    return rows;
  }
}

class _StudentRowData {
  final String studentName;
  final String courseTitle;
  final String? enrolledAt;
  final int progress;
  final bool completed;
  final String studentId;
  final String courseId;
  _StudentRowData({
    required this.studentName,
    required this.courseTitle,
    required this.enrolledAt,
    required this.progress,
    required this.completed,
    required this.studentId,
    required this.courseId,
  });
}

class StudentChallengeProgressDialog extends StatelessWidget {
  final String studentName;
  final String courseTitle;
  final String studentId;
  final String courseId;
  const StudentChallengeProgressDialog({
    required this.studentName,
    required this.courseTitle,
    required this.studentId,
    required this.courseId,
    Key? key,
  }) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchChallenges() async {
    final query = await FirebaseFirestore.instance
        .collection('challenges')
        .where('courseId', isEqualTo: courseId)
        .get();
    return query.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
  }

  Future<List<String>> _fetchCompletedChallenges() async {
    final doc = await FirebaseFirestore.instance
        .collection('progress')
        .doc(studentId + '_' + courseId)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final completed = data['completedChallenges'];
      if (completed is List) {
        return List<String>.from(completed);
      }
    }
    return [];
  }

  Future<String?> _fetchRemark(String challengeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('challenge_remarks')
        .doc(studentId + '_' + challengeId)
        .get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['remark'] as String?;
    }
    return null;
  }

  Future<void> _saveRemark(String challengeId, String remark) async {
    await FirebaseFirestore.instance
        .collection('challenge_remarks')
        .doc(studentId + '_' + challengeId)
        .set({
      'studentId': studentId,
      'challengeId': challengeId,
      'remark': remark,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Challenges for $studentName'),
      content: SizedBox(
        width: 400,
        child: FutureBuilder(
          future: Future.wait([
            _fetchChallenges(),
            _fetchCompletedChallenges(),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final challenges = snapshot.data![0] as List<Map<String, dynamic>>;
            final completed = snapshot.data![1] as List<String>;
            if (challenges.isEmpty) {
              return const Text('No challenges found for this course.');
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: challenges.length,
              itemBuilder: (context, index) {
                final challenge = challenges[index];
                final isDone = completed.contains(challenge['id']);
                return FutureBuilder<String?>(
                  future: _fetchRemark(challenge['id']),
                  builder: (context, remarkSnapshot) {
                    final TextEditingController _remarkController =
                        TextEditingController(text: remarkSnapshot.data ?? '');
                    return ListTile(
                      title: Text(challenge['title'] ?? 'Untitled'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(challenge['description'] ?? ''),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              isDone
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : const Icon(Icons.radio_button_unchecked,
                                      color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(isDone ? 'Passed' : 'Failed',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDone ? Colors.green : Colors.red)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _remarkController,
                            decoration: const InputDecoration(
                              labelText: 'Remarks',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            minLines: 1,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Save Remark',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              await _saveRemark(challenge['id'],
                                  _remarkController.text.trim());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Remark saved!'),
                                    backgroundColor: Colors.green),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
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
    );
  }
}
