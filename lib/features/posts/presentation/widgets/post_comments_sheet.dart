import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/posts/domain/post_comment_model.dart';
import 'package:fieldawy_store/features/posts/application/post_comments_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCommentsSheet extends ConsumerStatefulWidget {
  final String postId;

  const PostCommentsSheet({super.key, required this.postId});

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _commentController = TextEditingController();
  String? _replyingToId;
  String? _replyingToName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.locale.languageCode == 'ar'
                      ? 'التعليقات'
                      : 'Comments',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: CachedNetworkImage(
                    imageUrl:
                        "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Xmark-icon.png",
                    width: 24,
                    height: 24,
                    color: theme.iconTheme.color,
                    placeholder: (context, url) =>
                        const FaIcon(FontAwesomeIcons.xmark),
                    errorWidget: (context, url, error) =>
                        const FaIcon(FontAwesomeIcons.xmark),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Comments list
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('خطأ: $e')),
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Comments-icon.png",
                          width: 64,
                          height: 64,
                          color: Colors.grey[400],
                          placeholder: (context, url) => FaIcon(
                              FontAwesomeIcons.comments,
                              size: 64,
                              color: Colors.grey[400]),
                          errorWidget: (context, url, error) => FaIcon(
                              FontAwesomeIcons.comments,
                              size: 64,
                              color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.locale.languageCode == 'ar'
                              ? 'لا توجد تعليقات بعد'
                              : 'No comments yet',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.locale.languageCode == 'ar'
                              ? 'كن أول من يعلق!'
                              : 'Be the first to comment!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentItem(comments[index], theme, isDark);
                  },
                );
              },
            ),
          ),

          // Reply indicator
          if (_replyingToName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.withValues(alpha: 0.1),
              child: Row(
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Reply-icon.png",
                    width: 18,
                    height: 18,
                    color: Colors.grey,
                    placeholder: (context, url) => const FaIcon(
                        FontAwesomeIcons.reply,
                        size: 18,
                        color: Colors.grey),
                    errorWidget: (context, url, error) => const FaIcon(
                        FontAwesomeIcons.reply,
                        size: 18,
                        color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${context.locale.languageCode == 'ar' ? 'الرد على' : 'Replying to'} $_replyingToName',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: CachedNetworkImage(
                      imageUrl:
                          "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Xmark-icon.png",
                      width: 18,
                      height: 18,
                      color: theme.iconTheme.color,
                      placeholder: (context, url) =>
                          const FaIcon(FontAwesomeIcons.xmark, size: 18),
                      errorWidget: (context, url, error) =>
                          const FaIcon(FontAwesomeIcons.xmark, size: 18),
                    ),
                    onPressed: () {
                      setState(() {
                        _replyingToId = null;
                        _replyingToName = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: context.locale.languageCode == 'ar'
                              ? 'اكتب تعليق...'
                              : 'Write a comment...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl:
                                  "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Paper-Plane-icon.png",
                              width: 20,
                              height: 20,
                              color: Colors.white,
                              placeholder: (context, url) => const FaIcon(
                                  FontAwesomeIcons.paperPlane,
                                  color: Colors.white),
                              errorWidget: (context, url, error) =>
                                  const FaIcon(FontAwesomeIcons.paperPlane,
                                      color: Colors.white),
                            ),
                      onPressed: _isSubmitting ? null : _submitComment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
      PostCommentModel comment, ThemeData theme, bool isDark,
      {int depth = 0}) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(
            left: depth * 24.0,
            top: 12,
            bottom: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                      theme.colorScheme.secondary.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: comment.userPhoto != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: comment.userPhoto!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          (comment.userName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                comment.userName ??
                                    (context.locale.languageCode == 'ar'
                                        ? 'مستخدم'
                                        : 'User'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (comment.userRole == 'doctor') ...[
                                const SizedBox(width: 4),
                                const SizedBox(width: 4),
                                CachedNetworkImage(
                                  imageUrl:
                                      "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Circle-Check-icon.png",
                                  width: 14,
                                  height: 14,
                                  color: Colors.blue,
                                  placeholder: (context, url) => const FaIcon(
                                      FontAwesomeIcons.circleCheck,
                                      size: 14,
                                      color: Colors.blue),
                                  errorWidget: (context, url, error) =>
                                      const FaIcon(FontAwesomeIcons.circleCheck,
                                          size: 14, color: Colors.blue),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment.content,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    // Actions row
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 8),
                      child: Row(
                        children: [
                          Text(
                            timeago.format(comment.createdAt,
                                locale: context.locale.languageCode),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _replyingToId = comment.id;
                                _replyingToName = comment.userName ??
                                    (context.locale.languageCode == 'ar'
                                        ? 'مستخدم'
                                        : 'User');
                              });
                            },
                            child: Text(
                              context.locale.languageCode == 'ar'
                                  ? 'رد'
                                  : 'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          if (comment.isMine) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _deleteComment(comment.id),
                              child: Text(
                                context.locale.languageCode == 'ar'
                                    ? 'حذف'
                                    : 'Delete',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Nested replies
        ...comment.replies.map(
          (reply) => _buildCommentItem(reply, theme, isDark, depth: depth + 1),
        ),
      ],
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(postCommentsProvider(widget.postId).notifier)
        .addComment(content, parentId: _replyingToId);

    setState(() {
      _isSubmitting = false;
      if (success) {
        _commentController.clear();
        _replyingToId = null;
        _replyingToName = null;
      }
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.locale.languageCode == 'ar'
            ? 'حذف التعليق'
            : 'Delete Comment'),
        content: Text(context.locale.languageCode == 'ar'
            ? 'هل أنت متأكد من حذف هذا التعليق؟'
            : 'Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text(context.locale.languageCode == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.locale.languageCode == 'ar' ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(postCommentsProvider(widget.postId).notifier)
          .deleteComment(commentId);
    }
  }
}
