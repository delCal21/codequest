import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/services/teacher_email_validation_service.dart';
import 'package:codequest/services/real_email_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _searchQuery = '';
  final currentUser = FirebaseAuth.instance.currentUser;

  // Pagination variables
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;

  // No local _teachers; use Firestore

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _assignCourses(DocumentSnapshot doc) async {
    final teacher = doc.data() as Map<String, dynamic>;
    final selected = Set<String>.from(teacher['courses'] ?? []);
    String searchQuery = '';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.book, color: Colors.blue[600], size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Assign Courses',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search courses...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (value) => setState(
                          () => searchQuery = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('courses')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.blue));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.book_outlined,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text('No courses found',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          }
                          final courseDocs = snapshot.data!.docs;
                          // Filter by search
                          final filteredDocs = courseDocs.where((courseDoc) {
                            final course =
                                courseDoc.data() as Map<String, dynamic>;
                            final title = (course['title'] ?? '')
                                .toString()
                                .toLowerCase();
                            final id = courseDoc.id.toLowerCase();
                            // Only allow courses created by the current user
                            if (course['teacherId'] != currentUser?.uid)
                              return false;
                            return searchQuery.isEmpty ||
                                title.contains(searchQuery) ||
                                id.contains(searchQuery);
                          }).toList();
                          if (filteredDocs.isEmpty) {
                            return Center(
                                child: Text('No courses match your search.',
                                    style: TextStyle(color: Colors.grey[600])));
                          }
                          return ListView(
                            shrinkWrap: true,
                            children: filteredDocs.map((courseDoc) {
                              final course =
                                  courseDoc.data() as Map<String, dynamic>;
                              final courseId = courseDoc.id;
                              final courseTitle = course['title'] ?? 'Untitled';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: CheckboxListTile(
                                  value: selected.contains(courseId),
                                  title: Text(courseTitle,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87)),
                                  subtitle: Text('ID: $courseId',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  activeColor: Colors.blue[600],
                                  onChanged: (checked) {
                                    if (checked == true) {
                                      selected.add(courseId);
                                    } else {
                                      selected.remove(courseId);
                                    }
                                    setState(() {});
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child:
                      Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(selected.isEmpty
                      ? 'Assign'
                      : 'Assign (${selected.length})'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result != null) {
        try {
          // Resolve assigned teacher information
          final teacherId = doc.id;
          final teacherData = doc.data() as Map<String, dynamic>;
          final teacherName = (teacherData['name'] as String?) ?? 'Teacher';

          // Resolve admin assigning metadata
          final admin = FirebaseAuth.instance.currentUser;
          String assignedBy = admin?.uid ?? '';
          String assignedByName = 'Admin';
          if (admin != null) {
            try {
              final adminDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(admin.uid)
                  .get();
              final data = adminDoc.data();
              assignedByName =
                  (data != null ? (data['name'] as String?) : null) ??
                      admin.displayName ??
                      admin.email ??
                      'Admin';
            } catch (_) {
              assignedByName = admin.displayName ?? admin.email ?? 'Admin';
            }
          }

          // Batch update: update selected course docs and teacher's courses array
          final batch = FirebaseFirestore.instance.batch();
          for (final courseId in result) {
            final courseRef =
                FirebaseFirestore.instance.collection('courses').doc(courseId);
            batch.update(courseRef, {
              'teacherId': teacherId,
              'teacherName': teacherName,
              'assignedBy': assignedBy,
              'assignedByName': assignedByName,
              'assignedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          // Persist teacher's courses list for quick lookup
          batch.update(doc.reference, {'courses': result.toList()});

          await batch.commit();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Courses assigned successfully!'),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          // Trigger UI refresh where needed
          setState(() {});
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign courses: $e'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    });
  }

  Future<bool?> _showCourseReassignmentDialog(
    String teacherName,
    List<QueryDocumentSnapshot> courses,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Teacher Has Assigned Courses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The teacher "$teacherName" has ${courses.length} assigned course${courses.length == 1 ? '' : 's'}.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'What would you like to do with these courses?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Courses:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...courses.take(3).map((course) {
                    final courseData = course.data() as Map<String, dynamic>;
                    final courseTitle =
                        courseData['title'] ?? 'Untitled Course';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.book, size: 16, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              courseTitle,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (courses.length > 3)
                    Text(
                      '... and ${courses.length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Assign to Admin
            child: Text(
              'Assign to Admin',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // Reassign courses
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Reassign Courses'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null), // Cancel
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignCoursesToAdmin(
    List<QueryDocumentSnapshot> courses,
  ) async {
    try {
      final admin = FirebaseAuth.instance.currentUser;
      if (admin == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No admin user signed in.'),
            backgroundColor: Colors.red[600],
          ),
        );
        return;
      }

      String adminName = admin.displayName ?? '';
      if (adminName.isEmpty) {
        try {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(admin.uid)
              .get();
          final data = adminDoc.data();
          adminName = (data != null ? (data['name'] as String?) : null) ??
              admin.email ??
              'Admin';
        } catch (_) {
          adminName = admin.email ?? 'Admin';
        }
      }

      for (final courseDoc in courses) {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseDoc.id)
            .update({
          'teacherId': admin.uid,
          'teacherName': adminName,
          'assignedBy': admin.uid,
          'assignedByName': adminName,
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Assigned ${courses.length} course${courses.length == 1 ? '' : 's'} to $adminName (Admin).'),
          backgroundColor: Colors.green[600],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning courses to admin: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  // Show dialog to select which courses to reassign
  Future<List<QueryDocumentSnapshot>?> _showCourseSelectionDialog(
    String teacherName,
    List<QueryDocumentSnapshot> courses,
  ) async {
    if (courses.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No courses found for $teacherName'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return null;
    }

    final selectedCourses = <QueryDocumentSnapshot>[];

    return await showDialog<List<QueryDocumentSnapshot>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.book, color: Colors.blue[600], size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Courses to Reassign',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Select which courses from "$teacherName" should be reassigned to another teacher:',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final courseData = course.data() as Map<String, dynamic>;
                      final courseTitle =
                          courseData['title'] ?? 'Untitled Course';
                      final isSelected = selectedCourses.contains(course);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue[600]!
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          title: Text(
                            courseTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.blue[700]
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${course.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          activeColor: Colors.blue[600],
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedCourses.add(course);
                              } else {
                                selectedCourses.remove(course);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: selectedCourses.isEmpty
                          ? null
                          : () => Navigator.pop(context, selectedCourses),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                          'Reassign ${selectedCourses.length} Course${selectedCourses.length == 1 ? '' : 's'}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced reassignment: Allow assigning different courses to different teachers
  Future<void> _reassignSelectedCourses(
    String teacherId,
    String teacherName,
    List<QueryDocumentSnapshot> selectedCourses,
  ) async {
    // Get all active teachers
    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('active', isEqualTo: true)
        .get();

    if (teachersSnapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('No active teachers found to reassign courses to.'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    // Filter out the current teacher
    final availableTeachers =
        teachersSnapshot.docs.where((doc) => doc.id != teacherId).toList();

    if (availableTeachers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'No other active teachers available to reassign courses to.'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    // Map to store course assignments: courseId -> teacherId
    final Map<String, String> courseAssignments = {};
    final Map<String, String> teacherNames = {};

    // Initialize teacher names map
    for (final teacherDoc in availableTeachers) {
      final teacherData = teacherDoc.data();
      teacherNames[teacherDoc.id] = teacherData['name'] ?? 'Unknown';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!, width: 1),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: Colors.green[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Courses to Teachers',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Distribute courses among available teachers',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Assign each course from $teacherName to a different teacher',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Course assignment list
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectedCourses.length,
                    itemBuilder: (context, index) {
                      final courseDoc = selectedCourses[index];
                      final courseData =
                          courseDoc.data() as Map<String, dynamic>;
                      final courseTitle =
                          courseData['title'] ?? 'Untitled Course';
                      final assignedTeacherId = courseAssignments[courseDoc.id];

                      return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: assignedTeacherId != null
                                  ? Colors.green[200]!
                                  : Colors.grey[200]!,
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: assignedTeacherId != null
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.green[50]!,
                                        Colors.white,
                                      ],
                                    )
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.green[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.menu_book_rounded,
                                          color: Colors.green[600],
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              courseTitle,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Course ID: ${courseDoc.id}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (assignedTeacherId != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.green[300]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.green[600],
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Assigned',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey[200]!, width: 1),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_add_rounded,
                                              color: Colors.green[600],
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Assign to Teacher:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: availableTeachers
                                              .map((teacherDoc) {
                                            final teacherData =
                                                teacherDoc.data();
                                            final teacherName =
                                                teacherData['name'] ??
                                                    'Unknown';
                                            final isSelected =
                                                assignedTeacherId ==
                                                    teacherDoc.id;

                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  courseAssignments[courseDoc
                                                      .id] = teacherDoc.id;
                                                });
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.green[100]
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? Colors.green[300]!
                                                        : Colors.grey[300]!,
                                                    width: isSelected ? 2 : 1,
                                                  ),
                                                  boxShadow: isSelected
                                                      ? [
                                                          BoxShadow(
                                                            color: Colors
                                                                .green[200]!
                                                                .withOpacity(
                                                                    0.3),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                    0, 2),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? Colors.green[200]
                                                            : Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? Colors
                                                                  .green[400]!
                                                              : Colors
                                                                  .grey[400]!,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          teacherName.isNotEmpty
                                                              ? teacherName[0]
                                                                  .toUpperCase()
                                                              : 'T',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: isSelected
                                                                ? Colors
                                                                    .green[800]
                                                                : Colors
                                                                    .grey[600],
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      teacherName,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: isSelected
                                                            ? Colors.green[800]
                                                            : Colors.grey[700],
                                                        fontWeight: isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (isSelected) ...[
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        color:
                                                            Colors.green[600],
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ));
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Summary
                if (courseAssignments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assignment Summary:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...courseAssignments.entries.map((entry) {
                          final courseDoc = selectedCourses.firstWhere(
                            (doc) => doc.id == entry.key,
                          );
                          final courseData =
                              courseDoc.data() as Map<String, dynamic>;
                          final courseTitle =
                              courseData['title'] ?? 'Untitled Course';
                          final teacherName =
                              teacherNames[entry.value] ?? 'Unknown';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_forward,
                                    size: 14, color: Colors.blue[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$courseTitle → $teacherName',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: courseAssignments.length !=
                              selectedCourses.length
                          ? null
                          : () async {
                              try {
                                final admin = FirebaseAuth.instance.currentUser;
                                String assignedByName = 'Admin';
                                if (admin != null) {
                                  try {
                                    final doc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(admin.uid)
                                        .get();
                                    final data = doc.data();
                                    assignedByName = (data != null
                                            ? (data['name'] as String?)
                                            : null) ??
                                        admin.displayName ??
                                        admin.email ??
                                        'Admin';
                                  } catch (_) {
                                    assignedByName = admin.displayName ??
                                        admin.email ??
                                        'Admin';
                                  }
                                }

                                // Reassign each course to its assigned teacher
                                for (final entry in courseAssignments.entries) {
                                  final courseId = entry.key;
                                  final teacherId = entry.value;
                                  final teacherName =
                                      teacherNames[teacherId] ?? 'Unknown';

                                  await FirebaseFirestore.instance
                                      .collection('courses')
                                      .doc(courseId)
                                      .update({
                                    'teacherId': teacherId,
                                    'teacherName': teacherName,
                                    'assignedBy': admin?.uid,
                                    'assignedByName': assignedByName,
                                    'assignedAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                }

                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Successfully reassigned ${selectedCourses.length} course${selectedCourses.length == 1 ? '' : 's'} to different teachers',
                                    ),
                                    backgroundColor: Colors.green[600],
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Error reassigning courses: $e'),
                                    backgroundColor: Colors.red[600],
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Assign ${courseAssignments.length}/${selectedCourses.length} Courses',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reassignTeacherCourses(
    String teacherId,
    String teacherName,
    List<QueryDocumentSnapshot> courses,
  ) async {
    // Get all active teachers
    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('active', isEqualTo: true)
        .get();

    if (teachersSnapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('No active teachers found to reassign courses to.'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    // Filter out the current teacher
    final availableTeachers =
        teachersSnapshot.docs.where((doc) => doc.id != teacherId).toList();

    if (availableTeachers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'No other active teachers available to reassign courses to.'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    String? selectedTeacherId;
    String? selectedTeacherName;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Reassign Courses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a new teacher to assign ${courses.length} course${courses.length == 1 ? '' : 's'} from "$teacherName":',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select New Teacher',
                  border: OutlineInputBorder(),
                ),
                value: selectedTeacherId,
                items: availableTeachers.map((teacherDoc) {
                  final teacherData = teacherDoc.data();
                  final teacherName = teacherData['name'] ?? 'Unknown Teacher';
                  return DropdownMenuItem(
                    value: teacherDoc.id,
                    child: Text(teacherName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTeacherId = value;
                    if (value != null) {
                      final teacherDoc = availableTeachers.firstWhere(
                        (doc) => doc.id == value,
                      );
                      final teacherData = teacherDoc.data();
                      selectedTeacherName =
                          teacherData['name'] ?? 'Unknown Teacher';
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: selectedTeacherId == null
                  ? null
                  : () async {
                      try {
                        // Reassign all courses to the selected teacher
                        for (final courseDoc in courses) {
                          await FirebaseFirestore.instance
                              .collection('courses')
                              .doc(courseDoc.id)
                              .update({
                            'teacherId': selectedTeacherId,
                            'teacherName': selectedTeacherName,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        }

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Successfully reassigned ${courses.length} course${courses.length == 1 ? '' : 's'} to $selectedTeacherName',
                            ),
                            backgroundColor: Colors.green[600],
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error reassigning courses: $e'),
                            backgroundColor: Colors.red[600],
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTeacher(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Delete Teacher',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this teacher? This action cannot be undone.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Teacher deleted successfully!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'teacher')
              .snapshots(),
          builder: (context, snapshot) {
            List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];
            // Pair each user data with its doc reference
            List<Map<String, dynamic>> users = docs
                .map((doc) => {
                      ...((doc.data() ?? {}) as Map<String, dynamic>),
                      '_reference': doc.reference,
                    })
                .toList();

            // Search and filter logic
            List<Map<String, dynamic>> filteredUsers = users;
            if (_searchQuery.isNotEmpty) {
              filteredUsers = filteredUsers
                  .where((u) =>
                      (u['name'] ?? '').toLowerCase().contains(_searchQuery) ||
                      (u['email'] ?? '').toLowerCase().contains(_searchQuery))
                  .toList();
            }
            if (_selectedStatus != null) {
              filteredUsers = filteredUsers
                  .where((u) => (u['active'] ?? true) == _selectedStatus)
                  .toList();
            }

            // Update total items count
            _totalItems = filteredUsers.length;

            // Pagination logic
            final startIndex = (_currentPage - 1) * _itemsPerPage;
            final endIndex = startIndex + _itemsPerPage;
            final paginatedUsers = filteredUsers.sublist(
              startIndex,
              endIndex > filteredUsers.length ? filteredUsers.length : endIndex,
            );

            return Column(
              children: [
                // Green header, centered, NotoSans font
                Container(
                  color: Colors.green[500],
                  padding:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 24),
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: title
                      Text(
                        '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NotoSans',
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Right side: search bar, status dropdown, and add button
                      Row(
                        children: [
                          Container(
                            width: 180,
                            constraints: const BoxConstraints(maxWidth: 200),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.10),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                  color: const Color(0xFF58B74A), width: 1.2),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search users...',
                                  hintStyle: TextStyle(
                                      fontSize: 13,
                                      color:
                                          const Color.fromARGB(255, 0, 0, 0)),
                                  prefixIcon: Icon(Icons.search,
                                      color: Colors.black, size: 18),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Color(0xFF58B74A), width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Color(0xFF58B74A), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Color(0xFF58B74A), width: 2),
                                  ),
                                ),
                                style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontSize: 14,
                                    color: Color.fromARGB(255, 0, 0, 0)),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value.trim().toLowerCase();
                                    _currentPage =
                                        1; // Reset to first page when searching
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Removed DropdownButton for status filtering and its SizedBox spacing
                          // Register Teacher button (replaces IconButton)
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return Dialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: SizedBox(
                                      width: 500,
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: _RegisterTeacherForm(
                                          onRegistered: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.person_add,
                                color: Colors.white),
                            label: const Text('Register Teacher'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              elevation: 2,
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // DataTable for users
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            headingRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                                    (states) => Colors.green[50]),
                            dataRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                                    (states) => Colors.white),
                            headingTextStyle: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'NotoSans',
                            ),
                            dataTextStyle: const TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            columns: const [
                              DataColumn(
                                  label: Text('Name',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                              DataColumn(
                                  label: Text('Email',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                              DataColumn(
                                  label: Text('Role',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                              DataColumn(
                                  label: Text('Status',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                              DataColumn(
                                  label: Text('Remark',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                              DataColumn(
                                  label: Text('Actions',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                            ],
                            rows: paginatedUsers.map((user) {
                              final docRef = user['_reference'];
                              final remark = user['remark'] ?? '-';
                              return DataRow(
                                cells: [
                                  DataCell(Text(user['name'] ?? 'Unknown',
                                      style: const TextStyle(fontSize: 14))),
                                  DataCell(Text(user['email'] ?? '',
                                      style: const TextStyle(fontSize: 14))),
                                  DataCell(Text(user['role'] ?? '',
                                      style: const TextStyle(fontSize: 14))),
                                  DataCell(Row(
                                    children: [
                                      Icon(
                                        (user['active'] ?? true)
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: (user['active'] ?? true)
                                            ? Colors.green
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        (user['active'] ?? true)
                                            ? 'Active'
                                            : 'Inactive',
                                        style: TextStyle(
                                          color: (user['active'] ?? true)
                                              ? Colors.green[700]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'NotoSans',
                                        ),
                                      ),
                                    ],
                                  )),
                                  DataCell(Text(remark,
                                      style: const TextStyle(fontSize: 14))),
                                  DataCell(Row(
                                    children: [
                                      Tooltip(
                                        message: 'Assign Courses',
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: IconButton(
                                            icon: const Icon(Icons.book,
                                                color: Colors.blue),
                                            onPressed: () async {
                                              final snapshot =
                                                  await docRef.get();
                                              _assignCourses(snapshot);
                                            },
                                            splashRadius: 20,
                                            hoverColor: Colors.blue[50],
                                          ),
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Remarks',
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert,
                                                color: Colors.orange),
                                            tooltip: 'Set Remark',
                                            onSelected: (String value) async {
                                              // Determine active status based on remarks
                                              bool isActive = value == 'Active';

                                              await docRef.update({
                                                'remark': value,
                                                'active': isActive,
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                              });

                                              // If teacher is marked as "Retired", "Transferred", "Resigned", or "Others", reassign their courses
                                              if (value == 'Retired' ||
                                                  value == 'Transferred' ||
                                                  value == 'Resigned' ||
                                                  value == 'Others') {
                                                final teacherId = docRef.id;
                                                final teacherName =
                                                    user['name'] ??
                                                        'Unknown Teacher';

                                                print(
                                                    'Teacher marked as $value: $teacherName (ID: $teacherId)');

                                                // Check if teacher has assigned courses
                                                final coursesSnapshot =
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('courses')
                                                        .where('teacherId',
                                                            isEqualTo:
                                                                teacherId)
                                                        .get();

                                                // Also check for courses in the user's courses array
                                                final userCourses =
                                                    user['courses']
                                                            as List<dynamic>? ??
                                                        [];
                                                print(
                                                    'User courses array: $userCourses');

                                                print(
                                                    'Found ${coursesSnapshot.docs.length} courses for $value teacher');

                                                if (coursesSnapshot
                                                        .docs.isNotEmpty ||
                                                    userCourses.isNotEmpty) {
                                                  // Show course selection dialog for reassignment
                                                  final selectedCourses =
                                                      await _showCourseSelectionDialog(
                                                    teacherName,
                                                    coursesSnapshot.docs,
                                                  );

                                                  print(
                                                      'Selected courses for reassignment: ${selectedCourses?.length ?? 0}');

                                                  if (selectedCourses != null &&
                                                      selectedCourses
                                                          .isNotEmpty) {
                                                    // Reassign selected courses to another teacher
                                                    await _reassignSelectedCourses(
                                                        teacherId,
                                                        teacherName,
                                                        selectedCourses);
                                                  } else {
                                                    // If none selected, assign all courses to current admin
                                                    await _assignCoursesToAdmin(
                                                        coursesSnapshot.docs);
                                                  }
                                                } else {
                                                  print(
                                                      'No courses found for $value teacher');
                                                }
                                              }

                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Remark set to: $value, Status: ${isActive ? "Active" : "Inactive"}'),
                                                  backgroundColor: isActive
                                                      ? Colors.green
                                                      : Colors.orange,
                                                ),
                                              );
                                              setState(() {});
                                            },
                                            itemBuilder:
                                                (BuildContext context) => [
                                              const PopupMenuItem(
                                                value: 'Active',
                                                child: Text('Active'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'Retired',
                                                child: Text('Retired'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'Transferred',
                                                child: Text('Transferred'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'Resigned',
                                                child: Text('Resigned'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'Others',
                                                child: Text('Others'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Pagination controls
                if (_totalItems > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Previous
                        ElevatedButton(
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage--)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPage > 1
                                ? Colors.green[600]
                                : Colors.grey[300],
                            foregroundColor: _currentPage > 1
                                ? Colors.white
                                : Colors.grey[600],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: _currentPage > 1 ? 2 : 0,
                          ),
                          child: const Text('Previous',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        // Page label
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Page $_currentPage of ${(_totalItems / _itemsPerPage).ceil()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Next
                        ElevatedButton(
                          onPressed: _currentPage <
                                  (_totalItems / _itemsPerPage).ceil()
                              ? () => setState(() => _currentPage++)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPage <
                                    (_totalItems / _itemsPerPage).ceil()
                                ? Colors.green[600]
                                : Colors.grey[300],
                            foregroundColor: _currentPage <
                                    (_totalItems / _itemsPerPage).ceil()
                                ? Colors.white
                                : Colors.grey[600],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: _currentPage <
                                    (_totalItems / _itemsPerPage).ceil()
                                ? 2
                                : 0,
                          ),
                          child: const Text('Next',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Helper methods for DataTable actions
  bool? _selectedStatus;
}

class _RegisterTeacherForm extends StatefulWidget {
  final VoidCallback onRegistered;
  const _RegisterTeacherForm({required this.onRegistered});

  @override
  State<_RegisterTeacherForm> createState() => _RegisterTeacherFormState();
}

class _RegisterTeacherFormState extends State<_RegisterTeacherForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _obscurePassword = true;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumbers = false;
  bool _hasSpecialChars = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validatePassword(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumbers = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChars = password.contains(RegExp(r'[!@#\$%\^&*(),.?":{}|<>]'));
    });
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green[600] : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? Colors.green[700] : Colors.grey[600],
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  double _getPasswordStrength() {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasNumbers) score++;
    if (_hasSpecialChars) score++;
    return score / 5.0;
  }

  Color _getPasswordStrengthColor() {
    double strength = _getPasswordStrength();
    if (strength <= 0.2) return Colors.red;
    if (strength <= 0.4) return Colors.orange;
    if (strength <= 0.6) return Colors.yellow[700]!;
    if (strength <= 0.8) return Colors.lightGreen;
    return Colors.green;
  }

  String _getPasswordStrengthText() {
    double strength = _getPasswordStrength();
    if (strength <= 0.2) return 'Very Weak';
    if (strength <= 0.4) return 'Weak';
    if (strength <= 0.6) return 'Fair';
    if (strength <= 0.8) return 'Good';
    return 'Strong';
  }

  void _registerTeacher() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isRegistering = true);
    try {
      // Create user with Firebase Auth (this will trigger the email notification function)
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Add user info to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'id': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'teacher',
        'courses': <String>[],
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify admin of new teacher registration
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userCredential.user!.uid,
        'type': 'new_user',
        'title': 'New Teacher Registered',
        'message':
            'A new teacher (${_nameController.text.trim()}, ${_emailController.text.trim()}) has been registered and will receive a welcome email.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Create teacher notification for the newly registered teacher
      await FirebaseFirestore.instance.collection('teacher_notifications').add({
        'teacherId': userCredential.user!.uid,
        'type': 'account_created',
        'title': 'Welcome to CodeQuest!',
        'message':
            'Your teacher account has been created by the administrator. Please check your email for login instructions.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'actionRequired': false,
      });

      // Send welcome email directly to teacher
      final emailSent = await RealEmailService.sendWelcomeEmail(
        teacherName: _nameController.text.trim(),
        teacherEmail: _emailController.text.trim(),
        teacherPassword: _passwordController.text.trim(),
      );

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Teacher registered successfully! Welcome email sent to their inbox.'
                : 'Teacher registered successfully! (Email sending in progress)',
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      widget.onRegistered();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_add,
                color: Colors.green[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Register New Teacher',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                  ),
                  prefixIcon: Icon(Icons.person, color: Colors.green[600]),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter full name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                  ),
                  prefixIcon: Icon(Icons.email, color: Colors.green[600]),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Please enter email address';
                  // Validate teacher email
                  final validationError =
                      TeacherEmailValidationService.validateTeacherEmailSync(v);
                  if (validationError != null) {
                    return validationError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.black87),
                onChanged: _validatePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock, color: Colors.green[600]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'Password must contain at least one uppercase letter';
                  }
                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                    return 'Password must contain at least one lowercase letter';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Password must contain at least one number';
                  }
                  if (!RegExp(r'[!@#\$%\^&*(),.?":{}|<>]').hasMatch(value)) {
                    return 'Password must contain at least one special character';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Password requirements indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password Requirements:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRequirementRow(
                        'At least 8 characters', _hasMinLength),
                    _buildRequirementRow(
                        'Uppercase letter (A-Z)', _hasUppercase),
                    _buildRequirementRow(
                        'Lowercase letter (a-z)', _hasLowercase),
                    _buildRequirementRow('Number (0-9)', _hasNumbers),
                    _buildRequirementRow(
                        'Special character (!@#\$%^&*)', _hasSpecialChars),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Password strength indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Text(
                      'Strength: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _getPasswordStrength(),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getPasswordStrengthColor(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getPasswordStrengthText(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _getPasswordStrengthColor(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _isRegistering
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _registerTeacher,
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text(
                        'Register Teacher',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
