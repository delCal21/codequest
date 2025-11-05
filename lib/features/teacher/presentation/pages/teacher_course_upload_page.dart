import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/courses/presentation/bloc/course_bloc.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';

class TeacherCourseUploadPage extends StatefulWidget {
  final CourseBloc courseBloc;

  const TeacherCourseUploadPage({super.key, required this.courseBloc});

  @override
  State<TeacherCourseUploadPage> createState() =>
      _TeacherCourseUploadPageState();
}

class _TeacherCourseUploadPageState extends State<TeacherCourseUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _categoryController = TextEditingController();
  final _prerequisitesController = TextEditingController();
  final _courseCodeController = TextEditingController();
  PlatformFile? _selectedFile;

  late CourseBloc _courseBloc;

  @override
  void initState() {
    super.initState();
    _courseBloc = widget.courseBloc;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _categoryController.dispose();
    _prerequisitesController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get teacher data
      final teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final teacherData = teacherDoc.data();
      if (teacherData == null) throw Exception('Teacher data not found');

      String teacherName = teacherData['name'] ??
          teacherData['fullName'] ??
          currentUser.displayName ??
          'Teacher';
      if (teacherName.trim().isEmpty) teacherName = 'Teacher';

      // Create course model
      final course = CourseModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        courseCode: _courseCodeController.text.trim(),
        teacherId: currentUser.uid,
        teacherName: teacherName,
        duration: int.tryParse(_durationController.text) ?? 0,
        category: _categoryController.text.trim(),
        prerequisites: _prerequisitesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        isPublished: false,
        createdAt: DateTime.now(),
      );

      // Add CreateCourse event to CourseBloc
      _courseBloc.add(CreateCourse(course, _selectedFile!));

      // Clear form
      _titleController.clear();
      _descriptionController.clear();
      _durationController.clear();
      _categoryController.clear();
      _prerequisitesController.clear();
      _courseCodeController.clear();
      setState(() {
        _selectedFile = null;
      });

      // Navigate back to courses page
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Course'),
        backgroundColor: Colors.green[600],
      ),
      body: BlocListener<CourseBloc, CourseState>(
        bloc: _courseBloc,
        listener: (context, state) {
          if (state is CourseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is CourseLoaded) {
            // Course was successfully created
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Course created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context); // Return to previous screen
          }
        },
        child: BlocBuilder<CourseBloc, CourseState>(
          bloc: _courseBloc,
          builder: (context, state) {
            final isLoading = state is CourseLoading;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.add_circle,
                                  color: Colors.green,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create New Course',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Add a new course to your curriculum',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Course Title
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Course Title',
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.green[600]!, width: 2),
                              ),
                              prefixIcon:
                                  Icon(Icons.title, color: Colors.green[600]),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter course title'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _courseCodeController,
                            decoration: InputDecoration(
                              labelText: 'Course Code',
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.green[600]!, width: 2),
                              ),
                              prefixIcon:
                                  Icon(Icons.code, color: Colors.green[600]),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter course code'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.green[600]!, width: 2),
                              ),
                              prefixIcon: Icon(Icons.description,
                                  color: Colors.green[600]),
                            ),
                            maxLines: 3,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter description'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Duration
                          TextFormField(
                            controller: _durationController,
                            decoration: InputDecoration(
                              labelText: 'Duration (in hours)',
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.green[600]!, width: 2),
                              ),
                              prefixIcon: Icon(Icons.schedule,
                                  color: Colors.green[600]),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter duration';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Category
                          TextFormField(
                            controller: _categoryController,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.green[600]!, width: 2),
                              ),
                              prefixIcon: Icon(Icons.category,
                                  color: Colors.green[600]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Prerequisites
                          TextFormField(
                            controller: _prerequisitesController,
                            decoration: InputDecoration(
                              labelText: 'Prerequisites (comma-separated)',
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.green[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.green[600]!, width: 2),
                              ),
                              prefixIcon:
                                  Icon(Icons.school, color: Colors.green[600]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // File Upload
                          OutlinedButton.icon(
                            onPressed: isLoading ? null : _pickFile,
                            icon: const Icon(Icons.upload_file,
                                color: Colors.green),
                            label: Text(
                              _selectedFile == null
                                  ? 'Select File (PDF, Word, or PowerPoint)'
                                  : _selectedFile!.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[600],
                              side: BorderSide(color: Colors.green[600]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Submit Button
                          ElevatedButton.icon(
                            onPressed: isLoading ? null : _uploadCourse,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save, size: 20),
                            label: const Text(
                              'Create Course',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
