import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ForumsPage extends StatefulWidget {
  const ForumsPage({Key? key}) : super(key: key);

  @override
  State<ForumsPage> createState() => _ForumsPageState();
}

class _ForumsPageState extends State<ForumsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Set<String> _enrolledCourseIds = {};
  final Map<String, String> _courseIdToName = {};
  bool _loadingEnrollments = true;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _fetchEnrolledCourses();
  }

  Future<void> _fetchEnrolledCourses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('enrollments')
        .where('studentId', isEqualTo: user.uid)
        .get();
    // collect unique courseIds from enrollments
    final rawIds = snapshot.docs
        .map((d) => d.data()['courseId'])
        .whereType<String>()
        .toSet();
    final verifiedIds = <String>{};
    // Load course names and filter valid courses
    final futures = rawIds.map((id) async {
      try {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(id)
            .get();
        final data = courseDoc.data();
        if (courseDoc.exists && data != null) {
          final isPublished =
              data['isPublished'] == null || data['isPublished'] == true;
          final isActive = data['active'] == null || data['active'] == true;
          if (isPublished && isActive) {
            verifiedIds.add(id);
            final title = (data['title'] as String?)?.trim();
            _courseIdToName[id] =
                (title != null && title.isNotEmpty) ? title : id;
          }
        }
      } catch (_) {
        // ignore invalid ids
      }
    });
    await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _enrolledCourseIds = verifiedIds;
      _loadingEnrollments = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _postTopic() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post.')),
      );
      return;
    }
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final authorName = userDoc.data()?['name'] ?? user.email ?? 'Unknown';
    await FirebaseFirestore.instance.collection('forums').add({
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'authorId': user.uid,
      'authorName': authorName,
      'likes': <String>[],
      'shares': <String>[],
      'comments': [],
      'reactions': {},
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'courseId': _selectedCourseId ?? '',
      'exclusive': _selectedCourseId != null,
    });
    _titleController.clear();
    _contentController.clear();
    _selectedCourseId = null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forum post created!')),
    );
  }

  Future<void> _toggleLike(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final likes = List<String>.from(doc['likes'] ?? []);
    if (likes.contains(user.uid)) {
      likes.remove(user.uid);
    } else {
      likes.add(user.uid);
    }
    await doc.reference.update({'likes': likes});
  }

  Future<void> _sharePost(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final shares = List<String>.from(doc['shares'] ?? []);
    if (!shares.contains(user.uid)) {
      shares.add(user.uid);
      await doc.reference.update({'shares': shares});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post shared!')),
      );
    }
  }

  void _showCommentDialog(DocumentSnapshot doc) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(labelText: 'Comment'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (commentController.text.trim().isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .get();
                final authorName =
                    userDoc.data()?['name'] ?? user?.email ?? 'Unknown';
                final comments =
                    List<Map<String, dynamic>>.from(doc['comments'] ?? []);
                comments.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'content': commentController.text.trim(),
                  'authorId': user?.uid ?? '',
                  'authorName': authorName,
                  'createdAt': DateTime.now().toIso8601String(),
                  'likes': <String>[],
                  'isDeleted': false,
                });
                print('DEBUG: Adding comment: ${comments.last}');
                await doc.reference.update({'comments': comments});
              }
              Navigator.pop(context);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate());
    } else if (timestamp is String) {
      try {
        final date = DateTime.parse(timestamp);
        return DateFormat('MMM d, yyyy • h:mm a').format(date);
      } catch (_) {
        return timestamp; // fallback: just show the string
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final currentUserId = user?.uid;
    if (_loadingEnrollments) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Forums'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Create Forum Post Button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Create Forum Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // match header green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 1,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Create Forum Post'),
                        content: Form(
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
                                    child:
                                        Text('General (not course exclusive)'),
                                  ),
                                  ..._enrolledCourseIds
                                      .map((id) => DropdownMenuItem(
                                            value: id,
                                            child: Text(
                                              'Course: ' +
                                                  (_courseIdToName[id] ?? id),
                                            ),
                                          )),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCourseId = val;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Course (optional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Title',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter title'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contentController,
                                decoration: const InputDecoration(
                                  labelText: 'Content',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter content'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await _postTopic();
                              Navigator.pop(context);
                            },
                            child: const Text('Post'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Forum Posts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('forums')
                    .where('isDeleted', isEqualTo: false)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No forum posts found.');
                  }
                  final docs = snapshot.data!.docs;
                  // Filter forums for student:
                  // - Show if exclusive=false (or missing)
                  // - Or exclusive=true and courseId in _enrolledCourseIds
                  // - Or courseId is empty (general)
                  final filtered = docs.where((doc) {
                    final p = doc.data() as Map<String, dynamic>;
                    final courseId = p['courseId'] ?? '';
                    final isExclusive = p['exclusive'] ?? false;
                    if (!isExclusive) return true;
                    if (courseId == '') return true;
                    return _enrolledCourseIds.contains(courseId);
                  }).toList();
                  // DEBUG: Print comments for each forum post
                  for (final doc in filtered) {
                    final p = doc.data() as Map<String, dynamic>;
                    print('Forum: ' +
                        (p['title'] ?? '') +
                        ' | Comments: ' +
                        (p['comments']?.toString() ?? 'null'));
                  }
                  if (filtered.isEmpty) {
                    return const Text(
                        'No forum posts available for your courses.');
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final p = doc.data() as Map<String, dynamic>;
                      final likes = List<String>.from(p['likes'] ?? []);
                      final shares = List<String>.from(p['shares'] ?? []);
                      final rawComments =
                          (p['comments'] is List) ? p['comments'] : [];
                      final comments = <Map<String, dynamic>>[];
                      for (var c in rawComments) {
                        if (c is Map<String, dynamic>) {
                          comments.add(c);
                        }
                      }
                      final isLiked = currentUserId != null &&
                          likes.contains(currentUserId);
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    child: Text(
                                      (p['authorName'] ?? 'U')
                                              .toString()
                                              .isNotEmpty
                                          ? p['authorName'][0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['authorName'] ?? 'Unknown',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      Text(
                                        _formatDate(p['createdAt']),
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                p['title'] ?? '',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p['content'] ?? '',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 14),
                              Divider(color: Colors.grey[300]),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isLiked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      color: isLiked
                                          ? Colors.blue
                                          : Colors.grey[700],
                                    ),
                                    onPressed: () => _toggleLike(doc),
                                    tooltip: 'Like',
                                  ),
                                  Text('${likes.length}'),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.share),
                                    onPressed: () => _sharePost(doc),
                                    tooltip: 'Share',
                                  ),
                                  Text('${shares.length}'),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.comment),
                                    onPressed: () => _showCommentDialog(doc),
                                    tooltip: 'Comment',
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${comments.length}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue),
                                    ),
                                  ),
                                  if (currentUserId == p['authorId'])
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      tooltip: 'Delete Post',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title:
                                                const Text('Delete Forum Post'),
                                            content: const Text(
                                                'Are you sure you want to delete this post? This action cannot be undone.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text('Delete',
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await doc.reference
                                              .update({'isDeleted': true});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                  'Forum post deleted.'),
                                              action: SnackBarAction(
                                                label: 'Undo',
                                                onPressed: () async {
                                                  await doc.reference.update(
                                                      {'isDeleted': false});
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                              if (comments.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Comments:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: comments.length,
                                  separatorBuilder: (context, idx) =>
                                      const Divider(height: 16),
                                  itemBuilder: (context, idx) {
                                    try {
                                      final comment = comments[idx];
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            child: Text(
                                              (comment['authorName'] ??
                                                          comment['user'] ??
                                                          'U')
                                                      .toString()
                                                      .isNotEmpty
                                                  ? comment['authorName'] ??
                                                      comment['user'][0]
                                                          .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  comment['authorName'] ??
                                                      comment['user'] ??
                                                      'Unknown',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(comment['content'] ??
                                                    comment['text'] ??
                                                    ''),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    } catch (e, stack) {
                                      debugPrint('Error rendering comment: ' +
                                          e.toString() +
                                          '\n' +
                                          stack.toString());
                                      debugPrint(
                                          'Problematic comment: ${comments[idx]}');
                                      return const SizedBox.shrink();
                                    }
                                  },
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
}
