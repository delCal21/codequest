import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/services/notification_service.dart';
import 'package:codequest/config/routes.dart';

class TeacherNotificationPanel extends StatefulWidget {
  final VoidCallback onClose;
  const TeacherNotificationPanel({Key? key, required this.onClose})
      : super(key: key);

  @override
  State<TeacherNotificationPanel> createState() =>
      _TeacherNotificationPanelState();
}

class _TeacherNotificationPanelState extends State<TeacherNotificationPanel> {
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  StreamBuilder<QuerySnapshot>(
                    stream: NotificationService.getTeacherNotifications(
                        currentUser.uid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final docs = snapshot.data?.docs ?? [];
                      final hasReadNotifications = docs.any((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['read'] == true;
                      });

                      if (!hasReadNotifications) return const SizedBox.shrink();

                      return _isClearing
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.delete_sweep, size: 16),
                                label: const Text(
                                  'Clear Read',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text(
                                          'Clear Read Notifications'),
                                      content: const Text(
                                          'Are you sure you want to delete all read notifications? This cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Clear'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    setState(() => _isClearing = true);
                                    try {
                                      await NotificationService
                                          .clearReadTeacherNotifications(
                                              currentUser.uid);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Read notifications cleared.')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Failed to clear: $e')),
                                        );
                                      }
                                    } finally {
                                      if (mounted)
                                        setState(() => _isClearing = false);
                                    }
                                  }
                                },
                              ),
                            );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: widget.onClose,
                      tooltip: 'Close',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: NotificationService.getTeacherNotifications(
                    currentUser.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error.toString()}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_off,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text('No notifications',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: docs.take(5).length, // Show only first 5
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final n = docs[i];
                            final data = n.data() as Map<String, dynamic>;
                            final isRead = data['read'] ?? false;
                            final type = data['type'] ?? '';
                            final timestamp = data['timestamp'] as Timestamp?;
                            final actionRequired =
                                data['actionRequired'] ?? false;

                            String title = _getNotificationTitle(type);
                            String message =
                                _getNotificationMessage(type, data);

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    isRead ? Colors.grey[50] : Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRead
                                      ? Colors.grey[200]!
                                      : Colors.blue[200]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getNotificationColor(
                                            type, actionRequired)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(type),
                                    color: _getNotificationColor(
                                        type, actionRequired),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                    fontSize: 15,
                                    color: isRead
                                        ? Colors.grey[700]
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isRead
                                            ? Colors.grey[600]
                                            : Colors.grey[700],
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (actionRequired) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.orange[400]!,
                                              Colors.orange[600]!
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.orange
                                                  .withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'Action Required',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (timestamp != null)
                                      Text(
                                        _formatTime(timestamp.toDate()),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (!isRead) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[600],
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.blue.withOpacity(0.4),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () async {
                                  // Mark as read
                                  if (!isRead) {
                                    await NotificationService
                                        .markTeacherNotificationAsRead(n.id);
                                  }
                                  // Show full content dialog
                                  await showDialog(
                                    context: context,
                                    builder: (ctx) => Dialog(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 12,
                                      child: Container(
                                        width: 500,
                                        constraints: const BoxConstraints(
                                            maxHeight: 600),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    _getNotificationColor(
                                                        type, actionRequired),
                                                    _getNotificationColor(type,
                                                            actionRequired)
                                                        .withOpacity(0.8),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(20),
                                                  topRight: Radius.circular(20),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Icon(
                                                      _getNotificationIcon(
                                                          type),
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      title.isNotEmpty
                                                          ? title
                                                          : 'Notification',
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        Navigator.of(ctx).pop(),
                                                    icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.white),
                                                    tooltip: 'Close',
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Flexible(
                                              child: SingleChildScrollView(
                                                padding:
                                                    const EdgeInsets.all(24),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              16),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[50],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: Colors
                                                                .grey[200]!),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            color: Colors
                                                                .grey[600],
                                                            size: 16,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                            _formatTime(timestamp
                                                                    ?.toDate() ??
                                                                DateTime.now()),
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    if (message.isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.blue[50],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .blue[200]!),
                                                        ),
                                                        child: Text(
                                                          message,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 15,
                                                            height: 1.4,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                        ),
                                                      ),
                                                    if (data.isNotEmpty) ...[
                                                      const SizedBox(
                                                          height: 20),
                                                      Text(
                                                        'Details',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.grey[800],
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[50],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .grey[200]!),
                                                        ),
                                                        child: Column(
                                                          children: data.entries
                                                              .where((e) =>
                                                                  e.key != 'timestamp' &&
                                                                  e.key !=
                                                                      'read' &&
                                                                  e.key !=
                                                                      'title' &&
                                                                  e.key !=
                                                                      'message' &&
                                                                  e.key !=
                                                                      'teacherId' &&
                                                                  e.key !=
                                                                      'type')
                                                              .map((e) {
                                                            return Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(12),
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border(
                                                                  bottom:
                                                                      BorderSide(
                                                                    color: Colors
                                                                            .grey[
                                                                        200]!,
                                                                    width: 0.5,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  SizedBox(
                                                                    width: 140,
                                                                    child: Text(
                                                                      _prettifyKey(
                                                                          e.key),
                                                                      style:
                                                                          TextStyle(
                                                                        color: Colors
                                                                            .grey[700],
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          12),
                                                                  Expanded(
                                                                    child: Text(
                                                                      e.value?.toString() ??
                                                                          '',
                                                                      style:
                                                                          const TextStyle(
                                                                        color: Colors
                                                                            .black87,
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      if (docs.length > 5)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onClose(); // Close the dialog
                                Navigator.pushNamed(
                                    context, AppRouter.teacherNotifications);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('View All Notifications'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNotificationTitle(String type) {
    switch (type) {
      case 'collaborator_assigned':
        return 'Added as Collaborator';
      case 'course_assigned':
        return 'Course Assigned';
      case 'course_created':
        return 'Course Created';
      default:
        return 'Notification';
    }
  }

  String _getNotificationMessage(String type, Map<String, dynamic> data) {
    final courseTitle = data['courseTitle'] ?? 'Unknown Course';

    switch (type) {
      case 'collaborator_assigned':
        final role = data['role'] ?? 'Collaborator';
        final assignedByName = data['assignedByName'] ?? 'Unknown User';
        return 'You have been added as a $role to "$courseTitle" by $assignedByName';
      case 'course_assigned':
        final assignedByName = data['assignedByName'] ?? 'Unknown User';
        return 'Course "$courseTitle" has been assigned to you by $assignedByName';
      case 'course_created':
        return 'Course "$courseTitle" has been created successfully';
      default:
        return 'You have a new notification';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  String _prettifyKey(String key) {
    // Known mappings for nicer labels
    const Map<String, String> overrides = {
      'courseId': 'Course ID',
      'courseTitle': 'Course Title',
      'challengeId': 'Challenge ID',
      'challengeTitle': 'Challenge Title',
      'videoId': 'Video ID',
      'videoTitle': 'Video Title',
      'forumId': 'Forum ID',
      'forumTitle': 'Forum Title',
      'teacherId': 'Teacher ID',
      'teacherName': 'Teacher Name',
      'userId': 'User ID',
      'userName': 'User Name',
      'assignedBy': 'Assigned By',
      'assignedByName': 'Assigned By Name',
      'role': 'Role',
      'actionRequired': 'Action Required',
      'type': 'Type',
    };
    if (overrides.containsKey(key)) return overrides[key]!;
    // Convert snake_case or camelCase to Title Case
    final snake = key.replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'), (m) => '${m.group(1)}_${m.group(2)}');
    final words = snake.split('_');
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'collaborator_assigned':
        return Icons.people_alt;
      case 'course_assigned':
        return Icons.school;
      case 'course_created':
        return Icons.add_circle_outline;
      case 'account_created':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type, bool actionRequired) {
    if (actionRequired) return Colors.orange[600]!;

    switch (type) {
      case 'collaborator_assigned':
        return Colors.green[600]!;
      case 'course_assigned':
        return Colors.blue[600]!;
      case 'course_created':
        return Colors.purple[600]!;
      case 'account_created':
        return Colors.indigo[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}
