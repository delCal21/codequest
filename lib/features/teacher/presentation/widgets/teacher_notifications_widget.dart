import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/services/notification_service.dart';
import 'package:intl/intl.dart';

class TeacherNotificationsWidget extends StatefulWidget {
  const TeacherNotificationsWidget({Key? key}) : super(key: key);

  @override
  State<TeacherNotificationsWidget> createState() =>
      _TeacherNotificationsWidgetState();
}

class _TeacherNotificationsWidgetState
    extends State<TeacherNotificationsWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view notifications'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: NotificationService.getTeacherNotifications(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading notifications: ${snapshot.error}'),
          );
        }

        final notifications = snapshot.data?.docs ?? [];

        if (notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You\'ll see notifications here when you\'re assigned\nto courses or added as a collaborator',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications (${notifications.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      StreamBuilder<int>(
                        stream: NotificationService
                            .getUnreadTeacherNotificationsCount(
                                currentUser.uid),
                        builder: (context, unreadSnapshot) {
                          final unreadCount = unreadSnapshot.data ?? 0;
                          if (unreadCount == 0) return const SizedBox.shrink();

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () =>
                            _clearReadNotifications(currentUser.uid),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Read'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final data = notification.data() as Map<String, dynamic>;
                  final isRead = data['read'] ?? false;
                  final type = data['type'] ?? '';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final actionRequired = data['actionRequired'] ?? false;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRead ? Colors.grey[200]! : Colors.blue[200]!,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getNotificationColor(type, actionRequired)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getNotificationColor(type, actionRequired)
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _getNotificationIcon(type),
                          color: _getNotificationColor(type, actionRequired),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        _getNotificationTitle(type),
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.w600,
                          fontSize: 16,
                          color: isRead ? Colors.grey[700] : Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            _getNotificationMessage(type, data),
                            style: TextStyle(
                              color:
                                  isRead ? Colors.grey[600] : Colors.grey[700],
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.grey[600],
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (actionRequired) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange[400]!,
                                    Colors.orange[600]!
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
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
                      trailing: !isRead
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            )
                          : null,
                      onTap: () async {
                        // Mark as read
                        await _markAsRead(notification.id);

                        // Capture values for the dialog
                        final notificationType = type;
                        final notificationData = data;
                        final notificationTimestamp = timestamp;

                        // Show detailed view dialog
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
                              constraints: const BoxConstraints(maxHeight: 600),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getNotificationColor(
                                              notificationType, actionRequired),
                                          _getNotificationColor(
                                                  notificationType,
                                                  actionRequired)
                                              .withOpacity(0.8),
                                        ],
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
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(
                                                notificationType),
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            _getNotificationTitle(
                                                notificationType),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          icon: const Icon(Icons.close,
                                              color: Colors.white),
                                          tooltip: 'Close',
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.grey[200]!),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  color: Colors.grey[600],
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatTimestamp(
                                                      notificationTimestamp ??
                                                          Timestamp.now()),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.blue[200]!),
                                            ),
                                            child: Text(
                                              _getNotificationMessage(
                                                  notificationType,
                                                  notificationData),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                height: 1.4,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (notificationData.isNotEmpty) ...[
                                            const SizedBox(height: 20),
                                            Text(
                                              'Details',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[800],
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: Colors.grey[200]!),
                                              ),
                                              child: Column(
                                                children: notificationData
                                                    .entries
                                                    .where((e) =>
                                                        e.key != 'timestamp' &&
                                                        e.key != 'read' &&
                                                        e.key != 'title' &&
                                                        e.key != 'message' &&
                                                        e.key != 'teacherId' &&
                                                        e.key != 'type')
                                                    .map((e) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        bottom: BorderSide(
                                                          color:
                                                              Colors.grey[200]!,
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
                                                            _prettifyKey(e.key),
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[700],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            e.value?.toString() ??
                                                                '',
                                                            style:
                                                                const TextStyle(
                                                              color: Colors
                                                                  .black87,
                                                              fontSize: 13,
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
          ],
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final notificationTime = timestamp.toDate();
    final difference = now.difference(notificationTime);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, yyyy').format(notificationTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await NotificationService.markTeacherNotificationAsRead(notificationId);
  }

  Future<void> _clearReadNotifications(String teacherId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Read Notifications'),
        content: const Text(
          'Are you sure you want to clear all read notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationService.clearReadTeacherNotifications(teacherId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Read notifications cleared'),
          ),
        );
      }
    }
  }

  String _getNotificationTitle(String type) {
    switch (type) {
      case 'collaborator_assigned':
        return 'Added as Collaborator';
      case 'course_assigned':
        return 'Course Assigned';
      case 'course_created':
        return 'Course Created';
      case 'account_created':
        return 'Account Created';
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
      case 'account_created':
        return 'Your teacher account has been created by the administrator. Please check your email for login instructions.';
      default:
        return 'You have a new notification';
    }
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
