import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:codequest/features/courses/domain/models/collaborator_model.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';
import 'dart:async';

Future<String?> handleFileUpload(
    PlatformFile file, BuildContext context) async {
  if (file.bytes == null) {
    showCustomSnackBar(
        context, 'File data is missing. Please re-select the file.',
        isError: true);
    return null;
  }
  if (file.name.toLowerCase().endsWith('.pdf') &&
      (file.bytes!.isEmpty || file.bytes!.length < 5)) {
    showCustomSnackBar(context, 'File "${file.name}" is empty or invalid PDF.',
        isError: true);
    return null;
  }
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = '${timestamp}_${file.name}';
  final storage = FirebaseStorage.instanceFor(
    bucket: 'codequest-a5317.firebasestorage.app',
  );
  final storageRef = storage.ref().child('courses/$fileName');
  final metadata = SettableMetadata(
    contentType: file.name.toLowerCase().endsWith('.pdf')
        ? 'application/pdf'
        : 'application/msword',
    customMetadata: {
      'originalName': file.name,
      'uploadTime': timestamp.toString(),
    },
  );
  try {
    final uploadTask = storageRef.putData(file.bytes!, metadata);
    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();
    return url;
  } catch (e) {
    showCustomSnackBar(context, 'File upload failed: $e', isError: true);
    return null;
  }
}

