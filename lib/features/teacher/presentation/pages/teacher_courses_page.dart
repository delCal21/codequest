import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/presentation/widgets/collaborator_management_widget.dart';
import 'dart:async';

class TeacherCoursesPage extends StatefulWidget {
  const TeacherCoursesPage({super.key});

  @override
  State<TeacherCoursesPage> createState() => _TeacherCoursesPageState();
}

class _TeacherCoursesPageState extends State<TeacherCoursesPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _courseCodeController = TextEditingController();
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  bool _showAllCourses = false;
  String _searchQuery = '';
  String? _selectedFileTypeFilter;

  late StreamController<List<DocumentSnapshot>> _coursesController;
  StreamSubscription? _myCoursesSubscription;
  StreamSubscription? _collaboratedCoursesSubscription;

  List<DocumentSnapshot> _myCourses = [];
  List<DocumentSnapshot> _collaboratedCourses = [];

  @override
  void initState() {
    super.initState();
    _coursesController = StreamController<List<DocumentSnapshot>>.broadcast();
    _subscribeToCourses();
  }

  void _subscribeToCourses() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final myCoursesStream = FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: currentUser.uid)
        .snapshots();

    final collaboratedCoursesStream = FirebaseFirestore.instance
        .collection('courses')
        .where('collaboratorIds', arrayContains: currentUser.uid)
        .snapshots();

    _myCoursesSubscription = myCoursesStream.listen((snapshot) {
      _myCourses = snapshot.docs;
      _updateCourses();
    });

    _collaboratedCoursesSubscription =
        collaboratedCoursesStream.listen((snapshot) {
      _collaboratedCourses = snapshot.docs;
      _updateCourses();
    });
  }

  void _updateCourses() {
    final allCoursesMap = <String, DocumentSnapshot>{};
    for (var doc in _myCourses) {
      allCoursesMap[doc.id] = doc;
    }
    for (var doc in _collaboratedCourses) {
      allCoursesMap[doc.id] = doc;
    }
    _coursesController.add(allCoursesMap.values.toList());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseCodeController.dispose();
    _coursesController.close();
    _myCoursesSubscription?.cancel();
    _collaboratedCoursesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final files =
          result.files.where((file) => file.size <= 50 * 1024 * 1024).toList();
      final tooLarge =
          result.files.where((file) => file.size > 50 * 1024 * 1024).toList();
      if (tooLarge.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Some files were too large and not added (max 50MB each).'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
      setState(() {
        _selectedFiles = files;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _uploadFilesToStorage(
      List<PlatformFile> files) async {
    List<Map<String, dynamic>> uploaded = [];
    for (final file in files) {
      if (file.bytes == null) continue;
      if (file.name.toLowerCase().endsWith('.pdf') &&
          (file.bytes!.isEmpty || file.bytes!.length < 5)) {
        // Show error and skip invalid PDF
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File "${file.name}" is empty or invalid PDF.'),
            backgroundColor: Colors.red[600],
          ),
        );
        continue;
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
      final uploadTask = storageRef.putData(file.bytes!, metadata);
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      uploaded.add({
        'url': url,
        'name': file.name,
        'type': file.name.split('.').last,
      });
    }
    return uploaded;
  }

  Future<void> _saveCourse(
      {String? docId, List<Map<String, dynamic>>? existingFiles}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);
    try {
      List<Map<String, dynamic>> files = [];

      // If updating an existing course, use the passed existing files or fetch them
      if (docId != null) {
        if (existingFiles != null) {
          files = List<Map<String, dynamic>>.from(existingFiles);
        } else {
          final existingDoc = await FirebaseFirestore.instance
              .collection('courses')
              .doc(docId)
              .get();
          if (existingDoc.exists) {
            final existingData = existingDoc.data() as Map<String, dynamic>;
            files =
                List<Map<String, dynamic>>.from(existingData['files'] ?? []);
          }
        }
      }

      // Add new files if any are selected
      if (_selectedFiles.isNotEmpty) {
        final newFiles = await _uploadFilesToStorage(_selectedFiles);
        files.addAll(newFiles);
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User not authenticated.'),
            backgroundColor: Colors.red[600],
          ),
        );
        if (!mounted) return;
        setState(() => _isUploading = false);
        return;
      }
      // Get teacher name from user document
      String teacherName = 'Teacher';
      try {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final teacherData = teacherDoc.data();
        if (teacherData != null) {
          teacherName = teacherData['name'] ??
              teacherData['fullName'] ??
              currentUser.displayName ??
              'Teacher';
          if (teacherName.trim().isEmpty) teacherName = 'Teacher';
        }
      } catch (e) {
        teacherName = currentUser.displayName ?? 'Teacher';
      }

      final data = {
        'title': _titleController.text.trim(),
        'courseCode': _courseCodeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'teacherId': currentUser.uid,
        'teacherName': teacherName,
        'files': files,
        'isPublished': true, // Set default to published
      };
      if (docId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('courses').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(docId)
            .update(data);
      }
      _clearForm();
      if (docId != null && mounted) {
        Navigator.pop(context); // Close dialog
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Course  ${docId == null ? 'created' : 'updated'} successfully!'),
          backgroundColor: Colors.green[600],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _courseCodeController.clear();
    setState(() {
      _selectedFiles = [];
    });
  }

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    _titleController.text = data['title'];
    _courseCodeController.text = data['courseCode'];
    // Don't set _selectedFiles from existing data as it contains URLs, not PlatformFile objects
    setState(() {
      _selectedFiles = [];
    });

    // Store existing files for display
    final existingFiles = List<Map<String, dynamic>>.from(data['files'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Course'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _courseCodeController,
                  decoration: const InputDecoration(labelText: 'Course Code'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[600],
                    side: BorderSide(color: Colors.green[600]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file, color: Colors.green),
                  label: const Text('Select PDF or Word files'),
                ),
                // Show existing files
                if (existingFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Existing Files:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...existingFiles
                      .map((file) => ListTile(
                            title: Text(file['name'] ?? 'Unknown file'),
                            subtitle: Text(file['type'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () {
                                existingFiles.remove(file);
                              },
                              tooltip: 'Remove file',
                            ),
                          ))
                      .toList(),
                ],
                // Show new files to be uploaded
                if (_selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'New Files to Upload:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._selectedFiles
                      .map((file) => ListTile(
                            title: Text(file.name),
                            subtitle: Text(
                                '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB'),
                            trailing: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.remove(file);
                                });
                              },
                            ),
                          ))
                      .toList(),
                ],
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                _saveCourse(docId: doc.id, existingFiles: existingFiles),
            child: _isUploading
                ? const CircularProgressIndicator()
                : const Text('Update'),
          ),
        ],
      ),
    );
  }

