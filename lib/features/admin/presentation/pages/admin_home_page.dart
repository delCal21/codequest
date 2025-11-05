import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:codequest/features/teacher/presentation/widgets/teacher_student_report.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String _selectedUserFilter = 'Ongoing'; // 'Ongoing', 'Completed'

  @override
  void initState() {
    super.initState();
    // Migrate old enrollment records to ensure they have required fields
    _migrateEnrollmentRecords();
    // Debug enrollment data
    _debugEnrollmentData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Grid
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.blue),
                      ),
                    );
                  }
                  final users = userSnapshot.data!.docs;
                  final teachers =
                      users.where((doc) => doc['role'] == 'teacher').length;
                  final students =
                      users.where((doc) => doc['role'] == 'student').length;
                  final totalUsers = teachers + students;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('courses')
                        .snapshots(),
                    builder: (context, courseSnapshot) {
                      if (!courseSnapshot.hasData) {
                        return Container(
                          padding: const EdgeInsets.all(40),
                          child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.blue),
                          ),
                        );
                      }
                      final courses = courseSnapshot.data!.docs.length;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('challenges')
                            .snapshots(),
                        builder: (context, challengeSnapshot) {
                          if (!challengeSnapshot.hasData) {
                            return Container(
                              padding: const EdgeInsets.all(40),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.blue),
                              ),
                            );
                          }
                          // challenges count fetched but not used here

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('videos')
                                .snapshots(),
                            builder: (context, videoSnapshot) {
                              if (!videoSnapshot.hasData) {
                                return Container(
                                  padding: const EdgeInsets.all(40),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.blue),
                                  ),
                                );
                              }
                              // videos count fetched but not used here

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('enrollments')
                                    .snapshots(),
                                builder: (context, enrollmentSnapshot) {
                                  if (!enrollmentSnapshot.hasData) {
                                    return Container(
                                      padding: const EdgeInsets.all(40),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.blue),
                                      ),
                                    );
                                  }

                                  // enrollmentSnapshot fetched for downstream widgets; counts handled in graph section

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      GridView.count(
                                        crossAxisCount: 4,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        crossAxisSpacing: 24,
                                        mainAxisSpacing: 24,
                                        childAspectRatio: 2.5,
                                        children: [
                                          _StatCard(
                                            title: 'Total Users',
                                            value: totalUsers.toString(),
                                            icon: Icons.people,
                                            color: Colors.indigo[600]!,
                                            backgroundColor:
                                                Colors.indigo[200]!,
                                            subtitle: 'All app users',
                                          ),
                                          _StatCard(
                                            title: 'Teachers',
                                            value: teachers.toString(),
                                            icon: Icons.school,
                                            color: Colors.green[600]!,
                                            backgroundColor: Colors.green[200]!,
                                            subtitle: 'Active educators',
                                          ),
                                          _StatCard(
                                            title: 'Students',
                                            value: students.toString(),
                                            icon: Icons.person,
                                            color: Colors.blue[600]!,
                                            backgroundColor: Colors.blue[200]!,
                                            subtitle: 'Enrolled learners',
                                          ),
                                          _StatCard(
                                            title: 'Courses',
                                            value: courses.toString(),
                                            icon: Icons.menu_book,
                                            color: Colors.orange[600]!,
                                            backgroundColor:
                                                Colors.orange[200]!,
                                            subtitle: 'Available courses',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),

                                      // User Statistics Overview Graph
                                      _buildUserStatisticsGraph(
                                        totalUsers: totalUsers,
                                        students: students,
                                        teachers: teachers,
                                      ),
                                      const SizedBox(height: 24),

                                      // Enrollment trend and Challenges per Course (side-by-side)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              child:
                                                  _buildCourseEnrollmentGraph()),
                                          const SizedBox(width: 24),
                                          Expanded(
                                              child:
                                                  _buildChallengesPerCourseBarChart()),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      // Student Report (Teacher widget) scoped for Admin view
                                      _buildTeacherStudentReportForAdmin(),
                                      const SizedBox(height: 24),
                                    ],
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
              // Recent Activity removed
            ],
          ),
        ),
      ),
    );
  }

  // User Statistics Graph - Shows total app users and course enrollments
  Widget _buildUserStatisticsGraph({
    required int totalUsers,
    required int students,
    required int teachers,
  }) {
    return SizedBox(
      height: 400,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics, color: Colors.green[700], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'User Statistics Overview',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    // Filter buttons with accurate data
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('enrollments')
                          .snapshots(),
                      builder: (context, enrollmentsSnapshot) {
                        int ongoingCount = 0;
                        int completedCount = 0;

                        if (enrollmentsSnapshot.hasData) {
                          final enrollments = enrollmentsSnapshot.data!.docs;
                          for (final enrollment in enrollments) {
                            final data =
                                enrollment.data() as Map<String, dynamic>?;
                            final progress =
                                (data?['progress'] as num?)?.toDouble() ?? 0.0;
                            final completed = data?['completed'] == true;
                            final completedAt = data?['completedAt'];

                            if (completed ||
                                completedAt != null ||
                                progress >= 100.0) {
                              completedCount++;
                            } else {
                              ongoingCount++;
                            }
                          }
                        }

                        return Row(
                          children: [
                            _buildFilterButton(
                              'Ongoing',
                              ongoingCount,
                              Icons.trending_up,
                              _selectedUserFilter == 'Ongoing',
                              () => setState(
                                  () => _selectedUserFilter = 'Ongoing'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              'Completed',
                              completedCount,
                              Icons.check_circle,
                              _selectedUserFilter == 'Completed',
                              () => setState(
                                  () => _selectedUserFilter = 'Completed'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('courses')
                        .snapshots(),
                    builder: (context, coursesSnapshot) {
                      if (!coursesSnapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.purple));
                      }

                      final courses = coursesSnapshot.data!.docs;
                      final courseIds = courses.map((doc) => doc.id).toList();
                      final courseTitles = {
                        for (final doc in courses)
                          doc.id:
                              (doc.data() as Map<String, dynamic>?)?['title'] ??
                                  'Untitled Course'
                      };

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('enrollments')
                            .snapshots(),
                        builder: (context, enrollmentsSnapshot) {
                          if (!enrollmentsSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.purple));
                          }

                          final enrollments = enrollmentsSnapshot.data!.docs;

                          // Calculate enrollments per course
                          final Map<String, int> courseEnrollments = {};
                          for (final courseId in courseIds) {
                            courseEnrollments[courseId] = 0;
                          }

                          for (final enrollment in enrollments) {
                            final data =
                                enrollment.data() as Map<String, dynamic>?;
                            final courseId = data?['courseId'] as String?;

                            // Apply filter based on enrollment status
                            bool shouldInclude = true;
                            if (_selectedUserFilter == 'Ongoing') {
                              // Show only ongoing enrollments
                              final progress =
                                  (data?['progress'] as num?)?.toDouble() ??
                                      0.0;
                              final completed = data?['completed'] == true;
                              final completedAt = data?['completedAt'];
                              shouldInclude = !completed &&
                                  completedAt == null &&
                                  progress < 100.0;
                            } else if (_selectedUserFilter == 'Completed') {
                              // Show only completed enrollments
                              final progress =
                                  (data?['progress'] as num?)?.toDouble() ??
                                      0.0;
                              final completed = data?['completed'] == true;
                              final completedAt = data?['completedAt'];
                              shouldInclude = completed ||
                                  completedAt != null ||
                                  progress >= 100.0;
                            }

                            if (shouldInclude &&
                                courseId != null &&
                                courseEnrollments.containsKey(courseId)) {
                              courseEnrollments[courseId] =
                                  (courseEnrollments[courseId] ?? 0) + 1;
                            }
                          }

                          // Sort courses by enrollment count
                          final sortedCourses = courseEnrollments.entries
                              .toList()
                            ..sort((a, b) => b.value.compareTo(a.value));

                          // Take top 10 courses for better visualization
                          final topCourses = sortedCourses.take(10).toList();

                          if (topCourses.isEmpty) {
                            String emptyMessage =
                                _selectedUserFilter == 'Ongoing'
                                    ? 'No ongoing enrollments found'
                                    : 'No completed enrollments found';
                            return _emptyBox(emptyMessage);
                          }

                          // Prepare data for the chart
                          final courseNames = topCourses
                              .map((e) =>
                                  courseTitles[e.key] ?? 'Unknown Course')
                              .toList();
                          final enrollmentCounts = topCourses
                              .map((e) => e.value.toDouble())
                              .toList();

                          // Calculate max value for scaling
                          final maxEnrollments = enrollmentCounts.fold<double>(
                              0, (prev, val) => val > prev ? val : prev);
                          final maxY =
                              maxEnrollments > 0 ? maxEnrollments * 1.1 : 10.0;

                          return Column(
                            children: [
                              // Bar chart
                              Expanded(
                                child: BarChart(
                                  BarChartData(
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        tooltipBgColor: Colors.black87,
                                        getTooltipItem:
                                            (group, groupIndex, rod, rodIndex) {
                                          final courseName = (groupIndex >= 0 &&
                                                  groupIndex <
                                                      courseNames.length)
                                              ? courseNames[groupIndex]
                                              : 'Course';
                                          return BarTooltipItem(
                                            '$courseName\n${rod.toY.toInt()} students',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    alignment: BarChartAlignment.spaceAround,
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (value) =>
                                          FlLine(
                                        color: Colors.grey[200]!,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) =>
                                              Text(
                                            value.toInt().toString(),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 100,
                                          getTitlesWidget: (value, meta) {
                                            final i = value.toInt();
                                            if (i >= 0 &&
                                                i < courseNames.length) {
                                              final courseName = courseNames[i];
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 12, left: 4, right: 4),
                                                child: Container(
                                                  width: 110,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 4),
                                                  child: Text(
                                                    courseName.length > 25
                                                        ? '${courseName.substring(0, 25)}...'
                                                        : courseName,
                                                    maxLines: 2,
                                                    softWrap: true,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: Colors.grey[900],
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1.3,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    barGroups: enrollmentCounts
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final count = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: count,
                                            width: 16,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.green[400]!,
                                                Colors.green[600]!,
                                              ],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                            backDrawRodData:
                                                BackgroundBarChartRodData(
                                              show: true,
                                              toY: maxY,
                                              color: Colors.green[50]!,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    maxY: maxY,
                                    minY: 0,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedUserFilter == 'Ongoing'
                          ? 'Ongoing Enrollments per Course'
                          : 'Completed Enrollments per Course',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
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

  // Course Enrollment Graph
  Widget _buildCourseEnrollmentGraph() {
    return SizedBox(
      height: 360,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green[700], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Course Enrollment Trends',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('enrollments')
                        .orderBy('enrolledAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.blue));
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red[400], size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'Error loading enrollment data',
                                style: TextStyle(
                                    color: Colors.red[600], fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please try refreshing the page',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }

                      final enrollments = snapshot.data!.docs;

                      // Group enrollments by month for the last 5 months
                      final Map<String, int> monthlyEnrolledData = {};
                      final Map<String, int> monthlyCompletedData = {};
                      final now = DateTime.now();

                      // Initialize data for the last 5 months
                      for (int i = 4; i >= 0; i--) {
                        final date = DateTime(now.year, now.month - i, 1);
                        final key =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}';
                        monthlyEnrolledData[key] = 0;
                        monthlyCompletedData[key] = 0;
                      }

                      // Process enrollment data
                      for (final enrollment in enrollments) {
                        try {
                          final data =
                              enrollment.data() as Map<String, dynamic>?;
                          if (data == null) continue;

                          // Process enrollment date
                          final enrolledAt = data['enrolledAt'];
                          if (enrolledAt != null) {
                            DateTime? date;
                            if (enrolledAt is Timestamp) {
                              date = enrolledAt.toDate();
                            } else if (enrolledAt is String) {
                              try {
                                date = DateTime.parse(enrolledAt);
                              } catch (_) {
                                continue;
                              }
                            } else {
                              continue;
                            }

                            final key =
                                '${date.year}-${date.month.toString().padLeft(2, '0')}';
                            if (monthlyEnrolledData.containsKey(key)) {
                              monthlyEnrolledData[key] =
                                  (monthlyEnrolledData[key] ?? 0) + 1;
                            }
                          }

                          // Process completion data
                          final completed = data.containsKey('completed') &&
                              data['completed'] == true;
                          final completedAt = data['completedAt'];

                          if (completed) {
                            DateTime? date;

                            if (completedAt != null) {
                              // Use the actual completion date
                              if (completedAt is Timestamp) {
                                date = completedAt.toDate();
                              } else if (completedAt is String) {
                                try {
                                  date = DateTime.parse(completedAt);
                                } catch (_) {
                                  // If parsing fails, fall back to enrollment date
                                  final enrolledAt = data['enrolledAt'];
                                  if (enrolledAt is Timestamp) {
                                    date = enrolledAt.toDate();
                                  } else if (enrolledAt is String) {
                                    try {
                                      date = DateTime.parse(enrolledAt);
                                    } catch (_) {
                                      continue;
                                    }
                                  } else {
                                    continue;
                                  }
                                }
                              } else {
                                continue;
                              }
                            } else {
                              // If completedAt is null, use enrollment date as fallback
                              final enrolledAt = data['enrolledAt'];
                              if (enrolledAt is Timestamp) {
                                date = enrolledAt.toDate();
                              } else if (enrolledAt is String) {
                                try {
                                  date = DateTime.parse(enrolledAt);
                                } catch (_) {
                                  continue;
                                }
                              } else {
                                continue;
                              }
                            }

                            final key =
                                '${date.year}-${date.month.toString().padLeft(2, '0')}';
                            if (monthlyCompletedData.containsKey(key)) {
                              monthlyCompletedData[key] =
                                  (monthlyCompletedData[key] ?? 0) + 1;
                            }
                          }
                        } catch (e) {
                          // Handle any errors gracefully and continue processing other enrollments
                          print('Error processing enrollment data: $e');
                          continue;
                        }
                      }

                      final sortedKeys = monthlyEnrolledData.keys.toList()
                        ..sort();
                      final enrolledValues = sortedKeys
                          .map((key) => monthlyEnrolledData[key]!.toDouble())
                          .toList();
                      final completedValues = sortedKeys
                          .map((key) => monthlyCompletedData[key]!.toDouble())
                          .toList();

                      // Calculate max value with some padding
                      final double maxYValue = [
                        ...enrolledValues,
                        ...completedValues,
                      ].fold<double>(0, (prev, v) => v > prev ? v : prev);

                      // Add some padding to the max value for better visualization
                      final double paddedMaxY =
                          maxYValue > 0 ? maxYValue * 1.1 : 10.0;

                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey[200]!,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() < sortedKeys.length) {
                                    final key = sortedKeys[value.toInt()];
                                    final parts = key.split('-');
                                    final month = int.parse(parts[1]);
                                    final monthNames = [
                                      'Jan',
                                      'Feb',
                                      'Mar',
                                      'Apr',
                                      'May',
                                      'Jun',
                                      'Jul',
                                      'Aug',
                                      'Sep',
                                      'Oct',
                                      'Nov',
                                      'Dec'
                                    ];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        monthNames[month - 1],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: enrolledValues
                                  .asMap()
                                  .entries
                                  .map((entry) =>
                                      FlSpot(entry.key.toDouble(), entry.value))
                                  .toList(),
                              isCurved: true,
                              color: Colors.blue[600]!,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blue[100]!.withOpacity(0.25),
                              ),
                            ),
                            LineChartBarData(
                              spots: completedValues
                                  .asMap()
                                  .entries
                                  .map((entry) =>
                                      FlSpot(entry.key.toDouble(), entry.value))
                                  .toList(),
                              isCurved: true,
                              color: Colors.green[600]!,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green[100]!.withOpacity(0.2),
                              ),
                            ),
                          ],
                          minX: 0,
                          maxX: (sortedKeys.length - 1).toDouble(),
                          minY: 0,
                          maxY: paddedMaxY,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Enrollments',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.green[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Completions',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
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

  // Reuse TeacherStudentReport inside Admin dashboard context
  Widget _buildTeacherStudentReportForAdmin() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('courses').snapshots(),
      builder: (context, coursesSnapshot) {
        if (!coursesSnapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final courseDocs = coursesSnapshot.data!.docs;
        final Set<String> allCourseIds = {
          for (final d in courseDocs) d.id,
        };
        final Map<String, String> courseIdToTitle = {
          for (final d in courseDocs)
            d.id:
                (((d.data() as Map<String, dynamic>?)?['title']) as String?) ??
                    'Untitled'
        };

        return TeacherStudentReport(
          teacherCourseIds: allCourseIds,
          courseIdToTitle: courseIdToTitle,
          hideCategory: true,
          useLifetimeCompleted: true,
          hideStatus: true,
          hideEmail: true,
          disableClickableNames: true,
        );
      },
    );
  }

  // Challenges per Course - Bar Chart
  Widget _buildChallengesPerCourseBarChart() {
    return SizedBox(
      height: 360,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        color: Colors.green[700], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Challenges per Course',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('courses')
                        .snapshots(),
                    builder: (context, coursesSnapshot) {
                      if (!coursesSnapshot.hasData) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.green));
                      }

                      if (coursesSnapshot.hasError) {
                        return _errorBox('Error loading courses');
                      }

                      final courseDocs = coursesSnapshot.data!.docs;
                      if (courseDocs.isEmpty) {
                        return _emptyBox('No courses found');
                      }

                      final Map<String, String> courseIdToTitle = {
                        for (final d in courseDocs)
                          d.id: ((d.data() as Map<String, dynamic>?)?['title']
                                  as String?) ??
                              'Untitled'
                      };

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('challenges')
                            .snapshots(),
                        builder: (context, challengesSnapshot) {
                          if (!challengesSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.green));
                          }

                          if (challengesSnapshot.hasError) {
                            return _errorBox('Error loading challenges');
                          }

                          final challengeDocs = challengesSnapshot.data!.docs;

                          final Map<String, int> counts = {
                            for (final id in courseIdToTitle.keys) id: 0
                          };
                          for (final c in challengeDocs) {
                            final data = c.data() as Map<String, dynamic>?;
                            final courseId = data?['courseId'] as String?;
                            if (courseId != null &&
                                counts.containsKey(courseId)) {
                              counts[courseId] = (counts[courseId] ?? 0) + 1;
                            }
                          }

                          final entries = counts.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));

                          final topEntries = entries.length > 8
                              ? entries.sublist(0, 8)
                              : entries;

                          final barGroups = <BarChartGroupData>[];
                          int index = 0;
                          int maxCount = 0;
                          for (final e in topEntries) {
                            final count = e.value;
                            if (count > maxCount) maxCount = count;
                            barGroups.add(
                              BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: count.toDouble(),
                                    width: 14,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green[400]!,
                                        Colors.green[700]!
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: (maxCount > 0 ? (maxCount * 1.2) : 5)
                                          .toDouble(),
                                      color: Colors.green[50],
                                    ),
                                  ),
                                ],
                              ),
                            );
                            index++;
                          }

                          final labels = topEntries
                              .map((e) => courseIdToTitle[e.key] ?? 'Course')
                              .toList();
                          final double maxY =
                              (maxCount > 0 ? (maxCount * 1.2) : 5).toDouble();

                          return BarChart(
                            BarChartData(
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  tooltipBgColor: Colors.black87,
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                    final label = (groupIndex >= 0 &&
                                            groupIndex < labels.length)
                                        ? labels[groupIndex]
                                        : 'Course';
                                    return BarTooltipItem(
                                      '$label\n${rod.toY.toInt()} challenges',
                                      const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    );
                                  },
                                ),
                              ),
                              alignment: BarChartAlignment.spaceAround,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey[200]!,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 36,
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 100,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i >= 0 && i < labels.length) {
                                        final label = labels[i];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              top: 12, left: 4, right: 4),
                                          child: Container(
                                            width: 110,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 4),
                                            child: Text(
                                              label.length > 25
                                                  ? '${label.substring(0, 25)}...'
                                                  : label,
                                              maxLines: 2,
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.blue[900],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              barGroups: barGroups,
                              maxY: maxY,
                              minY: 0,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: Colors.green[700], shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Total challenges per course',
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child:
          Text(message, style: TextStyle(color: Colors.red[700], fontSize: 14)),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(message,
          style: TextStyle(color: Colors.grey[700], fontSize: 14)),
    );
  }

  // Student Reports section removed as requested

  // Helper method to migrate old enrollment records
  Future<void> _migrateEnrollmentRecords() async {
    try {
      final enrollments =
          await FirebaseFirestore.instance.collection('enrollments').get();

      final batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (final doc in enrollments.docs) {
        final data = doc.data();
        // If the document doesn't have a 'completed' field, add it
        if (!data.containsKey('completed')) {
          batch.update(doc.reference, {'completed': false});
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('Migrated $updateCount enrollment records');
      }
    } catch (e) {
      print('Error migrating enrollment records: $e');
    }
  }

  // Debug method to inspect enrollment data
  Future<void> _debugEnrollmentData() async {
    try {
      final enrollments =
          await FirebaseFirestore.instance.collection('enrollments').get();

      print('=== ENROLLMENT DATA DEBUG ===');
      print('Total enrollments: ${enrollments.docs.length}');

      int completedCount = 0;
      int withCompletedAt = 0;

      for (final doc in enrollments.docs) {
        final data = doc.data();
        if (data.containsKey('completed') && data['completed'] == true) {
          completedCount++;
          if (data.containsKey('completedAt')) {
            withCompletedAt++;
            print('Completed enrollment: ${doc.id}');
            print('  - completedAt: ${data['completedAt']}');
            print('  - enrolledAt: ${data['enrolledAt']}');
          }
        }
      }

      print('Completed enrollments: $completedCount');
      print('With completedAt field: $withCompletedAt');
      print('=============================');
    } catch (e) {
      print('Error debugging enrollment data: $e');
    }
  }

  // Build interactive filter button
  Widget _buildFilterButton(
    String label,
    int count,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[600] : Colors.green[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green[600]! : Colors.green[100]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.green[700],
            ),
            const SizedBox(width: 6),
            Text(
              '$label: $count',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.green[800],
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.black.withOpacity(0.75),
                  size: 18,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.75),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Unused legacy widget, remove to satisfy lints
// Removed unused _EnrollmentStatCard (previous legacy widget)

// Unused legacy widget, remove to satisfy lints
// Removed unused _CategoryCard (previous legacy widget)
