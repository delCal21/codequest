import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheatingLogsPage extends StatefulWidget {
  final String? studentId;
  const CheatingLogsPage({Key? key, this.studentId}) : super(key: key);

  @override
  State<CheatingLogsPage> createState() => _CheatingLogsPageState();
}

class _CheatingLogsPageState extends State<CheatingLogsPage> {
  int _currentPage = 0;
  static const int _pageSize = 20;
  String _search = '';
  String _selectedEvent = 'All';
  DateTimeRange? _dateRange;
  int _sortColumnIndex = 0;
  bool _sortAscending = false; // newest first when false

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentId != null
                        ? 'Activity Monitoring'
                        : 'Security Logs',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (widget.studentId != null)
                    Text(
                      'Student Activity Logs',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red.shade600, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Confirm Deletion'),
                          ),
                        ],
                      ),
                      content: Text(
                        widget.studentId != null
                            ? 'Are you sure you want to clear all activity logs for this student? This action cannot be undone.'
                            : 'Are you sure you want to clear ALL activity logs? This action cannot be undone.',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      if (widget.studentId != null) {
                        // Clear logs for specific student
                        final batch = FirebaseFirestore.instance.batch();
                        final query = await FirebaseFirestore.instance
                            .collection('challenge_cheat_logs')
                            .where('studentId', isEqualTo: widget.studentId)
                            .get();
                        for (final doc in query.docs) {
                          batch.delete(doc.reference);
                        }
                        await batch.commit();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Activity logs cleared successfully'),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      } else {
                        // Clear all logs
                        final batch = FirebaseFirestore.instance.batch();
                        final query = await FirebaseFirestore.instance
                            .collection('challenge_cheat_logs')
                            .get();
                        for (final doc in query.docs) {
                          batch.delete(doc.reference);
                        }
                        await batch.commit();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('All logs cleared successfully'),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error clearing logs: $e'),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_sweep, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        widget.studentId != null ? 'Clear' : 'Clear All',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Search and filter controls header section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Filters & Search',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Search logs...',
                      hintText:
                          'Search by student, challenge, course, or event type',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade600, size: 20),
                              onPressed: () => setState(() => _search = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.green.shade700, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedEvent,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: Colors.grey.shade700),
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'All', child: Text('All Events')),
                              DropdownMenuItem(
                                  value: 'screenshot_taken',
                                  child: Text('Screenshots')),
                              DropdownMenuItem(
                                  value: 'screen_recording_started',
                                  child: Text('Screen Recording Started')),
                              DropdownMenuItem(
                                  value: 'screen_recording_stopped',
                                  child: Text('Screen Recording Stopped')),
                              DropdownMenuItem(
                                  value: 'app_paused',
                                  child: Text('App Paused')),
                              DropdownMenuItem(
                                  value: 'app_resumed',
                                  child: Text('App Resumed')),
                              DropdownMenuItem(
                                  value: 'clipboard_cleared',
                                  child: Text('Clipboard Cleared')),
                              DropdownMenuItem(
                                  value: 'tab_hidden',
                                  child: Text('Tab Hidden')),
                              DropdownMenuItem(
                                  value: 'tab_visible',
                                  child: Text('Tab Visible')),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedEvent = value!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.green.shade700,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (range != null) {
                            setState(() => _dateRange = range);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _dateRange == null
                              ? 'Select Date Range'
                              : '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                      if (_dateRange != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _dateRange = null),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.shade200, width: 1),
                                ),
                                child: Icon(Icons.clear,
                                    color: Colors.red.shade700, size: 18),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Data table section
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: (() {
                  Query query = FirebaseFirestore.instance
                      .collection('challenge_cheat_logs');
                  if (widget.studentId != null) {
                    query =
                        query.where('studentId', isEqualTo: widget.studentId);
                  }
                  if (_selectedEvent != 'All') {
                    query = query.where('eventType', isEqualTo: _selectedEvent);
                  }
                  if (_dateRange != null) {
                    query = query
                        .where('timestamp',
                            isGreaterThanOrEqualTo:
                                Timestamp.fromDate(_dateRange!.start))
                        .where('timestamp',
                            isLessThanOrEqualTo:
                                Timestamp.fromDate(_dateRange!.end));
                  }
                  query = query.orderBy('timestamp', descending: true);
                  return query.snapshots();
                })(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade700),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading activity logs...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.studentId != null
                                ? 'No activity logs found for this student'
                                : 'No activity logs found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Activity logs will appear here when detected',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // Prepare rows
                  final docs = snapshot.data!.docs;
                  List<Map<String, dynamic>> logs = docs
                      .map((d) => d.data() as Map<String, dynamic>)
                      .toList(growable: false);

                  // Client-side filters
                  if (_search.isNotEmpty) {
                    final s = _search.toLowerCase();
                    logs = logs.where((log) {
                      bool matches(String? v) =>
                          (v ?? '').toLowerCase().contains(s);
                      return matches(log['studentName'] as String?) ||
                          matches(log['studentId'] as String?) ||
                          matches(log['challengeTitle'] as String?) ||
                          matches(log['courseTitle'] as String?) ||
                          matches(log['eventType'] as String?);
                    }).toList(growable: false);
                  }

                  if (_selectedEvent != 'All') {
                    logs = logs
                        .where((log) =>
                            (log['eventType'] as String?) == _selectedEvent)
                        .toList(growable: false);
                  }

                  if (_dateRange != null) {
                    final start = DateTime(_dateRange!.start.year,
                        _dateRange!.start.month, _dateRange!.start.day);
                    final end = DateTime(_dateRange!.end.year,
                        _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
                    logs = logs.where((log) {
                      final ts = log['timestamp'] as Timestamp?;
                      if (ts == null) return false;
                      final dt = ts.toDate();
                      return !dt.isBefore(start) && !dt.isAfter(end);
                    }).toList(growable: false);
                  }

                  // Sort by time
                  logs.sort((a, b) {
                    final ta =
                        (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
                    final tb =
                        (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
                    return _sortAscending ? ta.compareTo(tb) : tb.compareTo(ta);
                  });

                  final total = logs.length;
                  final maxPage = total == 0 ? 0 : ((total - 1) ~/ _pageSize);
                  if (_currentPage > maxPage) _currentPage = maxPage;
                  final startIndex = _currentPage * _pageSize;
                  final endIndex = (startIndex + _pageSize).clamp(0, total);
                  final visible = logs.sublist(startIndex, endIndex);

                  Widget buildPager() {
                    final totalPages =
                        ((total / _pageSize).ceil()).clamp(1, 999);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Showing ${startIndex + 1}-${endIndex} of $total logs',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage -= 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left, size: 20),
                              label: const Text('Previous'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentPage > 0
                                    ? Colors.green.shade700
                                    : Colors.grey.shade300,
                                foregroundColor: _currentPage > 0
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: _currentPage > 0 ? 2 : 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Page ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${_currentPage + 1}',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    ' of $totalPages',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _currentPage < maxPage
                                  ? () => setState(() => _currentPage += 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right, size: 20),
                              label: const Text('Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentPage < maxPage
                                    ? Colors.green.shade700
                                    : Colors.grey.shade300,
                                foregroundColor: _currentPage < maxPage
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: _currentPage < maxPage ? 2 : 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _sortAscending,
                              headingRowColor: MaterialStateProperty.all(
                                  Colors.grey.shade50),
                              headingTextStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                                fontSize: 14,
                              ),
                              dataRowMinHeight: 56,
                              dataRowMaxHeight: 80,
                              columns: [
                                DataColumn(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Timestamp'),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _sortAscending
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ],
                                  ),
                                  onSort: (columnIndex, ascending) {
                                    setState(() {
                                      _sortColumnIndex = columnIndex;
                                      _sortAscending = ascending;
                                    });
                                  },
                                ),
                                const DataColumn(label: Text('Event Type')),
                                const DataColumn(label: Text('Student')),
                                const DataColumn(label: Text('Challenge')),
                                const DataColumn(label: Text('Course')),
                              ],
                              rows: visible.map((log) {
                                final timestamp =
                                    log['timestamp'] as Timestamp?;
                                final timeStr = timestamp != null
                                    ? '${timestamp.toDate().day.toString().padLeft(2, '0')}/${timestamp.toDate().month.toString().padLeft(2, '0')}/${timestamp.toDate().year}\n${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                                    : '-';
                                final eventType =
                                    log['eventType'] as String? ?? 'unknown';
                                final studentName = (log['studentName']
                                        as String?) ??
                                    (log['studentId'] as String? ?? 'Unknown');
                                final challengeTitle =
                                    (log['challengeTitle'] as String?) ??
                                        'Unknown Challenge';
                                final courseTitle =
                                    (log['courseTitle'] as String?) ??
                                        'Unknown Course';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _getEventColor(eventType)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: _getEventColor(eventType)
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getEventIcon(eventType),
                                              size: 14,
                                              color: _getEventColor(eventType),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _getEventLabel(eventType),
                                                style: TextStyle(
                                                  color:
                                                      _getEventColor(eventType),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        studentName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        challengeTitle,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        courseTitle,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: buildPager(),
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

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'screenshot_taken':
        return Colors.red.shade700;
      case 'screen_recording_started':
        return Colors.orange.shade700;
      case 'screen_recording_stopped':
        return Colors.amber.shade700;
      case 'app_paused':
        return Colors.orange.shade400;
      case 'app_resumed':
        return Colors.green.shade600;
      case 'clipboard_cleared':
        return Colors.blue.shade700;
      case 'tab_hidden':
        return Colors.deepOrange.shade700;
      case 'tab_visible':
        return Colors.lightGreen.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'screenshot_taken':
        return Icons.camera_alt;
      case 'screen_recording_started':
        return Icons.videocam;
      case 'screen_recording_stopped':
        return Icons.videocam_off;
      case 'app_paused':
        return Icons.pause_circle_outline;
      case 'app_resumed':
        return Icons.play_circle_outline;
      case 'clipboard_cleared':
        return Icons.content_cut;
      case 'tab_hidden':
        return Icons.visibility_off;
      case 'tab_visible':
        return Icons.visibility;
      default:
        return Icons.info_outline;
    }
  }

  String _getEventLabel(String eventType) {
    switch (eventType) {
      case 'screenshot_taken':
        return 'Screenshot';
      case 'screen_recording_started':
        return 'Recording Started';
      case 'screen_recording_stopped':
        return 'Recording Stopped';
      case 'app_paused':
        return 'App Paused';
      case 'app_resumed':
        return 'App Resumed';
      case 'clipboard_cleared':
        return 'Clipboard Cleared';
      case 'tab_hidden':
        return 'Tab Hidden';
      case 'tab_visible':
        return 'Tab Visible';
      default:
        return eventType
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isEmpty
                ? word
                : (word[0].toUpperCase() + word.substring(1)))
            .join(' ');
    }
  }
}
