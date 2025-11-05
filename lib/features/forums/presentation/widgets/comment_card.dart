import 'package:flutter/material.dart';
import 'package:codequest/features/forums/domain/models/comment_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentCard extends StatelessWidget {
  final CommentModel comment;
  final List<CommentModel> replies;
  final bool isHighlighted;
  final Function(CommentModel) onReply;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const CommentCard({
    super.key,
    required this.comment,
    required this.replies,
    this.isHighlighted = false,
    required this.onReply,
    required this.onLike,
    required this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isHighlighted ? Colors.amber[50] : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: comment.userAvatarUrl != null
                  ? NetworkImage(comment.userAvatarUrl!)
                  : null,
              child: comment.userAvatarUrl == null
                  ? Text(comment.userFullName[0].toUpperCase())
                  : null,
            ),
            title: Text(comment.userFullName),
            subtitle: Text(timeago.format(comment.createdAt)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up_outlined),
                  onPressed: onLike,
                ),
                Text('${comment.likes.length}'),
                IconButton(
                  icon: const Icon(Icons.thumb_down_outlined),
                  onPressed: onDislike,
                ),
                Text('${comment.dislikes.length}'),
                IconButton(
                  icon: const Icon(Icons.reply),
                  onPressed: () => onReply(comment),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(comment.content),
          ),
          if (replies.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: replies.map((reply) {
                  return CommentCard(
                    comment: reply,
                    replies: const [],
                    onReply: onReply,
                    onLike: onLike,
                    onDislike: onDislike,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