//  header part
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text("Please log in."));
    }
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        title: const Text(
          '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSans',
          ),
        ),
        actions: [
          Row(
            children: [
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
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search courses...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                          prefixIcon: const Icon(Icons.search,
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
                            borderSide: const BorderSide(
                                color: Color(0xFF58B74A), width: 1.2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF58B74A), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF58B74A), width: 2),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      ),
                    ),
                  );
                },
              ),
              // Removed global "Add Collaborator" button; moved to per-row actions
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ElevatedButton.icon(
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
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _coursesController.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No courses found.'));
          }
          final docs = snapshot.data!;
          // Separate my courses and collaborator courses
          final myCourses = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['teacherId'] == currentUser.uid;
          }).toList();
          final collaboratorCourses = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final collaboratorIds = (data['collaboratorIds'] ?? []) as List;
            return data['teacherId'] != currentUser.uid &&
                collaboratorIds.contains(currentUser.uid);
          }).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  docs.isEmpty ? const Text('') : _buildCoursesDataTable(docs),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper to build the DataTable for a list of courses
  Widget _buildCoursesDataTable(List<DocumentSnapshot> docs) {
    final filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final courseCode = (data['courseCode'] ?? '').toString().toLowerCase();
      final fileType = (data['fileType'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery) ||
          courseCode.contains(_searchQuery);
      return matchesSearch;
    }).toList();
    // Pagination logic
    int _currentPage = 0;
    const int _pageSize = 10;
    int start = _currentPage * _pageSize;
    int end = (start + _pageSize) > filteredDocs.length
        ? filteredDocs.length
        : (start + _pageSize);
    List paginated = filteredDocs.sublist(start, end);
    return filteredDocs.isEmpty
        ? const Text('No courses found.')
        : Column(
            children: [
              Container(
                color: Colors.green[50],
                padding: const EdgeInsets.symmetric(horizontal: 0),
                height: 48.0, // Increased header height
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                        child: Padding(
                      padding: EdgeInsets.only(left: 12), // Move right
                      child: Text('Title',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'NotoSans')),
                    )),
                    Expanded(
                        child: Text('Course Code',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'NotoSans'))),
                    // Removed File column
                    Expanded(
                        child: Text('Created',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'NotoSans'))),
                    Expanded(
                        child: Text('Status',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'NotoSans'))),
                    Expanded(
                        child: Text('Actions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'NotoSans'))),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                child: DataTable(
                  headingRowHeight:
                      40.0, // Adjusted header height for better visibility
                  headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                      (states) => Colors.transparent),
                  dataRowColor:
                      MaterialStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.green[100];
                    }
                    return Colors.white;
                  }),
                  columns: const [
                    DataColumn(label: SizedBox.shrink()), // Title
                    DataColumn(label: SizedBox.shrink()), // Course Code
                    // Removed File column
                    DataColumn(label: SizedBox.shrink()), // Created
                    DataColumn(label: SizedBox.shrink()), // Status
                    DataColumn(label: SizedBox.shrink()), // Actions
                  ],
                  rows: paginated.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAtRaw = data['createdAt'];
                    DateTime? createdAt;
                    if (createdAtRaw is Timestamp) {
                      createdAt = createdAtRaw.toDate();
                    } else if (createdAtRaw is String) {
                      createdAt = DateTime.tryParse(createdAtRaw);
                    } else if (createdAtRaw is DateTime) {
                      createdAt = createdAtRaw;
                    }
                    return DataRow(
                      color:
                          MaterialStateProperty.resolveWith<Color?>((states) {
                        return index % 2 == 0
                            ? Colors.white
                            : const Color.fromARGB(255, 255, 255, 255);
                      }),
                      cells: [
                        DataCell(Text(data['title'] ?? 'Untitled')),
                        DataCell(Text(
                          data['courseCode'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )),
                        // Removed File cell
                        DataCell(Text(createdAt != null
                            ? createdAt.toString().substring(0, 10)
                            : 'N/A')),
                        DataCell(Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(),
                              child: Text(
                                (data['isPublished'] == true)
                                    ? 'Published'
                                    : 'Unpublished',
                                style: TextStyle(
                                  color: (data['isPublished'] == true)
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: data['isPublished'] == true,
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor: Colors.grey[300],
                                onChanged: (val) async {
                                  await doc.reference
                                      .update({'isPublished': val});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Course status updated to ' +
                                              (val
                                                  ? 'Published'
                                                  : 'Unpublished')),
                                      backgroundColor: Colors.green[600],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.people,
                                  color: Colors.purple),
                              tooltip: 'Add Collaborator',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SizedBox(
                                      width: 500,
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: CollaboratorManagementWidget(
                                          courseId: doc.id,
                                          courseTitle:
                                              data['title'] ?? 'Untitled',
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit',
                              onPressed: () => _showEditDialog(doc),
                            ),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16, right: 20, bottom: 16),
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
  }

  Widget _buildCourseForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Courses',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Course Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _courseCodeController,
              decoration: const InputDecoration(
                labelText: 'Course Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _buildFilePicker(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading ? null : () => _saveCourse(),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Course'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _pickFiles,
          icon: const Icon(Icons.attach_file),
          label: const Text('Select Course File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.black,
          ),
        ),
        if (_selectedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: _selectedFiles
                  .map((file) => ListTile(
                        title: Text(file.name),
                        subtitle: Text(
                            '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB'),
                        trailing: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedFiles.remove(file);
                            });
                          },
                        ),
                      ))
                  .toList(),
            ),
          )
      ],
    );
  }

  Widget _buildCourseList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text("Please log in."));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error is FirebaseException &&
              (snapshot.error as FirebaseException).code ==
                  'failed-precondition') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Firestore Index Required',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A query requires a special index. Please create it in your Firebase console. The error log contains a direct link to create it.',
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('Error: ${snapshot.error.toString()}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        final showLimit = 5;
        final showButton = docs.length > showLimit;
        final visibleDocs =
            _showAllCourses ? docs : docs.take(showLimit).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Courses',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (showButton)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllCourses = !_showAllCourses;
                        });
                      },
                      child: Text(_showAllCourses ? 'Show Less' : 'Show All'),
                    ),
                ],
              ),
            ),
            if (docs.isEmpty)
              const Center(child: Text('You have not created any courses yet.'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleDocs.length,
                itemBuilder: (context, index) {
                  final doc = visibleDocs[index];
                  return _buildCourseCard(doc);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildCourseCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAtRaw = data['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          data['fileType'] == 'pdf' ? Icons.picture_as_pdf : Icons.description,
          color: Colors.blueAccent,
        ),
        title: Text(data['title']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Created on: ${createdAt?.toLocal().toString().substring(0, 10) ?? 'N/A'}'),
            if (data['collaboratorIds'] != null &&
                (data['collaboratorIds'] as List).isNotEmpty)
              Text(
                '${(data['collaboratorIds'] as List).length} collaborator${(data['collaboratorIds'] as List).length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.people, color: Colors.purple),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CollaboratorManagementWidget(
                      courseId: doc.id,
                      courseTitle: data['title'],
                    ),
                  ),
                );
              },
              tooltip: 'Manage Collaborators',
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(doc),
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
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final files =
          result.files.where((file) => file.size <= 50 * 1024 * 1024).toList();
      final tooLarge =
          result.files.where((file) => file.size > 50 * 1024 * 1024).toList();
      if (tooLarge.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Some files were too large and not added (max 50MB each).'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
      setState(() {
        _selectedFiles = files;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _uploadFilesToStorage(
      List<PlatformFile> files) async {
    List<Map<String, dynamic>> uploaded = [];
    for (final file in files) {
      if (file.bytes == null) continue;
      if (file.name.toLowerCase().endsWith('.pdf') &&
          (file.bytes!.isEmpty || file.bytes!.length < 5)) {
        // Show error and skip invalid PDF
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File "${file.name}" is empty or invalid PDF.'),
            backgroundColor: Colors.red[600],
          ),
        );
        continue;
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
      final uploadTask = storageRef.putData(file.bytes!, metadata);
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      uploaded.add({
        'url': url,
        'name': file.name,
        'type': file.name.split('.').last,
      });
    }
    return uploaded;
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a file.'),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      // 1. Upload file to Firebase Storage
      final files = await _uploadFilesToStorage(_selectedFiles);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User not authenticated.'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        if (!mounted) return;
        setState(() => _isUploading = false);
        return;
      }
      final data = {
        'title': _titleController.text.trim(),
        'courseCode': _courseCodeController.text.trim(),
        'files': files,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'teacherId': currentUser.uid,
        'teacherName': await _getTeacherNameFromDoc(currentUser.uid),
        'isPublished': true,
      };
      await FirebaseFirestore.instance.collection('courses').add(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Course created successfully!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      widget.onCourseCreated();
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
      if (mounted) setState(() => _isUploading = false);
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
                Icons.add_box,
                color: Colors.green[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create New Course',
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
                controller: _titleController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Course Title',
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
                  prefixIcon: Icon(Icons.code, color: Colors.green[600]),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter course code'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[600],
                  side: BorderSide(color: Colors.green[600]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _pickFiles,
                icon: const Icon(Icons.attach_file, color: Colors.green),
                label: const Text('Select PDF or Word files'),
              ),
              if (_selectedFiles.isNotEmpty)
                Column(
                  children: _selectedFiles
                      .map((file) => ListTile(
                            title: Text(file.name),
                            subtitle: Text(
                                '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB'),
                            trailing: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.remove(file);
                                });
                              },
                            ),
                          ))
                      .toList(),
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

  Future<String> _getTeacherNameFromDoc(String teacherId) async {
    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .get();
      final teacherData = teacherDoc.data();
      if (teacherData == null) return 'Teacher';

      String teacherName =
          teacherData['name'] ?? teacherData['fullName'] ?? 'Teacher';
      if (teacherName.trim().isEmpty) teacherName = 'Teacher';
      return teacherName;
    } catch (e) {
      return 'Teacher';
    }
  }

  Future<String> _getTeacherName(String teacherId) async {
    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .get();
      final teacherData = teacherDoc.data();
      if (teacherData == null) return 'Teacher';

      String teacherName =
          teacherData['name'] ?? teacherData['fullName'] ?? 'Teacher';
      if (teacherName.trim().isEmpty) teacherName = 'Teacher';
      return teacherName;
    } catch (e) {
      return 'Teacher';
    }
  }
}
