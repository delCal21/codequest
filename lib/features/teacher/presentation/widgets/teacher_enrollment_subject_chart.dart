import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class TeacherEnrollmentSubjectChart extends StatelessWidget {
  final Set<String> teacherCourseIds;
  final Map<String, String> courseIdToTitle;

  const TeacherEnrollmentSubjectChart({
    super.key,
    required this.teacherCourseIds,
    required this.courseIdToTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      constraints: const BoxConstraints(minHeight: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: Colors.indigo[600], size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enrollments by Subject (Ongoing and Completed)',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('enrollments')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 220,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }

              final enrollments = snapshot.data!.docs
                  .map((d) => d.data() as Map<String, dynamic>)
                  .where((e) =>
                      e['courseId'] is String &&
                      teacherCourseIds.contains(e['courseId']))
                  .toList();

              if (enrollments.isEmpty) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: Text('No enrollments yet')),
                );
              }

              final Map<String, int> ongoingByCourse = {};
              final Map<String, int> completedByCourse = {};

              for (final e in enrollments) {
                final String courseId = e['courseId'];
                final bool completed = e['completed'] == true;
                if (completed) {
                  completedByCourse[courseId] =
                      (completedByCourse[courseId] ?? 0) + 1;
                } else {
                  ongoingByCourse[courseId] =
                      (ongoingByCourse[courseId] ?? 0) + 1;
                }
              }

              // Build a consistent list of courseIds present in data
              final List<String> courseIds = {
                ...ongoingByCourse.keys,
                ...completedByCourse.keys,
              }.toList()
                ..sort((a, b) => (courseIdToTitle[a] ?? a)
                    .compareTo(courseIdToTitle[b] ?? b));

              // Limit bars for readability (top 8 by total)
              courseIds.sort((a, b) {
                final at =
                    (ongoingByCourse[a] ?? 0) + (completedByCourse[a] ?? 0);
                final bt =
                    (ongoingByCourse[b] ?? 0) + (completedByCourse[b] ?? 0);
                return bt.compareTo(at);
              });
              final limitedCourseIds = courseIds.take(8).toList();

              final barGroups = <BarChartGroupData>[];
              for (int i = 0; i < limitedCourseIds.length; i++) {
                final id = limitedCourseIds[i];
                final ongoing = (ongoingByCourse[id] ?? 0).toDouble();
                final completed = (completedByCourse[id] ?? 0).toDouble();

                barGroups.add(
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: ongoing + completed,
                        rodStackItems: [
                          BarChartRodStackItem(0, ongoing, Colors.orange),
                          BarChartRodStackItem(
                              ongoing, ongoing + completed, Colors.green),
                        ],
                        borderRadius: BorderRadius.circular(4),
                        width: 20,
                      ),
                    ],
                  ),
                );
              }

              final double chartWidth =
                  math.max(700, limitedCourseIds.length * 160).toDouble();
              return SizedBox(
                height: 240,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: BarChart(
                      BarChartData(
                        barGroups: barGroups,
                        gridData:
                            FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: true, reservedSize: 32),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 72,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= limitedCourseIds.length) {
                                  return const SizedBox.shrink();
                                }
                                final title =
                                    courseIdToTitle[limitedCourseIds[idx]] ??
                                        limitedCourseIds[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontSize: 11),
                                    softWrap: true,
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        barTouchData: BarTouchData(enabled: true),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Legend(color: Colors.orangeAccent, label: 'Ongoing'),
              SizedBox(width: 16),
              _Legend(color: Colors.greenAccent, label: 'Completed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}
