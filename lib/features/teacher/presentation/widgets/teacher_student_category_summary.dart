import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherStudentCategorySummary extends StatelessWidget {
  final Set<String> teacherCourseIds;

  const TeacherStudentCategorySummary(
      {super.key, required this.teacherCourseIds});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, color: Colors.indigo[600], size: 22),
              const SizedBox(width: 8),
              const Text(
                'Student Categories',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  height: 120,
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
                  height: 120,
                  child: Center(child: Text('No students yet')),
                );
              }

              int total = enrollments.length;
              int completed =
                  enrollments.where((e) => e['completed'] == true).length;
              int ongoing = total - completed;

              // Simple categorization inspired by admin page
              int high = 0;
              int average = 0;
              int low = 0;
              int inactive = 0;

              // Group by studentId to compute per-student stats
              final Map<String, List<Map<String, dynamic>>> byStudent = {};
              for (final e in enrollments) {
                final sid = e['studentId'];
                if (sid is! String) continue;
                byStudent.putIfAbsent(sid, () => []).add(e);
              }

              byStudent.forEach((_, list) {
                final int t = list.length;
                final int c = list.where((e) => e['completed'] == true).length;
                final int o = t - c;
                if (t == 0) {
                  inactive++; // safety
                } else if (c > 0 && c / t > 0.7) {
                  high++;
                } else if (c > 0 && c / t > 0.4) {
                  average++;
                } else if (o > 0) {
                  low++;
                } else {
                  inactive++;
                }
              });

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _chip('Total', total, Colors.blueGrey.shade100),
                  _chip('Ongoing', ongoing, Colors.orange.shade100),
                  _chip('Completed', completed, Colors.green.shade100),
                  _chip('High Performers', high, Colors.green.shade200),
                  _chip('Average Performers', average, Colors.amber.shade200),
                  _chip('Low Performers', low, Colors.red.shade100),
                  _chip('Inactive Students', inactive, Colors.grey.shade200),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('$value'),
          ),
        ],
      ),
    );
  }
}
