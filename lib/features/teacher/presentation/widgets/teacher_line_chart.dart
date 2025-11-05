import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TeacherLineChart extends StatelessWidget {
  final int courses;
  final int challenges;
  final int students;

  const TeacherLineChart({
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
                Icons.show_chart_rounded,
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
            height: 200,
            child: LineChart(
              LineChartData(
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
                            return const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Courses',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          case 1:
                            return const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Challenges',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          case 2:
                            return const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Students',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Courses line segment
                  LineChartBarData(
                    spots: [
                      FlSpot(0 - 0.2, courses.toDouble()),
                      FlSpot(0 + 0.2, courses.toDouble()),
                    ],
                    isCurved: false,
                    color: Colors.green[600],
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: Colors.green[600]!,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Challenges line segment
                  LineChartBarData(
                    spots: [
                      FlSpot(1 - 0.2, challenges.toDouble()),
                      FlSpot(1 + 0.2, challenges.toDouble()),
                    ],
                    isCurved: false,
                    color: Colors.amber[600],
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: Colors.amber[600]!,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Students line segment
                  LineChartBarData(
                    spots: [
                      FlSpot(2 - 0.2, students.toDouble()),
                      FlSpot(2 + 0.2, students.toDouble()),
                    ],
                    isCurved: false,
                    color: Colors.blue[600],
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: Colors.blue[600]!,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                minX: 0,
                maxX: 2,
                minY: 0,
                maxY: [
                      courses.toDouble(),
                      challenges.toDouble(),
                      students.toDouble()
                    ].reduce((a, b) => a > b ? a : b) +
                    5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: Colors.green[600]!,
                label: 'Courses',
                value: courses.toString(),
              ),
              const SizedBox(height: 8),
              _LegendItem(
                color: Colors.amber[600]!,
                label: 'Challenges',
                value: challenges.toString(),
              ),
              const SizedBox(height: 8),
              _LegendItem(
                color: Colors.blue[600]!,
                label: 'Students',
                value: students.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
