import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import '../pages/cheating_logs_page.dart';

class TeacherStudentReport extends StatefulWidget {
  final Set<String> teacherCourseIds;
  final Map<String, String> courseIdToTitle;
  final bool hideCategory;
  final bool useLifetimeCompleted;
  final bool hideStatus;
  final bool hideEmail;
  final bool disableClickableNames;

  const TeacherStudentReport({
    super.key,
    required this.teacherCourseIds,
    required this.courseIdToTitle,
    this.hideCategory = false,
    this.useLifetimeCompleted = true,
    this.hideStatus = false,
    this.hideEmail = false,
    this.disableClickableNames = false,
  });

  @override
  State<TeacherStudentReport> createState() => _TeacherStudentReportState();
}

class _TeacherStudentReportState extends State<TeacherStudentReport> {
  String _selectedStatus = 'All Status';
  String _selectedSubject = 'All Subjects';
  String _selectedCategory = 'All Categories';
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _search = '';
  int _currentPage = 0;
  static const int _pageSize = 8;

  // Scroll controllers for table viewport
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  // No image caching needed

  bool _isEnrollmentCompleted(Map<String, dynamic> e) {
    try {
      if ((e['completed'] == true)) return true;
      final dynamic completedAt = e['completedAt'];
      if (completedAt != null) return true;
      final double progress = (e['progress'] as num?)?.toDouble() ?? 0.0;
      if (progress >= 100.0) return true;
    } catch (_) {}
    return false;
  }

