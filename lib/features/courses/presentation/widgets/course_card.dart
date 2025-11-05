import 'package:flutter/material.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback? onTap;
  final bool isEnrolled;
  final bool isCompleted;
  final VoidCallback? onEnroll;
  final VoidCallback? onView;
  final VoidCallback? onUnenroll;
  final bool showViewButton;
  final bool showUnenrollButton;
  final bool showDownloadButton;
  final double? progressPercent; // 0.0 to 1.0, optional

  const CourseCard({
    Key? key,
    required this.course,
    this.onTap,
    this.isEnrolled = false,
    this.isCompleted = false,
    this.onEnroll,
    this.onView,
    this.onUnenroll,
    this.showViewButton = false,
    this.showUnenrollButton = false,
    this.showDownloadButton = false,
    this.progressPercent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine if we should show the Enroll button
    final showEnrollButton = onEnroll != null && !isEnrolled && !isCompleted;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course icon or thumbnail
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green[50],
                  child: Icon(
                    Icons.menu_book,
                    color: Colors.green[700],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<dynamic>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(course.teacherId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text(
                              'By: ...',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            );
                          }
                          final data =
                              snapshot.data?.data() as Map<String, dynamic>?;
                          final fullName = data?['fullName'] ?? 'Teacher';
                          return Text(
                            'By $fullName',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                      if (course.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            course.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green[100]
                        : isEnrolled
                            ? Colors.blue[100]
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted
                        ? 'Completed'
                        : isEnrolled
                            ? 'Enrolled'
                            : 'Available',
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.green[800]
                          : isEnrolled
                              ? Colors.blue[800]
                              : Colors.grey[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            // Always show progress bar
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (progressPercent ?? 0.0).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              color: Colors.green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress: ${((progressPercent ?? 0.0) * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showEnrollButton)
                    _ResponsiveEnrollButton(onEnroll: onEnroll!),
                  if (showViewButton && onView != null)
                    OutlinedButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
                    ),
                  if (showUnenrollButton &&
                      onUnenroll != null &&
                      !isCompleted) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onUnenroll,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Unenroll',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                  if (showDownloadButton && course.files.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ...course.files.map((file) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(file['url']);
                              if (await canLaunchUrl(url)) {
                                final launched = await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                                if (!launched && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not open file'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not open file'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.download),
                            label: Text(file['name'] ?? 'Download'),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveEnrollButton extends StatefulWidget {
  final VoidCallback onEnroll;
  const _ResponsiveEnrollButton({required this.onEnroll});

  @override
  State<_ResponsiveEnrollButton> createState() =>
      _ResponsiveEnrollButtonState();
}

class _ResponsiveEnrollButtonState extends State<_ResponsiveEnrollButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton.icon(
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                widget.onEnroll();
                if (mounted) setState(() => _loading = false);
              },
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.add),
        label: Text(_loading ? 'Enrolling...' : 'Enroll'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
    );
  }
}
