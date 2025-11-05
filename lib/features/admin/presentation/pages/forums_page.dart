import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForumsPage extends StatefulWidget {
  const ForumsPage({super.key});

  @override
  State<ForumsPage> createState() => _ForumsPageState();
}

class _ForumsPageState extends State<ForumsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // No local _posts; use Firestore

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _postTopic() async {
    final user = FirebaseAuth.instance.currentUser;
    final authorId = user?.uid ?? 'admin';
    final authorName = user?.displayName ?? 'Admin';
    if (!_formKey.currentState!.validate()) return;
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
    });
    _titleController.clear();
    _contentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Forum post created successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddForumDialog() {
    _titleController.clear();
    _contentController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.forum, color: Colors.green[600], size: 24),
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
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(
                      color: Colors.black87,
                      fontFamily: 'NotoSans',
                    ),
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
                    prefixIcon: const Icon(Icons.title, color: Colors.green),
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
                    prefixIcon:
                        const Icon(Icons.description, color: Colors.green),
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
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _postTopic();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
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
          content: Text(likes.contains(user.uid)
              ? 'You liked the post!'
              : 'You unliked the post!'),
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
    final comments = List<Map<String, dynamic>>.from(doc['comments'] ?? []);
    comments.add({'user': 'Admin', 'text': comment});
    await doc.reference.update({'comments': comments});
  }

  Future<void> _moderatePost(DocumentSnapshot doc, String status) async {
    await doc.reference.update({'status': status});
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
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.comment, color: Colors.green, size: 24),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
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
              backgroundColor: Colors.green,
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header
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
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.forum,
                            color: Colors.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Forum Management',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'NotoSans',
                              ),
                            ),
                            Text(
                              'Manage and moderate forum discussions',
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
                        backgroundColor: Colors.green,
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
              // Enhanced Forum Posts Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.article,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Forum Posts & Moderation',
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
                          color: Colors.green,
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
                  final user = FirebaseAuth.instance.currentUser;
                  final adminId = user?.uid;
                  final docs = snapshot.data!.docs;
                  // Filter forums for admin:
                  // - Show if exclusive=false (or missing)
                  // - Or courseId is empty (general)
                  // - Or authored by admin
                  final filtered = docs.where((doc) {
                    final p = doc.data() as Map<String, dynamic>;
                    final courseId = p['courseId'] ?? '';
                    final isExclusive = p['exclusive'] ?? false;
                    final authorId = p['authorId'] ?? '';
                    if (authorId == adminId) return true;
                    if (!isExclusive) return true;
                    if (courseId == '') return true;
                    return false;
                  }).toList();
                  if (filtered.isEmpty) {
                    return Center(
                        child: Text('No forums found for this filter.'));
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
                                        Colors.green.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.green,
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
                                                  'Delete Forum Post'),
                                              content: const Text(
                                                  'Are you sure you want to delete this post? This action cannot be undone.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Forum post deleted successfully!'),
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
                                              Icon(Icons.delete,
                                                  color: Colors.red),
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
                                    color: Colors.green,
                                    onPressed: () => _likePost(doc),
                                  ),
                                  const SizedBox(width: 16),
                                  _ActionButton(
                                    icon: Icons.comment,
                                    label:
                                        '${(p['comments'] as List?)?.length ?? 0}',
                                    color: Colors.green,
                                    onPressed: () => _showCommentDialog(doc),
                                  ),
                                  const SizedBox(width: 16),
                                  _ActionButton(
                                    icon: Icons.share,
                                    label:
                                        '${(p['shares'] is List) ? p['shares'].length : 0}',
                                    color: Colors.green,
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
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
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
                                          (p['comments'] as List).length, (i) {
                                        final c = (p['comments'] as List)[i];
                                        final user = c['user'] ?? '';
                                        final text = c['text'] ?? '';
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.grey[200]!),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
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
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                              // Moderation Actions
                              if (p['status'] == 'Pending') ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.pending,
                                        color: Colors.green[700],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Pending Moderation',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'NotoSans',
                                        ),
                                      ),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _moderatePost(doc, 'Approved'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('Reject'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _moderatePost(doc, 'Rejected'),
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
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
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