void showCustomSnackBar(BuildContext context, String message,
    {bool isError = false, bool isSuccess = false}) {
  final color = isError
      ? Colors.red[600]
      : isSuccess
          ? Colors.green[600]
          : Colors.blue[600];
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

class CoursesCrudPage extends StatefulWidget {
  const CoursesCrudPage({super.key});

  @override
  State<CoursesCrudPage> createState() => _CoursesCrudPageState();
}

class _CoursesCrudPageState extends State<CoursesCrudPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _courseCodeController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String _searchQuery = '';

  // StreamController for student counts
  final StreamController<Map<String, int>> _studentCountsController =
      StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get studentCountsStream =>
      _studentCountsController.stream;

  @override
  void initState() {
    super.initState();
    _loadAllStudentCounts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseCodeController.dispose();
    _studentCountsController.close();
    super.dispose();
  }

  Future<int> _getStudentCountForCourse(String courseId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('courseId', isEqualTo: courseId)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error fetching student count for course $courseId: $e');
      return 0;
    }
  }

  // New method to load all student counts and update the stream
  Future<void> _loadAllStudentCounts() async {
    final coursesSnapshot =
        await FirebaseFirestore.instance.collection('courses').get();
    final Map<String, int> counts = {};
    for (final doc in coursesSnapshot.docs) {
      final count = await _getStudentCountForCourse(doc.id);
      counts[doc.id] = count;
    }
    _studentCountsController.sink.add(counts);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      // File size check: 50MB max
      const maxFileSize = 50 * 1024 * 1024; // 50MB
      if (file.size > maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'File is too large. Maximum allowed size is 50MB.',
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Please select a file.', isError: true);
      return;
    }
    setState(() => _isUploading = true);
    try {
      // 1. Upload file to Firebase Storage
      final fileUrl = await handleFileUpload(_selectedFile!, context);
      if (fileUrl == null) {
        setState(() => _isUploading = false);
        return;
      }
      // 2. Prepare course data
      final fileName = _selectedFile!.name;
      final fileType =
          _selectedFile!.name.toLowerCase().endsWith('.pdf') ? 'pdf' : 'doc';
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        showCustomSnackBar(context, 'User not authenticated.', isError: true);
        setState(() => _isUploading = false);
        return;
      }
      // Get admin name from user document
      String adminName = 'Admin';
      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final adminData = adminDoc.data();
        if (adminData != null) {
          adminName = adminData['name'] ??
              adminData['fullName'] ??
              currentUser.displayName ??
              'Admin';
          if (adminName.trim().isEmpty) adminName = 'Admin';
        }
      } catch (e) {
        adminName = currentUser.displayName ?? 'Admin';
      }

      final data = {
        'title': _titleController.text.trim(),
        'courseCode': _courseCodeController.text.trim(),
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileType': fileType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'teacherId': currentUser.uid,
        'teacherName': adminName,
      };
      await FirebaseFirestore.instance.collection('courses').add(data);
      if (!mounted) return;
      showCustomSnackBar(context, 'Course created successfully!',
          isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _courseCodeController.clear();
    setState(() {
      _selectedFile = null;
    });
  }

  Future<void> _deleteCourse(DocumentSnapshot doc) async {
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
              'Delete Course',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this course? This action cannot be undone.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
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
      showCustomSnackBar(context, 'Course deleted successfully!',
          isSuccess: true);
    }
  }

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    _titleController.text = data['title'];
    _courseCodeController.text = data['courseCode'];
    _selectedFile = null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Edit Course',
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _courseCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Course code is required' : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    side: BorderSide(color: Colors.blue[600]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _selectedFile == null
                        ? 'Change File (Optional)'
                        : _selectedFile!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearForm();
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => _updateCourse(doc.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCourse(String courseId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    try {
      String? fileUrl;
      String fileName = '';
      String fileType = '';

      if (_selectedFile != null) {
        // Upload new file
        fileUrl = await handleFileUpload(_selectedFile!, context);
        if (fileUrl == null) {
          setState(() => _isUploading = false);
          return;
        }
        fileName = _selectedFile!.name;
        fileType =
            _selectedFile!.name.toLowerCase().endsWith('.pdf') ? 'pdf' : 'doc';
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        showCustomSnackBar(context, 'User not authenticated.', isError: true);
        setState(() => _isUploading = false);
        return;
      }

      // Get admin name from user document
      String adminName = 'Admin';
      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final adminData = adminDoc.data();
        if (adminData != null) {
          adminName = adminData['name'] ??
              adminData['fullName'] ??
              currentUser.displayName ??
              'Admin';
          if (adminName.trim().isEmpty) adminName = 'Admin';
        }
      } catch (e) {
        adminName = currentUser.displayName ?? 'Admin';
      }

      final updateData = {
        'title': _titleController.text.trim(),
        'courseCode': _courseCodeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'teacherId': currentUser.uid,
        'teacherName': adminName,
      };

      // Only update file info if a new file was selected
      if (_selectedFile != null && fileUrl != null) {
        updateData['fileUrl'] = fileUrl;
        updateData['fileName'] = fileName;
        updateData['fileType'] = fileType;
      }

      await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .update(updateData);

      if (!mounted) return;
      Navigator.pop(context);
      showCustomSnackBar(context, 'Course updated successfully!',
          isSuccess: true);
      _loadAllStudentCounts(); // Refresh student counts
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  // Removed _assignInstructor and _getTeacherName as Assign Instructor action is no longer used

  // Add collaborator to course - using the working teacher implementation
  Future<void> _addCollaborator(DocumentSnapshot courseDoc) async {
    final courseData = courseDoc.data() as Map<String, dynamic>;
    final courseId = courseDoc.id;
    final courseTitle = courseData['title'] ?? 'Untitled Course';

    // Get all teachers
    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .get();

    if (teachersSnapshot.docs.isEmpty) {
      if (!mounted) return;
      showCustomSnackBar(context, 'No teachers found in the system.');
      return;
    }

    // Convert to the format expected by the working teacher implementation
    // Filter to only include active teachers
    final teachers = teachersSnapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? data['displayName'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'active': data['active'] ??
                true, // Use 'active' field to match teacher table
          };
        })
        .where((teacher) => teacher['active'] == true) // Only active teachers
        .toList();

    if (teachers.isEmpty) {
      if (!mounted) return;
      showCustomSnackBar(context, 'No active teachers found in the system.');
      return;
    }

    // Show teacher selection dialog
    final selectedTeacher =
        await _showTeacherSelectionDialog(courseTitle, teachers);
    if (selectedTeacher == null) return;

    // Show role selection dialog
    final selectedRole = await _showRoleSelectionDialog();
    if (selectedRole == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        showCustomSnackBar(
            context, 'You must be logged in to add collaborators.',
            isError: true);
        return;
      }

      // Create a temporary collaborator to get default permissions
      final tempCollaborator = CollaboratorModel(
        id: '',
        userId: selectedTeacher['id'],
        userName: selectedTeacher['name'],
        userEmail: selectedTeacher['email'],
        role: selectedRole,
        addedAt: DateTime.now(),
        addedBy: currentUser.uid,
      );

      final collaborator = CollaboratorModel(
        id: '',
        userId: selectedTeacher['id'],
        userName: selectedTeacher['name'],
        userEmail: selectedTeacher['email'],
        role: selectedRole,
        addedAt: DateTime.now(),
        addedBy: currentUser.uid,
        permissions: tempCollaborator.defaultPermissions,
      );

      final collaboratorRepository =
          CollaboratorRepository(FirebaseFirestore.instance);
      await collaboratorRepository.addCollaborator(courseId, collaborator);

      if (!mounted) return;
      showCustomSnackBar(context,
          '${selectedTeacher['name']} added as collaborator successfully!',
          isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Error adding collaborator: $e',
          isError: true);
    }
  }

  // Teacher selection dialog
  Future<Map<String, dynamic>?> _showTeacherSelectionDialog(
      String courseTitle, List<Map<String, dynamic>> teachers) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.group_add, color: Colors.green[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Select Active Teacher',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'NotoSans',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add a collaborator to:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'NotoSans',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                courseTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'NotoSans',
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: teachers.length,
                  itemBuilder: (context, index) {
                    final teacher = teachers[index];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Text(
                          teacher['name'][0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        teacher['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFamily: 'NotoSans',
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacher['email'],
                            style: const TextStyle(
                              fontFamily: 'NotoSans',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'NotoSans',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => Navigator.pop(context, teacher),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Role selection dialog - copied from teacher implementation
  Future<CollaboratorRole?> _showRoleSelectionDialog() async {
    return showDialog<CollaboratorRole>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CollaboratorRole.values.map((role) {
            return ListTile(
              title: Text(_getRoleDisplayName(role)),
              subtitle: Text(_getRoleDescription(role)),
              onTap: () => Navigator.pop(context, role),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getRoleDescription(CollaboratorRole role) {
    switch (role) {
      case CollaboratorRole.coTeacher:
        return 'Full access to manage course content, students, and collaborators';
      case CollaboratorRole.assistant:
        return 'Can manage content and create challenges, limited student management';
      case CollaboratorRole.moderator:
        return 'Can manage students and view analytics, limited content access';
    }
  }

  // View collaborators for a course
  Future<void> _viewCollaborators(DocumentSnapshot courseDoc) async {
    final courseData = courseDoc.data() as Map<String, dynamic>;
    final courseId = courseDoc.id;
    final courseTitle = courseData['title'] ?? 'Untitled Course';

    final collaboratorRepository =
        CollaboratorRepository(FirebaseFirestore.instance);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.orange[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Course Collaborators',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: FutureBuilder<List<CollaboratorModel>>(
            future: collaboratorRepository.getCourseCollaborators(courseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No collaborators found for this course.');
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    courseTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...snapshot.data!
                      .map((collaborator) => ListTile(
                            leading: CircleAvatar(
                              child:
                                  Text(collaborator.userName[0].toUpperCase()),
                            ),
                            title: Text(collaborator.userName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(collaborator.userEmail),
                                Text(
                                  _getRoleDisplayName(collaborator.role),
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.remove_circle,
                                  color: Colors.red[600]),
                              tooltip: 'Remove Collaborator',
                              onPressed: () =>
                                  _removeCollaborator(courseId, collaborator),
                            ),
                          ))
                      .toList(),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Remove a collaborator from a course
  Future<void> _removeCollaborator(
      String courseId, CollaboratorModel collaborator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text(
            'Are you sure you want to remove ${collaborator.userName} as a collaborator from this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final collaboratorRepository =
            CollaboratorRepository(FirebaseFirestore.instance);

        await collaboratorRepository.removeCollaborator(
            courseId, collaborator.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${collaborator.userName} removed as collaborator'),
              backgroundColor: Colors.green[600],
            ),
          );

          // Close the collaborators dialog and refresh the view
          Navigator.pop(context);
          // Reopen the collaborators dialog to show updated list
          // Note: This is a simple approach. In a production app, you might want to use a state management solution
          // to refresh the dialog content without closing and reopening it.
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing collaborator: ${e.toString()}'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    }
  }

  String _getRoleDisplayName(CollaboratorRole role) {
    switch (role) {
      case CollaboratorRole.coTeacher:
        return 'Co-Teacher';
      case CollaboratorRole.assistant:
        return 'Assistant';
      case CollaboratorRole.moderator:
        return 'Moderator';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xF3F8F1),
      body: SafeArea(
        child: Column(
          children: [
            // Green header bar
            Container(
              color: const Color(0xFF58B74A),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        '',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          fontFamily: 'NotoSans',
                        ),
                      ),
                    ),
                  ),
                  // Search bar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      return Container(
                        width: isWide ? 180 : 120,
                        constraints: const BoxConstraints(maxWidth: 200),
                        margin: const EdgeInsets.only(right: 16),
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
                          child: Semantics(
                            label: 'Search courses',
                            textField: true,
                            child: TextField(
                              autofocus: false,
                              controller:
                                  TextEditingController(text: _searchQuery)
                                    ..selection = TextSelection.collapsed(
                                        offset: _searchQuery.length),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'Search courses...',
                                hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: const Color.fromARGB(255, 0, 0, 0)),
                                prefixIcon: Icon(Icons.search,
                                    color: Colors.black, size: 18),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: Colors.green[300], size: 18),
                                        onPressed: () =>
                                            setState(() => _searchQuery = ''),
                                        tooltip: 'Clear search',
                                      )
                                    : null,
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
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Global actions removed: Assign Instructor
                  // Add Course button (replaces IconButton)
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SizedBox(
                              width: 500,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: _CreateCourseForm(
                                  onCourseCreated: () {
                                    Navigator.of(context).pop();
                                    _loadAllStudentCounts(); // Refresh student counts
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Course'),
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
            ),
            // Table - removed padding and made it expand to fill available space
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('courses')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.all(40),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.green,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No courses found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first course to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title =
                          (data['title'] ?? '').toString().toLowerCase();
                      final courseCode =
                          (data['courseCode'] ?? '').toString().toLowerCase();
                      return _searchQuery.isEmpty ||
                          title.contains(_searchQuery.toLowerCase()) ||
                          courseCode.contains(_searchQuery.toLowerCase());
                    }).toList();
                    // Pagination logic
                    int _currentPage = 0;
                    const int _pageSize = 10;
                    int start = _currentPage * _pageSize;
                    int end = (start + _pageSize) > filteredDocs.length
                        ? filteredDocs.length
                        : (start + _pageSize);
                    List paginated = filteredDocs.sublist(start, end);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: StreamBuilder<Map<String, int>>(
                                    stream: studentCountsStream,
                                    builder: (context, studentCountsSnapshot) {
                                      final studentCounts =
                                          studentCountsSnapshot.data ?? {};
                                      return DataTable(
                                        headingRowColor:
                                            MaterialStateProperty.all(
                                                const Color(0xFFEFF7ED)),
                                        dataRowColor: MaterialStateProperty
                                            .resolveWith<Color?>(
                                                (Set<MaterialState> states) {
                                          if (states.contains(
                                              MaterialState.selected)) {
                                            return Colors.green[100];
                                          }
                                          return null;
                                        }),
                                        columnSpacing:
                                            MediaQuery.of(context).size.width >
                                                    1200
                                                ? 8
                                                : MediaQuery.of(context)
                                                            .size
                                                            .width >
                                                        800
                                                    ? 4
                                                    : 2,
                                        dataRowMinHeight: 40,
                                        columns: [
                                          DataColumn(
                                              label: Text('Title',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16))),
                                          DataColumn(
                                              label: Text('Code',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16))),
                                          DataColumn(
                                              label: Text('Instructor',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16))),
                                          DataColumn(
                                              label: Text('Students',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16))),
                                          DataColumn(
                                              label: Text('Created',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16))),
                                          DataColumn(
                                              label: Text('Status',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16))),
                                          DataColumn(
                                              label: Text('Actions',
                                                  style: TextStyle(
                                                      color: Color.fromARGB(
                                                          255, 0, 0, 0),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16))),
                                        ],
                                        rows: paginated
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final doc = entry.value;
                                          final data = doc.data();
                                          final createdAtRaw =
                                              data['createdAt'];
                                          DateTime? createdAt;
                                          if (createdAtRaw is Timestamp) {
                                            createdAt = createdAtRaw.toDate();
                                          } else if (createdAtRaw is String) {
                                            createdAt =
                                                DateTime.tryParse(createdAtRaw);
                                          } else if (createdAtRaw is DateTime) {
                                            createdAt = createdAtRaw;
                                          }
                                          final teacherName =
                                              data['teacherName'] ?? '';
                                          final assignedByName =
                                              data['assignedByName'] as String?;
                                          final isPublished =
                                              data['isPublished'] == true;
                                          final studentCount =
                                              studentCounts[doc.id] ?? 0;
                                          return DataRow(
                                            color: MaterialStateProperty.all(
                                                Colors.white),
                                            cells: [
                                              DataCell(
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        data['title'] ??
                                                            'Untitled',
                                                        maxLines: 2,
                                                        softWrap: true,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 14),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(Text(
                                                data['courseCode'] ?? '',
                                                maxLines: 2,
                                                softWrap: true,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 14),
                                              )),
                                              DataCell(
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      teacherName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                    if (assignedByName !=
                                                            null &&
                                                        assignedByName
                                                            .trim()
                                                            .isNotEmpty)
                                                      Text(
                                                        'Assigned by: ' +
                                                            assignedByName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(Text(
                                                studentCount.toString(),
                                                style: TextStyle(fontSize: 14),
                                              )),
                                              DataCell(Text(
                                                createdAt != null
                                                    ? DateFormat('yyyy-MM-dd')
                                                        .format(createdAt)
                                                    : '-',
                                                style: TextStyle(fontSize: 14),
                                              )),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        isPublished
                                                            ? 'Published'
                                                            : 'Unpublished',
                                                        style: TextStyle(
                                                          color: isPublished
                                                              ? Colors
                                                                  .green[800]
                                                              : Colors
                                                                  .grey[800],
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    Transform.scale(
                                                      scale:
                                                          0.6, // smaller switch
                                                      child: Switch(
                                                        value: isPublished,
                                                        activeColor:
                                                            Colors.green,
                                                        inactiveThumbColor:
                                                            Colors.grey,
                                                        inactiveTrackColor:
                                                            Colors.grey[300],
                                                        onChanged: (val) async {
                                                          await doc.reference
                                                              .update({
                                                            'isPublished': val
                                                          });
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(val
                                                                  ? 'Set to Published'
                                                                  : 'Set to Unpublished'),
                                                              backgroundColor: val
                                                                  ? Colors.green[
                                                                      600]
                                                                  : Colors.grey[
                                                                      600],
                                                            ),
                                                          );
                                                          setState(() {});
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                PopupMenuButton<String>(
                                                  icon: Icon(
                                                    Icons.more_vert,
                                                    color: Colors.grey[700],
                                                  ),
                                                  tooltip: 'Course Actions',
                                                  onSelected: (value) {
                                                    switch (value) {
                                                      case 'add_collaborator':
                                                        _addCollaborator(doc);
                                                        break;
                                                      case 'view_collaborators':
                                                        _viewCollaborators(doc);
                                                        break;
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'add_collaborator',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.group_add,
                                                              color: Colors
                                                                  .green[700],
                                                              size: 20),
                                                          const SizedBox(
                                                              width: 12),
                                                          const Text(
                                                              'Add Collaborator'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value:
                                                          'view_collaborators',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.people,
                                                              color: Colors
                                                                  .orange[700],
                                                              size: 20),
                                                          const SizedBox(
                                                              width: 12),
                                                          const Text(
                                                              'View Collaborators'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 16, right: 20, bottom: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _currentPage > 0
                                          ? () {
                                              setState(() {
                                                _currentPage--;
                                              });
                                            }
                                          : null,
                                      child: const Text('Previous'),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Page ${_currentPage + 1} of ${((filteredDocs.length / _pageSize).ceil()).clamp(1, 999)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      onPressed: end < filteredDocs.length
                                          ? () {
                                              setState(() {
                                                _currentPage++;
                                              });
                                            }
                                          : null,
                                      child: const Text('Next'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCourseForm extends StatefulWidget {
  final VoidCallback onCourseCreated;
  const _CreateCourseForm({required this.onCourseCreated});

  @override
  State<_CreateCourseForm> createState() => _CreateCourseFormState();
}

class _CreateCourseFormState extends State<_CreateCourseForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _courseCodeController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      // File size check: 50MB max
      const maxFileSize = 50 * 1024 * 1024; // 50MB
      if (file.size > maxFileSize) {
        showCustomSnackBar(
            context, 'File is too large. Maximum allowed size is 50MB.',
            isError: true);
        return;
      }
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Please select a file.', isError: true);
      return;
    }
    setState(() => _isUploading = true);
    try {
      // 1. Upload file to Firebase Storage
      final fileUrl = await handleFileUpload(_selectedFile!, context);
      if (fileUrl == null) {
        setState(() => _isUploading = false);
        return;
      }
      // 2. Prepare course data
      final fileName = _selectedFile!.name;
      final fileType =
          _selectedFile!.name.toLowerCase().endsWith('.pdf') ? 'pdf' : 'doc';
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        showCustomSnackBar(context, 'User not authenticated.', isError: true);
        setState(() => _isUploading = false);
        return;
      }
      // Get admin name from user document
      String adminName = 'Admin';
      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final adminData = adminDoc.data();
        if (adminData != null) {
          adminName = adminData['name'] ??
              adminData['fullName'] ??
              currentUser.displayName ??
              'Admin';
          if (adminName.trim().isEmpty) adminName = 'Admin';
        }
      } catch (e) {
        adminName = currentUser.displayName ?? 'Admin';
      }

      final data = {
        'title': _titleController.text.trim(),
        'courseCode': _courseCodeController.text.trim(),
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileType': fileType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'teacherId': currentUser.uid,
        'teacherName': adminName,
      };
      await FirebaseFirestore.instance.collection('courses').add(data);
      if (!mounted) return;
      showCustomSnackBar(context, 'Course created successfully!',
          isSuccess: true);
      widget.onCourseCreated();
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_box, color: Colors.green[600], size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Create New Course',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF217A3B),
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
                  controller: _titleController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Course Title',
                    labelStyle: TextStyle(color: Colors.green[700]),
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
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    prefixIcon: Icon(Icons.title, color: Colors.green[600]),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter course title'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _courseCodeController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Course Code',
                    labelStyle: TextStyle(color: Colors.green[700]),
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
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    prefixIcon: Icon(Icons.code, color: Colors.green[600]),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter course code'
                      : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: Colors.green[600]!),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _pickFile,
                  icon: Icon(Icons.attach_file, color: Colors.green[600]),
                  label: Text(
                    _selectedFile == null
                        ? 'Select PDF or Word file'
                        : _selectedFile!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
                _isUploading
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
                        onPressed: _saveCourse,
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text(
                          'Create Course',
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
              style: TextButton.styleFrom(
                foregroundColor: Colors.green[700],
              ),
              child: Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getAdminName(String adminId) async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();
      final adminData = adminDoc.data();
      if (adminData == null) return 'Admin';

      String adminName = adminData['name'] ?? adminData['fullName'] ?? 'Admin';
      if (adminName.trim().isEmpty) adminName = 'Admin';
      return adminName;
    } catch (e) {
      return 'Admin';
    }
  }
}
