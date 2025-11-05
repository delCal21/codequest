import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart'
    as forum_model;
import 'package:codequest/features/forums/domain/models/comment_model.dart';
import 'package:codequest/features/forums/presentation/bloc/forums_bloc.dart';
import 'package:codequest/features/forums/presentation/widgets/comment_card.dart';
import 'package:codequest/features/forums/presentation/widgets/comment_input.dart';

class ForumDiscussionPage extends StatefulWidget {
  final forum_model.ForumModel forum;
  final String? initialCommentId;

  const ForumDiscussionPage({
    super.key,
    required this.forum,
    this.initialCommentId,
  });

  @override
  State<ForumDiscussionPage> createState() => _ForumDiscussionPageState();
}

class _ForumDiscussionPageState extends State<ForumDiscussionPage> {
  final TextEditingController _commentController = TextEditingController();
  String? _replyingTo;
  String? _replyingToId;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightedCommentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    context.read<ForumsBloc>().add(LoadComments(widget.forum.id));
    if (widget.initialCommentId != null) {
      // Wait for the comments to load and then scroll to the initial comment
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInitialComment();
      });
    }
  }

  void _scrollToInitialComment() {
    if (widget.initialCommentId == null) return;

    // Find the comment card with the initial comment ID
    final context = _highlightedCommentKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startReply(CommentModel comment) {
    setState(() {
      _replyingTo = comment.userFullName;
      _replyingToId = comment.id;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToId = null;
    });
  }

  void _submitComment() {
    if (_commentController.text.trim().isEmpty) return;

    final comment = CommentModel(
      id: '',
      forumId: widget.forum.id,
      userId: 'current_user_id', // TODO: Get from auth service
      userFullName: 'Current User', // TODO: Get from auth service
      userAvatarUrl: null,
      content: _commentController.text.trim(),
      parentCommentId: _replyingToId,
      likes: const [],
      dislikes: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.read<ForumsBloc>().add(AddComment(comment));
    _commentController.clear();
    _cancelReply();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forum.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ForumsBloc, ForumsState>(
              builder: (context, state) {
                if (state is ForumsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ForumsError) {
                  return Center(child: Text(state.message));
                }

                if (state is ForumsLoaded) {
                  final comments = state.comments
                      .where((c) => c.parentCommentId == null)
                      .toList();
                  final replies = state.comments
                      .where((c) => c.parentCommentId != null)
                      .toList();

                  if (comments.isEmpty) {
                    return const Center(
                      child: Text('No comments yet. Be the first to comment!'),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final commentReplies = replies
                          .where((r) => r.parentCommentId == comment.id)
                          .toList();

                      final isHighlighted =
                          comment.id == widget.initialCommentId;
                      return CommentCard(
                        key: isHighlighted ? _highlightedCommentKey : null,
                        comment: comment,
                        replies: commentReplies.cast<CommentModel>(),
                        isHighlighted: isHighlighted,
                        onReply: (comment) => _startReply(comment),
                        onLike: () {
                          context.read<ForumsBloc>().add(
                                LikeComment(
                                  commentId: comment.id,
                                  userId:
                                      'current_user_id', // TODO: Get from auth service
                                ),
                              );
                        },
                        onDislike: () {
                          context.read<ForumsBloc>().add(
                                DislikeComment(
                                  commentId: comment.id,
                                  userId:
                                      'current_user_id', // TODO: Get from auth service
                                ),
                              );
                        },
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          CommentInput(
            controller: _commentController,
            replyingTo: _replyingTo,
            onCancelReply: _cancelReply,
            onSubmit: _submitComment,
          ),
        ],
      ),
    );
  }
}
