import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/courses/presentation/bloc/course_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CourseForm extends StatefulWidget {
  final CourseModel? course;
  final String teacherId;
  final String teacherName;

  const CourseForm({
    Key? key,
    this.course,
    required this.teacherId,
    required this.teacherName,
  }) : super(key: key);

  @override
  State<CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<CourseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;
  late final TextEditingController _categoryController;
  late final TextEditingController _prerequisitesController;
  late final TextEditingController _courseCodeController;
  List<PlatformFile> _selectedFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.course?.title);
    _descriptionController =
        TextEditingController(text: widget.course?.description);
    _durationController =
        TextEditingController(text: widget.course?.duration.toString() ?? '0');
    _categoryController = TextEditingController(text: widget.course?.category);
    _prerequisitesController =
        TextEditingController(text: widget.course?.prerequisites?.join(', '));
    _courseCodeController =
        TextEditingController(text: widget.course?.courseCode);
    // Pre-populate files if editing
    if (widget.course?.files != null && widget.course!.files.isNotEmpty) {
      // No need to pre-populate PlatformFile, just show file names in UI
    }
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

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files
              .where((file) => file.size <= 50 * 1024 * 1024)
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        continue;
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      final storage = FirebaseStorage.instance;
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

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (widget.course == null && _selectedFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one course file'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() {
        _isSubmitting = true;
      });
      try {
        List<Map<String, dynamic>> files = [];
        if (_selectedFiles.isNotEmpty) {
          files = await _uploadFilesToStorage(_selectedFiles);
        } else if (widget.course?.files != null) {
          files = List<Map<String, dynamic>>.from(widget.course!.files);
        }
        final course = CourseModel(
          id: widget.course?.id ?? '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          courseCode: _courseCodeController.text.trim(),
          teacherId: widget.teacherId,
          teacherName: widget.teacherName,
          duration: int.tryParse(_durationController.text) ?? 0,
          category: _categoryController.text.trim(),
          prerequisites: _prerequisitesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          isPublished: widget.course?.isPublished ?? false,
          createdAt: widget.course?.createdAt ?? DateTime.now(),
          files: files,
        );
        if (widget.course == null) {
          context.read<CourseBloc>().add(CreateCourse(course, null));
        } else {
          context.read<CourseBloc>().add(
                UpdateCourse(
                  widget.course!.id,
                  course,
                  selectedFile: null,
                ),
              );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.course == null
                ? 'Course created successfully!'
                : 'Course updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.green[600]),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[400]!),
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.green[50],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file, color: Colors.green[600], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Course Material',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload your course content (PDF, DOC, DOCX)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.course?.files != null && widget.course!.files.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.course!.files
                  .map<Widget>((file) => Row(
                        children: [
                          Icon(Icons.insert_drive_file,
                              color: Colors.green[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ))
                  .toList(),
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.upload_file),
              label: Text(
                  _selectedFiles.isEmpty ? 'Select Files' : 'Change Files'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green[600],
                side: BorderSide(color: Colors.green[300]!),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.course == null ? Icons.add_circle : Icons.edit,
                      color: Colors.green[600],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course == null
                              ? 'Create New Course'
                              : 'Edit Course',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          widget.course == null
                              ? 'Add a new course to your curriculum'
                              : 'Update course information and materials',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Course Title
              _buildFormField(
                controller: _titleController,
                label: 'Course Title',
                icon: Icons.title,
                hintText: 'Enter course title',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a course title';
                  }
                  return null;
                },
              ),

              // Course Code
              _buildFormField(
                controller: _courseCodeController,
                label: 'Course Code',
                icon: Icons.code,
                hintText: 'Enter course code',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a course code';
                  }
                  return null;
                },
              ),

              // Course Description
              _buildFormField(
                controller: _descriptionController,
                label: 'Course Description',
                icon: Icons.description,
                hintText: 'Describe what students will learn in this course',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a course description';
                  }
                  if (value.trim().length < 20) {
                    return 'Description should be at least 20 characters';
                  }
                  return null;
                },
              ),

              // Duration and Category Row
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      controller: _durationController,
                      label: 'Duration (hours)',
                      icon: Icons.schedule,
                      hintText: 'e.g., 10',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter duration';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (int.parse(value) <= 0) {
                          return 'Duration must be greater than 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      controller: _categoryController,
                      label: 'Category',
                      icon: Icons.category,
                      hintText: 'e.g., Programming, Design',
                    ),
                  ),
                ],
              ),

              // Prerequisites
              _buildFormField(
                controller: _prerequisitesController,
                label: 'Prerequisites',
                icon: Icons.school,
                hintText: 'Enter prerequisites separated by commas',
              ),

              // File Upload Section
              _buildFileUploadSection(),

              // Submit Button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.green),
                        )
                      : Icon(widget.course == null ? Icons.add : Icons.save),
                  label: Text(
                    _isSubmitting
                        ? 'Processing...'
                        : (widget.course == null
                            ? 'Create Course'
                            : 'Update Course'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
