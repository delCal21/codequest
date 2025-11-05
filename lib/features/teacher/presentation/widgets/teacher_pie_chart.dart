import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TeacherPieChart extends StatelessWidget {
  final int courses;
  final int challenges;
  final int students;

  const TeacherPieChart({
    super.key,
    required this.courses,
    required this.challenges,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    final int total = courses + challenges + students;
    double pct(int v) => total == 0 ? 0 : (v / total * 100);
    return Container(
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
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                color: Colors.green[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: courses.toDouble(),
                    color: Colors.green[200]!,
                    title: '',
                    radius: 40,
                    titleStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                  PieChartSectionData(
                    value: challenges.toDouble(),
                    color: Colors.amber[200]!,
                    title: '',
                    radius: 40,
                    titleStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                  PieChartSectionData(
                    value: students.toDouble(),
                    color: Colors.blue[200]!,
                    title: '',
                    radius: 40,
                    titleStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ],
                sectionsSpace: 3,
                centerSpaceRadius: 60,
                centerSpaceColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Total in center overlay for readability
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 8,
            children: [
              _Legend(
                  label: 'Courses',
                  value: courses,
                  percent: pct(courses),
                  color: Colors.green),
              _Legend(
                  label: 'Challenges',
                  value: challenges,
                  percent: pct(challenges),
                  color: Colors.amber),
              _Legend(
                  label: 'Students',
                  value: students,
                  percent: pct(students),
                  color: Colors.blue),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final int value;
  final double percent;
  final MaterialColor color;
  const _Legend(
      {required this.label,
      required this.value,
      required this.percent,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color[600],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text('$label — $value (${percent.toStringAsFixed(0)}%)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            )),
      ],
    );
  }
}
