import 'package:flutter/material.dart';
import 'notification_model.dart';
import 'package:codequest/services/notification_service.dart';

class NotificationPanel extends StatefulWidget {
  final List<AdminNotification> notifications;
  final void Function(String id) onMarkRead;
  final VoidCallback onClose;

  const NotificationPanel({
    super.key,
    required this.notifications,
    required this.onMarkRead,
    required this.onClose,
  });

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.notifications.where((n) => !n.isRead).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (unreadCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '$unreadCount unread',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.notifications.any((n) => n.isRead))
                    _isClearing
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title:
                                        const Text('Clear Read Notifications'),
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
                                        .clearReadNotifications();
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
                                    Navigator.of(context).pop();
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delete_sweep,
                                      size: 18,
                                      color: Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Clear Read',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onClose,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.notifications.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade100,
                  ),
                  itemBuilder: (context, i) {
                    final n = widget.notifications[i];
                    return InkWell(
                      onTap: () async {
                        // Mark as read
                        widget.onMarkRead(n.id);
                        // Show full content dialog
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            titlePadding:
                                const EdgeInsets.fromLTRB(24, 24, 24, 16),
                            contentPadding:
                                const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(
                                        n.data['type'] as String?),
                                    color: Colors.blue.shade700,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title.isNotEmpty
                                            ? n.title
                                            : 'Notification',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _formatDetailedTime(n.timestamp),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_getTeacherName(n.data) != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 18,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Teacher',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _getTeacherName(n.data)!,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.green.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (n.message.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.blue.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 20,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              n.message,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.6,
                                                color: Colors.blue.shade900,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_hasRelevantDetails(n.data)) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                        children: [
                                          Expanded(child: Divider()),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              'Details',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(child: Divider()),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ..._getRelevantDetails(n.data).map((entry) {
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _prettifyKey(entry.key),
                                                style: TextStyle(
                                                  color: Colors.blue.shade900,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                entry.value?.toString() ?? '—',
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ],
                              ),
                            ),
                            actionsPadding:
                                const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            actions: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    backgroundColor: Colors.blue.shade600,
                                  ),
                                  child: const Text(
                                    'Dismiss',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? Colors.white
                              : Colors.blue.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: n.isRead
                                ? Colors.grey.shade200
                                : Colors.blue.shade200,
                            width: 1,
                          ),
                          boxShadow: n.isRead
                              ? []
                              : [
                                  BoxShadow(
                                    color:
                                        Colors.blue.shade100.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: n.isRead
                                    ? Colors.grey.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getNotificationIcon(n.data['type'] as String?),
                                color: n.isRead
                                    ? Colors.grey.shade600
                                    : Colors.blue.shade700,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: n.isRead
                                          ? FontWeight.w600
                                          : FontWeight.bold,
                                      fontSize: 15,
                                      color: n.isRead
                                          ? Colors.black87
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: n.isRead
                                          ? Colors.grey[600]
                                          : Colors.grey[800],
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (_getItemTitle(n.data) != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getItemIcon(
                                                n.data['type'] as String?),
                                            size: 14,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _getItemTitle(n.data)!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade900,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_getTeacherName(n.data) != null &&
                                      _getItemTitle(n.data) == null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 12,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _getTeacherName(n.data)!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _formatTime(n.timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (!n.isRead) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  String _formatDetailedTime(DateTime dt) {
    final months = [
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'course_created':
      case 'course_updated':
      case 'course_deleted':
        return Icons.menu_book;
      case 'challenge_created':
      case 'challenge_submitted':
      case 'challenge_completed':
        return Icons.code;
      case 'forum_post_created':
        return Icons.forum;
      case 'video_uploaded':
        return Icons.video_library;
      case 'user_registered':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  bool _hasRelevantDetails(Map<String, dynamic> data) {
    final relevantKeys = [
      'courseTitle',
      'challengeTitle',
      'videoTitle',
      'forumTitle',
      'teacherName',
      'userName',
    ];
    return data.entries.any((e) =>
        relevantKeys.contains(e.key) &&
        e.value != null &&
        e.value.toString().isNotEmpty &&
        !_isIdField(e.key));
  }

  List<MapEntry<String, dynamic>> _getRelevantDetails(
      Map<String, dynamic> data) {
    // Only show meaningful fields, exclude IDs and internal fields
    return data.entries
        .where((e) =>
            e.key != 'timestamp' &&
            e.key != 'read' &&
            e.key != 'title' &&
            e.key != 'message' &&
            e.key != 'type' &&
            !_isIdField(e.key) &&
            e.value != null &&
            e.value.toString().isNotEmpty &&
            !_isInternalDataField(e.value))
        .toList();
  }

  bool _isIdField(String key) {
    return key.endsWith('Id') || key == 'id';
  }

  bool _isInternalDataField(dynamic value) {
    // Exclude complex nested objects and maps
    return value is Map || value is List;
  }

  String? _getTeacherName(Map<String, dynamic> data) {
    final teacherName = data['teacherName'] as String?;
    if (teacherName != null && teacherName.isNotEmpty) {
      return teacherName;
    }
    return null;
  }

  String? _getItemTitle(Map<String, dynamic> data) {
    // Get the most relevant item title for display
    final courseTitle = data['courseTitle'] as String?;
    if (courseTitle != null && courseTitle.isNotEmpty) {
      return courseTitle;
    }
    final challengeTitle = data['challengeTitle'] as String?;
    if (challengeTitle != null && challengeTitle.isNotEmpty) {
      return challengeTitle;
    }
    final forumTitle = data['forumTitle'] as String?;
    if (forumTitle != null && forumTitle.isNotEmpty) {
      return forumTitle;
    }
    final videoTitle = data['videoTitle'] as String?;
    if (videoTitle != null && videoTitle.isNotEmpty) {
      return videoTitle;
    }
    return null;
  }

  IconData _getItemIcon(String? type) {
    switch (type) {
      case 'course_created':
      case 'course_updated':
      case 'course_deleted':
        return Icons.menu_book;
      case 'challenge_created':
      case 'challenge_submitted':
      case 'challenge_completed':
      case 'challenge_deleted':
        return Icons.code;
      case 'forum_post_created':
        return Icons.forum;
      case 'video_uploaded':
      case 'video_deleted':
        return Icons.video_library;
      default:
        return Icons.notifications;
    }
  }

  String _prettifyKey(String key) {
    // Professional label mappings - only for relevant display fields
    const Map<String, String> overrides = {
      'courseTitle': 'Course',
      'challengeTitle': 'Challenge',
      'videoTitle': 'Video',
      'forumTitle': 'Forum',
      'teacherName': 'Teacher',
      'userName': 'User',
      'type': 'Event Type',
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
}
