import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart';
import 'package:codequest/features/forums/presentation/bloc/forum_bloc.dart';
import 'package:codequest/features/forums/presentation/pages/forum_details_page.dart';
import 'package:codequest/features/forums/presentation/pages/forum_form_page.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:codequest/features/forums/data/repositories/forum_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForumsPage extends StatelessWidget {
  final String courseId;
  const ForumsPage({Key? key, required this.courseId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ForumBloc? maybeBloc;
    try {
      maybeBloc = context.read<ForumBloc>();
    } catch (_) {
      maybeBloc = null;
    }
    final child = Scaffold(
      appBar: AppBar(
        title: const Text('Forums'),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is Authenticated) {
                return const SizedBox.shrink();
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<ForumBloc, ForumState>(
        builder: (context, state) {
          if (state is ForumLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ForumLoaded) {
            return _buildForumList(context, state.forums);
          } else if (state is ForumError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text('No forums available'));
        },
      ),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BlocProvider.value(
                  value: context.read<ForumBloc>(),
                  child: ForumFormPage(courseId: courseId),
                ),
              ),
            );
          },
          child: const Icon(Icons.add),
          tooltip: 'Create Forum',
        ),
      ),
    );
    if (maybeBloc == null) {
      final authState = BlocProvider.of<AuthBloc>(context).state;
      final teacherId = authState is Authenticated ? authState.user.id : '';
      return BlocProvider(
        create: (context) =>
            ForumBloc(ForumRepositoryImpl(FirebaseFirestore.instance))
              ..add(LoadForums(courseId: courseId, teacherId: teacherId)),
        child: child,
      );
    } else {
      return child;
    }
  }

  Widget _buildForumList(BuildContext context, List<ForumModel> forums) {
    final authState = BlocProvider.of<AuthBloc>(context).state;
    final currentUserId = authState is Authenticated ? authState.user.id : '';

    return FutureBuilder<List<String>>(
      future: _getEnrolledCourseIds(currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final enrolledCourseIds = snapshot.data!;
        final visibleForums = forums.where((forum) {
          final isExclusive = (forum as dynamic).exclusive == true;
          if (isExclusive && forum.courseId.isNotEmpty) {
            return enrolledCourseIds.contains(forum.courseId);
          }
          return true;
        }).toList();

        if (visibleForums.isEmpty) {
          return const Center(
            child: Text('No forums available. Be the first to post!'),
          );
        }

        return ListView.builder(
          itemCount: visibleForums.length,
          itemBuilder: (context, index) {
            final forum = visibleForums[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  forum.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forum.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Posted by ${forum.authorName.isNotEmpty ? forum.authorName : 'Unknown'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatDate(forum.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.thumb_up,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${forum.likes.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.comment,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${forum.comments.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.share,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${forum.shares.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ForumDetailsPage(forum: forum),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<List<String>> _getEnrolledCourseIds(String userId) async {
    if (userId.isEmpty) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection('enrollments')
        .where('studentId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => doc['courseId'] as String).toList();
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
