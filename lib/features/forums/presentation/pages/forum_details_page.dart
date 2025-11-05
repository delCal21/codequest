import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart';
import 'package:codequest/features/forums/presentation/bloc/forum_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForumDetailsPage extends StatefulWidget {
  final ForumModel forum;

  const ForumDetailsPage({Key? key, required this.forum}) : super(key: key);

  @override
  State<ForumDetailsPage> createState() => _ForumDetailsPageState();
}

class _ForumDetailsPageState extends State<ForumDetailsPage> {
  final _commentController = TextEditingController();
  bool _isLoading = false;
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _fetchUserNames();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _fetchUserNames() async {
    final userIds = {...widget.forum.likes, ...widget.forum.reactions.keys};
    for (var id in userIds) {
      if (!_userNames.containsKey(id)) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();
          if (doc.exists) {
            final data = doc.data();
            if (data != null &&
                data['fullName'] != null &&
                data['fullName'].toString().trim().isNotEmpty) {
              setState(() {
                _userNames[id] = data['fullName'];
              });
            } else {
              setState(() {
                _userNames[id] = 'Unknown';
              });
            }
          } else {
            setState(() {
              _userNames[id] = 'Unknown';
            });
          }
        } catch (e) {
          setState(() {
            _userNames[id] = 'Unknown';
          });
        }
      }
    }
  }

  void _addComment() {
    if (_commentController.text.isEmpty) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to comment')),
      );
      return;
    }

    context.read<ForumBloc>().add(
      AddComment(
        forumId: widget.forum.id,
        content: _commentController.text,
        authorId: authState.user.id,
        authorName: authState.user.name,
      ),
    );

    _commentController.clear();
  }

  void _toggleLike() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like posts')),
      );
      return;
    }

    if (widget.forum.likes.contains(authState.user.id)) {
      context.read<ForumBloc>().add(
        UnlikeForum(widget.forum.id, authState.user.id),
      );
    } else {
      context.read<ForumBloc>().add(
        LikeForum(widget.forum.id, authState.user.id),
      );
    }
  }

  void _sharePost() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to share posts')),
      );
      return;
    }

    context.read<ForumBloc>().add(
      ShareForum(widget.forum.id, authState.user.id),
    );
  }

  void _addReaction(String reactionType) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to react')),
      );
      return;
    }

    if (widget.forum.reactions[authState.user.id] == reactionType) {
      context.read<ForumBloc>().add(
        RemoveReaction(widget.forum.id, authState.user.id),
      );
    } else {
      context.read<ForumBloc>().add(
        AddReaction(widget.forum.id, authState.user.id, reactionType),
      );
    }
  }

  void _deletePost() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      return;
    }

    if (widget.forum.authorId != authState.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own posts')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ForumBloc>().add(DeleteForum(widget.forum.id));
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to forums list
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is Authenticated;
    final currentUserId = isAuthenticated ? authState.user.id : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          if (isAuthenticated && widget.forum.authorId == currentUserId)
            IconButton(icon: const Icon(Icons.delete), onPressed: _deletePost),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.forum.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.forum.authorId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text(
                              'Posted by ...',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          }
                          final data =
                              snapshot.data?.data() as Map<String, dynamic>?;
                          final fullName = data?['fullName'] ?? 'Teacher';
                          return Text(
                            'Posted by $fullName',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${_formatDate(widget.forum.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(widget.forum.content),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          widget.forum.likes.contains(currentUserId)
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: isAuthenticated ? _toggleLike : null,
                        tooltip: 'Like',
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: isAuthenticated ? _sharePost : null,
                        tooltip: 'Share',
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions),
                        onPressed: isAuthenticated
                            ? () => _addReaction('😊')
                            : null,
                        tooltip: 'React',
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'List of users who liked the post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (widget.forum.likes.isNotEmpty) ...[
                    ...widget.forum.likes.map(
                      (id) => Text(
                        _userNames[id] ?? 'Unknown',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const Divider(),
                  const Text(
                    'List of users who reacted',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (widget.forum.reactions.isNotEmpty) ...[
                    ...widget.forum.reactions.entries.map(
                      (entry) => Text(
                        '${_userNames[entry.key] ?? 'Unknown'}: ${entry.value}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const Divider(),
                  const Text(
                    'Comments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (widget.forum.comments.isNotEmpty)
                    ...widget.forum.comments.map(
                      (comment) => ListTile(
                        title: Text(comment.content),
                        subtitle: Text(
                          comment.authorName.isNotEmpty
                              ? comment.authorName
                              : 'Unknown',
                        ),
                      ),
                    ),
                  if (widget.forum.comments.isEmpty)
                    const Text('No comments yet.'),
                  if (isAuthenticated) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Write a comment...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _addComment,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
