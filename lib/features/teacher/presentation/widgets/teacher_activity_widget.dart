import 'package:flutter/material.dart';
import 'package:codequest/services/activity_service.dart';
import 'package:codequest/features/admin/domain/models/activity_model.dart';

class TeacherActivityWidget extends StatefulWidget {
  final String teacherId;
  final Set<String> teacherCourseIds;
  final String Function(DateTime) getTimeAgo;

  const TeacherActivityWidget({
    Key? key,
    required this.teacherId,
    required this.teacherCourseIds,
    required this.getTimeAgo,
  }) : super(key: key);

  @override
  State<TeacherActivityWidget> createState() => _TeacherActivityWidgetState();
}

class _TeacherActivityWidgetState extends State<TeacherActivityWidget> {
  late Future<List<ActivityModel>> _future;
  List<ActivityModel>? _activities;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _future = ActivityService.getRecentTeacherActivities(
      teacherId: widget.teacherId,
      teacherCourseIds: widget.teacherCourseIds,
      limit: 15,
    );
    _future.then((activities) {
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _loading = false;
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildLoadingWidget();
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    final activities = _activities ?? [];
    if (activities.isEmpty) {
      return _buildEmptyWidget();
    }

    return _buildActivityList(activities);
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Error loading activity: ${_error.toString()}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'No recent activity',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(List<ActivityModel> activities) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...activities.map((activity) => _ActivityItem(
                activity: activity,
                getTimeAgo: widget.getTimeAgo,
              )),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final ActivityModel activity;
  final String Function(DateTime) getTimeAgo;

  const _ActivityItem({
    required this.activity,
    required this.getTimeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = getTimeAgo(activity.timestamp);
    final icon = ActivityService.getActivityIcon(activity.entityType);
    final color =
        Color(ActivityService.getActivityColor(activity.activityType));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      activity.teacherName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(
                        _getActionText(activity.activityType),
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  String _getActionText(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.courseCreated:
      case ActivityType.challengeCreated:
      case ActivityType.videoCreated:
      case ActivityType.forumCreated:
        return 'CREATED';
      case ActivityType.courseUpdated:
      case ActivityType.challengeUpdated:
      case ActivityType.videoUpdated:
      case ActivityType.forumUpdated:
        return 'UPDATED';
      case ActivityType.courseDeleted:
      case ActivityType.challengeDeleted:
      case ActivityType.videoDeleted:
      case ActivityType.forumDeleted:
        return 'DELETED';
    }
  }
}
