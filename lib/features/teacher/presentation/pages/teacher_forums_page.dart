import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';
import 'package:codequest/core/theme/app_theme.dart';

class TeacherForumsPage extends StatefulWidget {
  const TeacherForumsPage({super.key});

  @override
  State<TeacherForumsPage> createState() => _TeacherForumsPageState();
}

class _TeacherForumsPageState extends State<TeacherForumsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedCourseId;
  bool _isExclusive = false;
  Map<String, String> _teacherCourses = {};
  Map<String, Map<String, bool>> _coursePermissions = {};
  String? _filterCourseId;
  final CollaboratorRepository _collaboratorRepository = CollaboratorRepository(
    FirebaseFirestore.instance,
  );

  @override
  void initState() {
    super.initState();
    _fetchTeacherCourses();
  }

  Future<void> _fetchTeacherCourses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ownedSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: user.uid)
        .get();
    final courses = <String, String>{};
    final coursePermissions = <String, Map<String, bool>>{};
    for (var doc in ownedSnapshot.docs) {
      courses[doc.id] = doc['title'] ?? 'Untitled';
      coursePermissions[doc.id] = {
        'manage_content': true,
      }; // Owner always has permission
    }
    // Fetch collaborated courses
    final collaboratorCourseIds =
        await _collaboratorRepository.getCollaboratorCourses(user.uid);
    if (collaboratorCourseIds.isNotEmpty) {
      final collabSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where(FieldPath.documentId, whereIn: collaboratorCourseIds)
          .get();
      for (var doc in collabSnapshot.docs) {
        final title = doc['title'] ?? 'Untitled';
        final collaboratorDetails = await _collaboratorRepository
            .getCollaboratorDetails(doc.id, user.uid);
        final permissions = collaboratorDetails?.permissions ?? {};
        if (permissions['manage_content'] == true) {
          courses[doc.id] = title;
          coursePermissions[doc.id] = permissions;
        }
      }
    }
    setState(() {
      _teacherCourses = courses;
      _coursePermissions = coursePermissions;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _postTopic() async {
    final user = FirebaseAuth.instance.currentUser;
    final authorId = user?.uid ?? 'teacher';
    String authorName = user?.displayName ?? 'Teacher';
    // Try to get fullName from users collection
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['fullName'] != null &&
            (data['fullName'] as String).trim().isNotEmpty) {
          authorName = data['fullName'];
        }
      }
    }
    print('DEBUG: _postTopic called');
    print('DEBUG: _selectedCourseId:  [32m [1m [4m$_selectedCourseId [0m');
    print('DEBUG: _coursePermissions:  [32m [1m [4m$_coursePermissions [0m');
    // Only check permissions if a course is selected
    if (_selectedCourseId != null && _selectedCourseId!.isNotEmpty) {
      if (!_coursePermissions.containsKey(_selectedCourseId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are not a collaborator or owner for this course.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        print('DEBUG: No permission for selected course');
        return;
      }
      final permissions = _coursePermissions[_selectedCourseId];
      if (permissions == null || permissions['manage_content'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to post in this course.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        print('DEBUG: manage_content permission missing');
        return;
      }
    }
    if (!_formKey.currentState!.validate()) {
      print('DEBUG: Form validation failed');
      return;
    }
    try {
      print('DEBUG: Attempting to add forum post to Firestore');
      await FirebaseFirestore.instance.collection('forums').add({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'likes': <String>[],
        'shares': <String>[],
        'comments': [],
        'createdAt': FieldValue.serverTimestamp(),
        'authorId': authorId,
        'authorName': authorName,
        'isDeleted': false,
        'courseId': _selectedCourseId ?? '',
        'exclusive': _isExclusive,
      });
      print('DEBUG: Forum post added successfully');
      _titleController.clear();
      _contentController.clear();
      if (!mounted) return;
      setState(() {
        _selectedCourseId = null;
        _isExclusive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Forum post created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      print('ERROR: Failed to add forum post: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create forum post: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddForumDialog() {
    _titleController.clear();
    _contentController.clear();
    setState(() {
      _selectedCourseId = null;
      _isExclusive = false;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.forum,
                  color: AppTheme.accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create Forum Post',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSans',
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCourseId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('General (not course exclusive)'),
                    ),
                    ..._teacherCourses.entries.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCourseId = val;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Course (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _isExclusive,
                  onChanged: (val) {
                    setState(() {
                      _isExclusive = val ?? false;
                    });
                  },
                  title: const Text(
                    'Exclusive to enrolled students (and teacher)',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(
                      color: Colors.black87,
                      fontFamily: 'NotoSans',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.accentColor,
                        width: 2,
                      ),
                    ),
                    prefixIcon:
                        const Icon(Icons.title, color: AppTheme.accentColor),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'NotoSans',
                    color: Colors.black87,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    labelStyle: const TextStyle(
                      color: Colors.black87,
                      fontFamily: 'NotoSans',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.accentColor,
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.description,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'NotoSans',
                    color: Colors.black87,
                  ),
                  maxLines: 4,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter content' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black54,
                fontFamily: 'NotoSans',
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _postTopic();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Post Topic',
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _likePost(DocumentSnapshot doc) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final data = doc.data() as Map<String, dynamic>;
      final List<String> likes = List<String>.from(data['likes'] ?? []);
      if (likes.contains(user.uid)) {
        likes.remove(user.uid);
      } else {
        likes.add(user.uid);
      }
      await doc.reference.update({'likes': likes});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            likes.contains(user.uid)
                ? 'You liked the post!'
                : 'You unliked the post!',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to like post: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sharePost(DocumentSnapshot doc) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final data = doc.data() as Map<String, dynamic>;
      final List<String> shares = List<String>.from(data['shares'] ?? []);
      if (!shares.contains(user.uid)) {
        shares.add(user.uid);
        await doc.reference.update({'shares': shares});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already shared this post!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share post: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addComment(DocumentSnapshot doc, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'Teacher';
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['fullName'] != null &&
            (data['fullName'] as String).trim().isNotEmpty) {
          userName = data['fullName'];
        } else if (data['name'] != null &&
            (data['name'] as String).trim().isNotEmpty) {
          userName = data['name'];
        } else if (user.displayName != null &&
            user.displayName!.trim().isNotEmpty) {
          userName = user.displayName!;
        }
      } else if (user.displayName != null &&
          user.displayName!.trim().isNotEmpty) {
        userName = user.displayName!;
      }
    }
    final comments = List<Map<String, dynamic>>.from(doc['comments'] ?? []);
    comments.add({'user': userName, 'text': comment});
    await doc.reference.update({'comments': comments});
  }

  Future<void> _deletePost(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  void _showCommentDialog(DocumentSnapshot doc) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.comment,
                  color: AppTheme.accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Comment',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSans',
              ),
            ),
          ],
        ),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(
            labelText: 'Comment',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.accentColor, width: 2),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.trim().isNotEmpty) {
                await _addComment(doc, commentController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comment added successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final teacherId = user?.uid;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.forum,
                            color: AppTheme.accentColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Forum Discussions',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NotoSans',
                              ),
                            ),
                            Text(
                              'Share and discuss with other teachers',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontFamily: 'NotoSans',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add Forum Post',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _showAddForumDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Removed Course Filter Dropdown section
              const SizedBox(height: 16),
              // Forum Posts Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.article,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Forum Posts',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSans',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('forums')
                    .where('isDeleted', isEqualTo: false)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        child: const CircularProgressIndicator(
                          color: AppTheme.accentColor,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No forum posts found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'NotoSans',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create the first forum post to get started',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                                fontFamily: 'NotoSans',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  // Filter forums for teacher:
                  // - Authored by teacher
                  // - Or for teacher's courses (exclusive or not)
                  // - Or general (courseId is empty)
                  final filtered = docs.where((doc) {
                    final p = doc.data() as Map<String, dynamic>;
                    final courseId = p['courseId'] ?? '';
                    final authorId = p['authorId'] ?? '';
                    final isExclusive = p['exclusive'] ?? false;
                    // Filter by dropdown
                    if (_filterCourseId != null) {
                      if (_filterCourseId == '') {
                        // General
                        if (courseId != '') return false;
                      } else if (courseId != _filterCourseId) {
                        return false;
                      }
                    }
                    // Show if:
                    // - Authored by teacher
                    // - Or for teacher's course
                    // - Or general
                    return authorId == teacherId ||
                        (_teacherCourses.containsKey(courseId)) ||
                        courseId == '';
                  }).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('No forums found for this filter.'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final p = doc.data() as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Post Header
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        AppTheme.accentColor.withOpacity(
                                      0.1,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: AppTheme.accentColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['authorName'] ??
                                              p['user'] ??
                                              "Unknown",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                            fontFamily: 'NotoSans',
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          p['createdAt'] != null
                                              ? _formatDate(p['createdAt'])
                                              : 'Unknown time',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                            fontFamily: 'NotoSans',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (FirebaseAuth.instance.currentUser?.uid ==
                                      p['authorId'])
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) async {
                                        if (value == 'delete') {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const Text(
                                                'Delete Forum Post',
                                              ),
                                              content: const Text(
                                                'Are you sure you want to delete this post? This action cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    context,
                                                    false,
                                                  ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    context,
                                                    true,
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _deletePost(doc);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Forum post deleted successfully!',
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Delete Post'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Post Title
                              Text(
                                p['title'] ?? '',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'NotoSans',
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Post Content
                              if ((p['content'] ?? '').toString().isNotEmpty)
                                Text(
                                  p['content'],
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontFamily: 'NotoSans',
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // Action Buttons
                              Row(
                                children: [
                                  _ActionButton(
                                    icon: Icons.thumb_up,
                                    label:
                                        '${(p['likes'] is List) ? p['likes'].length : 0}',
                                    color: AppTheme.accentColor,
                                    onPressed: () => _likePost(doc),
                                  ),
                                  const SizedBox(width: 16),
                                  _ActionButton(
                                    icon: Icons.comment,
                                    label:
                                        '${(p['comments'] as List?)?.length ?? 0}',
                                    color: AppTheme.accentColor,
                                    onPressed: () => _showCommentDialog(doc),
                                  ),
                                  const SizedBox(width: 16),
                                  _ActionButton(
                                    icon: Icons.share,
                                    label:
                                        '${(p['shares'] is List) ? p['shares'].length : 0}',
                                    color: AppTheme.accentColor,
                                    onPressed: () => _sharePost(doc),
                                  ),
                                ],
                              ),
                              // Comments Section
                              if ((p['comments'] as List?)?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.zero,
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.comment,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Comments (${(p['comments'] as List).length})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                              fontFamily: 'NotoSans',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...List.generate(
                                        (p['comments'] as List).length,
                                        (i) {
                                          final c = (p['comments'] as List)[i];
                                          final user = c['authorName'] ??
                                              c['user'] ??
                                              '';
                                          final text =
                                              c['content'] ?? c['text'] ?? '';
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.grey[200]!,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                      fontFamily: 'NotoSans',
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    text,
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                      fontFamily: 'NotoSans',
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp);
    }
    if (date != null) {
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown time';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontFamily: 'NotoSans',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
