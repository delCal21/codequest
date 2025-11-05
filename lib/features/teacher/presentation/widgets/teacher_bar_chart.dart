import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TeacherBarChart extends StatelessWidget {
  final int courses;
  final int challenges;
  final int students;

  const TeacherBarChart({
    super.key,
    required this.courses,
    required this.challenges,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: Colors.blue[600],
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
            height: 158,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: [
                      courses.toDouble(),
                      challenges.toDouble(),
                      students.toDouble()
                    ].reduce((a, b) => a > b ? a : b) +
                    5,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
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
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return Text(
                              'Courses',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          case 1:
                            return Text(
                              'Challenges',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          case 2:
                            return Text(
                              'Students',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                      toY: courses.toDouble(),
                      color: Colors.green[600],
                      width: 24,
                      borderRadius: BorderRadius.zero,
                    )
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: challenges.toDouble(),
                      color: Colors.amber[600],
                      width: 24,
                      borderRadius: BorderRadius.zero,
                    )
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(
                      toY: students.toDouble(),
                      color: Colors.blue[600],
                      width: 24,
                      borderRadius: BorderRadius.zero,
                    )
                  ]),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 1,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
