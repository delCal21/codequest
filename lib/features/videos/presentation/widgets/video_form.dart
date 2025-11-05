import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/video_model.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';

class VideoForm extends StatefulWidget {
  final VideoModel? video;
  final String? preSelectedCourseId;
  const VideoForm({Key? key, this.video, this.preSelectedCourseId})
      : super(key: key);

  @override
  State<VideoForm> createState() => _VideoFormState();
}

class _VideoFormState extends State<VideoForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  PlatformFile? _selectedFile;
  PlatformFile? _selectedThumbnail;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _selectedCourseId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  final CollaboratorRepository _collaboratorRepository =
      CollaboratorRepository(FirebaseFirestore.instance);

  @override
  void initState() {
    super.initState();
    if (widget.video != null) {
      _titleController.text = widget.video!.title;
      _descriptionController.text = widget.video!.description;
      _selectedCourseId = widget.video!.courseId;
    } else if (widget.preSelectedCourseId != null) {
      _selectedCourseId = widget.preSelectedCourseId;
    }
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    // Fetch owned courses
    final ownedSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: currentUser.uid)
        .get();
    final courseDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    courseDocs.addAll(ownedSnapshot.docs);
    // Fetch collaborated courses
    final collaboratorCourseIds =
        await _collaboratorRepository.getCollaboratorCourses(currentUser.uid);
    if (collaboratorCourseIds.isNotEmpty) {
      final collabSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where(FieldPath.documentId, whereIn: collaboratorCourseIds)
          .get();
      courseDocs.addAll(collabSnapshot.docs);
    }
    setState(() {
      _courses = courseDocs;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        // File size check: 30MB max
        const maxFileSize = 30 * 1024 * 1024; // 30MB
        if (file.size > maxFileSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File is too large. Maximum allowed size is 30MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        setState(() {
          _selectedFile = file;
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

  Future<String?> _uploadVideoToStorage(PlatformFile file) async {
    if (file.bytes == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File data is missing. Please re-select the file.'),
        ),
      );
      return null;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      // Explicitly use the correct bucket
      const bucketName = 'codequest-a5317.firebasestorage.app';
      // print('Using Firebase Storage bucket: $bucketName');
      final storage = FirebaseStorage.instanceFor(
        bucket: bucketName,
      );
      final storageRef = storage.ref().child('videos/$fileName');

      // Create metadata
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'originalName': file.name,
          'uploadTime': timestamp.toString(),
        },
      );

      // Start upload
      final uploadTask = storageRef.putData(file.bytes!, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (!mounted) return;
        setState(() {
          _uploadProgress = progress;
        });
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('Upload completed, getting download URL...');

      // Get download URL
      final url = await snapshot.ref.getDownloadURL();
      print('Download URL: $url');
      return url;
    } catch (e) {
      print('Upload error: ${e.toString()}');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedThumbnail = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking thumbnail: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadThumbnailToStorage(PlatformFile file) async {
    if (file.bytes == null) return null;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      const bucketName = 'codequest-a5317.firebasestorage.app';
      final storage = FirebaseStorage.instanceFor(bucket: bucketName);
      final fileName = '${timestamp}_${file.name}';
      final storageRef = storage.ref().child('video_thumbnails/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {
          'originalName': file.name,
          'uploadTime': timestamp.toString(),
        },
      );
      final uploadTask = storageRef.putData(file.bytes!, metadata);
      await uploadTask;
      final url = await storageRef.getDownloadURL();
      return url;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thumbnail upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Thumbnail upload error: $e');
      return null;
    }
  }

  Future<void> _saveVideo() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.video == null && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file.')),
      );
      return;
    }
    if (_selectedCourseId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course for this video.')),
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated.')),
        );
        setState(() => _isUploading = false);
        return;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      final teacherName =
          userData?['displayName'] as String? ?? 'Unknown Teacher';

      String? videoUrl = widget.video?.videoUrl;
      String? thumbnailUrl = widget.video?.thumbnailUrl;

      if (_selectedFile != null) {
        videoUrl = await _uploadVideoToStorage(_selectedFile!);
        if (videoUrl == null) {
          setState(() => _isUploading = false);
          return;
        }
      }

      if (_selectedThumbnail != null) {
        thumbnailUrl = await _uploadThumbnailToStorage(_selectedThumbnail!);
      }

      final video = VideoModel(
        id: widget.video?.id ??
            FirebaseFirestore.instance.collection('videos').doc().id,
        title: _titleController.text,
        description: _descriptionController.text,
        teacherId: currentUser.uid,
        teacherName: teacherName,
        videoUrl: videoUrl!,
        fileName: _selectedFile?.name ?? widget.video?.fileName ?? '',
        mediaType: 'video/mp4',
        createdAt: widget.video?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isPublished: true,
        duration: 0,
        thumbnailUrl: thumbnailUrl,
        courseId: _selectedCourseId,
      );

      await FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .set(video.toJson());

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Video ${widget.video == null ? 'added' : 'updated'} successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving video: ${e.toString()}')),
      );
    } finally {
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      widget.video == null ? Icons.video_library : Icons.edit,
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
                          widget.video == null
                              ? 'Upload New Video'
                              : 'Edit Video',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          widget.video == null
                              ? 'Add a new video to your course'
                              : 'Update video information and settings',
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

              // Video Details
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Video Title',
                    hintText: 'Enter video title',
                    prefixIcon: Icon(Icons.title, color: Colors.green[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a title' : null,
                ),
              ),

              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Video Description',
                    hintText: 'Describe what this video covers',
                    prefixIcon:
                        Icon(Icons.description, color: Colors.green[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  maxLines: 3,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter a description'
                      : null,
                ),
              ),

              // Course Selection
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: DropdownButtonFormField<String>(
                  value: _selectedCourseId,
                  decoration: InputDecoration(
                    labelText: 'Course',
                    hintText: 'Select the course for this video',
                    prefixIcon: Icon(Icons.school, color: Colors.green[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  items: _courses
                      .map((doc) => DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['title'] ?? doc.id),
                          ))
                      .toList(),
                  onChanged: _isUploading
                      ? null
                      : (val) => setState(() => _selectedCourseId = val),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Please select a course'
                      : null,
                ),
              ),

              // Video Upload Section
              Container(
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
                        Icon(Icons.video_library,
                            color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Video File',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload an MP4 video (max 30MB)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _pickVideo,
                            icon: const Icon(Icons.upload_file, size: 20),
                            label: Text(
                              _selectedFile?.name ?? 'Select Video',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[600],
                              side: BorderSide(color: Colors.green[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_selectedFile != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Thumbnail Upload Section
              Container(
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
                        Icon(Icons.image, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Thumbnail (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a custom thumbnail for better preview',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _pickThumbnail,
                            icon: const Icon(Icons.image, size: 20),
                            label: Text(
                              _selectedThumbnail?.name ?? 'Select Thumbnail',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[600],
                              side: BorderSide(color: Colors.green[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_selectedThumbnail != null &&
                            _selectedThumbnail!.bytes != null)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _selectedThumbnail!.bytes!,
                                height: 50,
                                width: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Upload Progress
              if (_isUploading) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_upload,
                              color: Colors.green[600], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Uploading Video...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_uploadProgress * 100).toStringAsFixed(1)}% Complete',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Submit Button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _saveVideo,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.video == null
                          ? Icons.cloud_upload
                          : Icons.save),
                  label: Text(
                    _isUploading
                        ? 'Uploading...'
                        : (widget.video == null
                            ? 'Upload Video'
                            : 'Save Changes'),
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
