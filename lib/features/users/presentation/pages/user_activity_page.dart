import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:codequest/features/users/presentation/bloc/users_bloc.dart';
import 'package:codequest/features/videos/domain/models/video_model.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';
import 'package:codequest/features/videos/presentation/pages/video_player_page.dart';
import 'package:codequest/features/forums/presentation/pages/forum_discussion_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserActivityPage extends StatefulWidget {
  final UserModel user;

  const UserActivityPage({
    super.key,
    required this.user,
  });

  @override
  State<UserActivityPage> createState() => _UserActivityPageState();
}

class _UserActivityPageState extends State<UserActivityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<UsersBloc>().add(LoadUserActivity(widget.user.id));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.fullName}\'s Activity'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Videos'),
            Tab(text: 'Forums'),
            Tab(text: 'Comments'),
          ],
        ),
      ),
      body: BlocBuilder<UsersBloc, UsersState>(
        builder: (context, state) {
          if (state is UsersLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is UsersError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context
                          .read<UsersBloc>()
                          .add(LoadUserActivity(widget.user.id));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is UsersLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildVideosList(state.videos),
                _buildForumsList(state.forums),
                _buildCommentsList(state.comments),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildVideosList(List<VideoModel> videos) {
    if (videos.isEmpty) {
      return const Center(
        child: Text('No videos uploaded yet.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.video_library, size: 48),
            title: Text(video.title),
            subtitle: Text(video.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerPage(video: video),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildForumsList(List<forum_model.ForumModel> forums) {
    if (forums.isEmpty) {
      return const Center(
        child: Text('No forums created yet.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: forums.length,
      itemBuilder: (context, index) {
        final forum = forums[index];
        return Card(
          child: ListTile(
            title: Text(forum.title),
            subtitle: Text(
              'Created ${timeago.format(forum.createdAt)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForumDiscussionPage(forum: forum),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCommentsList(List<CommentModel> comments) {
    if (comments.isEmpty) {
      return const Center(
        child: Text('No comments made yet.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Card(
          child: ListTile(
            title: Text(comment.content),
            subtitle: Text(
              'Posted ${timeago.format(comment.createdAt)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              // First, get the forum for this comment
              final forum = await context
                  .read<UsersBloc>()
                  .getForumForComment(comment.forumId);
              if (forum != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ForumDiscussionPage(
                      forum: forum,
                      initialCommentId: comment.id,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