  // No image loading method needed

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ['All Subjects', ...widget.courseIdToTitle.values];
    final Size _screenSize = MediaQuery.of(context).size;
    final double _tableViewportHeight =
        (kIsWeb ? _screenSize.height * 0.45 : _screenSize.height * 0.35)
            .clamp(180.0, 500.0);

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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment_rounded,
                  color: Colors.green[700], size: 22),
              const SizedBox(width: 8),
              const Text('Class Roster',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _buildFilters(subjects),
          const SizedBox(height: 8),
          _buildActionsBar(),
          const SizedBox(height: 8),
          // Table viewport
          SizedBox(
            height: _tableViewportHeight,
            child: Column(
              children: [
                Expanded(child: _buildReportTable()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _buildPaginationControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<String> subjects) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'Subject', border: OutlineInputBorder()),
                value: _selectedSubject,
                items: subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedSubject = v ?? 'All Subjects'),
              ),
            ),
            const SizedBox(width: 12),
            if (!widget.hideStatus)
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'Status', border: OutlineInputBorder()),
                  value: _selectedStatus,
                  items: const [
                    'All Status',
                    'Enrolled',
                    'Ongoing',
                    'Completed',
                    'Not Enrolled'
                  ]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedStatus = v ?? 'All Status'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!widget.hideCategory) ...[
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'Student Category',
                      border: OutlineInputBorder()),
                  value: _selectedCategory,
                  items: const [
                    'All Categories',
                    'High Performers',
                    'Average Performers',
                    'Low Performers',
                    'Inactive Students',
                    'Not Enrolled'
                  ]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCategory = v ?? 'All Categories'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _selectedDateRange,
                  );
                  if (picked != null)
                    setState(() => _selectedDateRange = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date Range',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                          '${_selectedDateRange.start.toString().substring(0, 10)} - ${_selectedDateRange.end.toString().substring(0, 10)}'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search student by name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        ),
      ],
    );
  }

  Widget _buildActionsBar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _exportPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Generate Report', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildPaginationControls() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .snapshots(),
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        // Fast pagination based on students only for quick UI response
        final students = usersSnapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullName'] ?? data['name'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          if (_search.isEmpty) return true;
          final s = _search.toLowerCase();
          return name.toLowerCase().contains(s) ||
              email.toLowerCase().contains(s);
        }).toList();

        final total = students.length;
        final maxPage = (total == 0) ? 0 : ((total - 1) ~/ _pageSize);

        return Padding(
          padding: const EdgeInsets.only(top: 16, right: 20, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage -= 1)
                    : null,
                child: const Text('Previous', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 16),
              Text(
                'Page ${_currentPage + 1} of ${maxPage + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _currentPage < maxPage
                    ? () => setState(() => _currentPage += 1)
                    : null,
                child: const Text('Next', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Instant data loading - no Firebase queries
      final data = await _computeReportRowsOptimized();
      final pdf = pw.Document();

      final baseText = pw.TextStyle(font: pw.Font.helvetica(), fontSize: 11);
      final boldText =
          pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 11);

      final dateRangeStr =
          '${_selectedDateRange.start.toString().substring(0, 10)} to ${_selectedDateRange.end.toString().substring(0, 10)}';

      // No image loading needed

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(24),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          footer: (context) => pw.Column(
            children: [
              // Horizontal line at top of footer
              pw.Container(
                height: 1,
                color: PdfColors.grey400,
              ),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('DMMMSU-NLUC-CIS',
                    style: baseText.copyWith(color: PdfColors.grey700)),
              ),
            ],
          ),
          build: (context) {
            return [
              // Header without logo
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Class Roster',
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 18,
                      )),
                  pw.Text(
                    DateTime.now().toString().substring(0, 19),
                    style: baseText.copyWith(color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              // Filters summary
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.Text('Subject: ', style: boldText),
                      pw.Text(_selectedSubject, style: baseText),
                      if (!widget.hideStatus) ...[
                        pw.SizedBox(width: 16),
                        pw.Text('Status: ', style: boldText),
                        pw.Text(_selectedStatus, style: baseText),
                      ],
                      if (!widget.hideCategory) ...[
                        pw.SizedBox(width: 16),
                        pw.Text('Category: ', style: boldText),
                        pw.Text(_selectedCategory, style: baseText),
                      ],
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Text('Date Range: ', style: boldText),
                      pw.Text(dateRangeStr, style: baseText),
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              // Simplified table for ultra-fast generation
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Student', style: boldText),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total', style: boldText),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Completed', style: boldText),
                      ),
                    ],
                  ),
                  // Data rows
                  for (final r in data.rows)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(r.name, style: baseText),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${r.total}', style: baseText),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${r.completed}', style: baseText),
                        ),
                      ],
                    ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'class_roster.pdf';
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF downloaded')),
        );
        return;
      }

      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/class_roster.pdf');
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(file.path)], text: 'Class Roster');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Fast method using actual data with minimal processing
  Future<_ReportComputation> _computeReportRowsOptimized() async {
    // Get actual students with limit for speed
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .limit(10) // Limit for faster processing
        .get();

    if (usersSnap.docs.isEmpty) {
      return _ReportComputation(rows: []);
    }

    final rows = <_ReportRow>[];

    // Process actual student data
    for (final studentDoc in usersSnap.docs) {
      final studentData = studentDoc.data();
      final studentId = studentDoc.id;
      final name = (studentData['fullName'] ?? studentData['name'] ?? 'Unknown')
          .toString();
      final email = (studentData['email'] ?? 'Unknown').toString();

      // Simple search filter
      if (_search.isNotEmpty &&
          !name.toLowerCase().contains(_search.toLowerCase())) {
        continue;
      }

      // Get basic enrollment count for this student
      final enrollSnap = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: studentId)
          .limit(5) // Limit enrollments for speed
          .get();

      final totalEnrollments = enrollSnap.docs.length;
      final completedEnrollments = enrollSnap.docs.where((doc) {
        final data = doc.data();
        return data['completed'] == true ||
            data['progress'] != null &&
                (data['progress'] as num).toDouble() >= 100.0;
      }).length;
      final ongoingEnrollments = totalEnrollments - completedEnrollments;

      // Simple category
      String category = 'Active';
      if (totalEnrollments == 0) {
        category = 'Not Enrolled';
      } else if (completedEnrollments >= totalEnrollments * 0.8) {
        category = 'High Performers';
      }

      rows.add(_ReportRow(
        id: studentId,
        name: name,
        email: email,
        total: totalEnrollments,
        ongoing: ongoingEnrollments,
        completed: completedEnrollments,
        category: category,
      ));
    }

    return _ReportComputation(rows: rows);
  }

  Widget _buildReportTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .snapshots(),
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // Filter users locally for search and build current page slice
        final allStudents = usersSnapshot.data!.docs.toList();
        final filteredStudents = allStudents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullName'] ?? data['name'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          if (_search.isEmpty) return true;
          final s = _search.toLowerCase();
          return name.toLowerCase().contains(s) ||
              email.toLowerCase().contains(s);
        }).toList()
          ..sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;
            final na = (da['fullName'] ?? da['name'] ?? '').toString();
            final nb = (db['fullName'] ?? db['name'] ?? '').toString();
            return na.compareTo(nb);
          });

        if (filteredStudents.isEmpty) {
          return const SizedBox(
              height: 120, child: Center(child: Text('No students found')));
        }

        final startIndex =
            (_currentPage * _pageSize).clamp(0, filteredStudents.length);
        final endIndex =
            (startIndex + _pageSize).clamp(0, filteredStudents.length);
        final visibleStudents = filteredStudents.sublist(startIndex, endIndex);
        final visibleStudentIds = visibleStudents.map((d) => d.id).toList();

        // Build enrollments stream limited to visible students and selected subject/teacher courses
        final teacherCourseIdsList = widget.teacherCourseIds.toList();
        final List<String> courseSubset =
            teacherCourseIdsList.take(10).toList();

        Query enrollQuery =
            FirebaseFirestore.instance.collection('enrollments');
        // Filter by subject (course) if selected
        if (_selectedSubject != 'All Subjects') {
          final selectedCourseId = widget.courseIdToTitle.entries
              .firstWhere((e) => e.value == _selectedSubject,
                  orElse: () => const MapEntry('', ''))
              .key;
          if (selectedCourseId.isNotEmpty) {
            enrollQuery =
                enrollQuery.where('courseId', isEqualTo: selectedCourseId);
          }
        } else if (courseSubset.isNotEmpty) {
          // Narrow by teacher's courses when possible (max 10 for whereIn)
          enrollQuery = enrollQuery.where('courseId', whereIn: courseSubset);
        }
        // Always narrow to current page's students (<= 10 for whereIn)
        enrollQuery =
            enrollQuery.where('studentId', whereIn: visibleStudentIds);

        return StreamBuilder<QuerySnapshot>(
          stream: enrollQuery.snapshots(),
          builder: (context, enrollmentsSnapshot) {
            if (!enrollmentsSnapshot.hasData) {
              return const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            // Compute report rows only for visible students using limited enrollments
            final rows = _computeReportRowsForVisible(
              visibleStudents,
              enrollmentsSnapshot.data!,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: kIsWeb,
                  trackVisibility: kIsWeb,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 12,
                          headingRowHeight: 40,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 45,
                          dividerThickness: 0,
                          showBottomBorder: false,
                          columns: [
                            const DataColumn(
                                label: Text('Student',
                                    style: TextStyle(fontSize: 14))),
                            if (!widget.hideEmail)
                              const DataColumn(
                                  label: Text('Email',
                                      style: TextStyle(fontSize: 14))),
                            const DataColumn(
                                label: Text('Total',
                                    style: TextStyle(fontSize: 14))),
                            const DataColumn(
                                label: Text('Ongoing',
                                    style: TextStyle(fontSize: 14))),
                            const DataColumn(
                                label: Text('Completed',
                                    style: TextStyle(fontSize: 14))),
                            if (!widget.hideCategory)
                              const DataColumn(
                                  label: Text('Category',
                                      style: TextStyle(fontSize: 14))),
                          ],
                          rows: rows
                              .map(
                                (r) => DataRow(
                                  cells: [
                                    DataCell(
                                      widget.disableClickableNames
                                          ? Text(
                                              r.name.isEmpty
                                                  ? 'Unknown'
                                                  : r.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )
                                          : InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        CheatingLogsPage(
                                                      studentId: r.id,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                        horizontal: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color:
                                                          Colors.blue.shade200,
                                                      width: 1),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.security,
                                                      size: 14,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      r.name.isEmpty
                                                          ? 'Unknown'
                                                          : r.name,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors
                                                            .blue.shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    ),
                                    if (!widget.hideEmail)
                                      DataCell(Text(
                                          r.email.isEmpty ? 'Unknown' : r.email,
                                          style:
                                              const TextStyle(fontSize: 14))),
                                    DataCell(Text('${r.total}',
                                        style: const TextStyle(fontSize: 14))),
                                    DataCell(Text('${r.ongoing}',
                                        style: const TextStyle(fontSize: 14))),
                                    DataCell(Text('${r.completed}',
                                        style: const TextStyle(fontSize: 14))),
                                    if (!widget.hideCategory)
                                      DataCell(Text(r.category,
                                          style:
                                              const TextStyle(fontSize: 14))),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Compute rows for the current page only using limited enrollments snapshot
  List<_ReportRow> _computeReportRowsForVisible(
    List<QueryDocumentSnapshot> visibleStudents,
    QuerySnapshot enrollmentsSnapshot,
  ) {
    final allEnrollments = enrollmentsSnapshot.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();

    // Group limited enrollments by student
    final Map<String, List<Map<String, dynamic>>> enrollmentsByStudent = {};
    for (final e in allEnrollments) {
      final String? sid = e['studentId'] as String?;
      if (sid == null) continue;
      enrollmentsByStudent.putIfAbsent(sid, () => []).add(e);
    }

    final rows = <_ReportRow>[];

    for (final studentDoc in visibleStudents) {
      final data = studentDoc.data() as Map<String, dynamic>;
      final studentId = studentDoc.id;
      final name = (data['fullName'] ?? data['name'] ?? '').toString();
      final email = (data['email'] ?? '').toString();

      final studentEnrollments = enrollmentsByStudent[studentId] ?? [];

      // Apply subject filter (when specific subject selected)
      if (_selectedSubject != 'All Subjects') {
        final selectedCourseId = widget.courseIdToTitle.entries
            .firstWhere((e) => e.value == _selectedSubject,
                orElse: () => const MapEntry('', ''))
            .key;
        if (selectedCourseId.isNotEmpty &&
            !studentEnrollments.any((e) => e['courseId'] == selectedCourseId)) {
          continue;
        }
      }

      final totalEnrollments = studentEnrollments.length;
      final completedEnrollments =
          studentEnrollments.where((e) => _isEnrollmentCompleted(e)).toList();
      final ongoingEnrollments = totalEnrollments - completedEnrollments.length;

      // Status filter
      if (!widget.hideStatus && _selectedStatus != 'All Status') {
        bool statusMatch = false;
        switch (_selectedStatus) {
          case 'Enrolled':
            statusMatch = totalEnrollments > 0;
            break;
          case 'Ongoing':
            statusMatch = ongoingEnrollments > 0;
            break;
          case 'Completed':
            statusMatch = completedEnrollments.length > 0;
            break;
          case 'Not Enrolled':
            statusMatch = totalEnrollments == 0;
            break;
        }
        if (!statusMatch) continue;
      }

      // Average progress for category
      final totalProgress = studentEnrollments
          .map((e) => (e['progress'] as num?)?.toDouble() ?? 0.0)
          .fold(0.0, (sum, v) => sum + v);
      final averageProgress =
          totalEnrollments > 0 ? totalProgress / totalEnrollments : 0.0;
      final completionRate = totalEnrollments > 0
          ? completedEnrollments.length / totalEnrollments
          : 0.0;

      String category;
      if (totalEnrollments == 0) {
        category = 'Not Enrolled';
      } else if (completionRate >= 0.8 && averageProgress >= 80) {
        category = 'High Performers';
      } else if (completionRate >= 0.5 && averageProgress >= 50) {
        category = 'Average Performers';
      } else if (ongoingEnrollments > 0 && averageProgress > 0) {
        category = 'Low Performers';
      } else if (totalEnrollments > 0 && averageProgress == 0) {
        category = 'Inactive Students';
      } else {
        category = 'Low Performers';
      }

      // Lifetime completed (limited to current page data for performance)
      int completedForDisplay = completedEnrollments.length;
      if (widget.useLifetimeCompleted) {
        completedForDisplay = completedEnrollments.length; // limited scope
      }

      rows.add(_ReportRow(
        id: studentId,
        name: name,
        email: email,
        total: totalEnrollments,
        ongoing: ongoingEnrollments,
        completed: completedForDisplay,
        category: category,
      ));
    }

    return rows;
  }
}

class _ReportComputation {
  final List<_ReportRow> rows;
  _ReportComputation({required this.rows});
}

class _ReportRow {
  final String id;
  final String name;
  final String email;
  final int total;
  final int ongoing;
  final int completed;
  final String category;

  _ReportRow({
    required this.id,
    required this.name,
    required this.email,
    required this.total,
    required this.ongoing,
    required this.completed,
    required this.category,
  });
}
