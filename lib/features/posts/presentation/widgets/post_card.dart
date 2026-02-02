import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/posts/domain/post_model.dart';
import 'package:fieldawy_store/features/posts/application/posts_provider.dart';
import 'package:fieldawy_store/features/posts/presentation/widgets/post_comments_sheet.dart';
import 'package:fieldawy_store/features/posts/presentation/screens/create_post_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCard extends ConsumerWidget {
  final PostModel post;
  final bool isAdmin;

  const PostCard({
    super.key,
    required this.post,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User info
          _buildHeader(context, ref, theme, isDark),

          // Content
          _buildContent(theme),

          // Image (if exists)
          if (post.imageUrl != null) _buildImage(),

          // Stats & Actions
          _buildActions(context, ref, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
            ),
            child: post.userPhoto != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: post.userPhoto!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      (post.userName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Name & Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.userName ??
                          (context.locale.languageCode == 'ar'
                              ? 'مستخدم'
                              : 'User'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (post.userRole == 'doctor') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            SizedBox(width: 4),
                            Text(
                              context.locale.languageCode == 'ar'
                                  ? 'دكتور'
                                  : 'Doctor',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(post.createdAt,
                      locale: context.locale.languageCode),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // More menu
          if (post.isMine || isAdmin)
            PopupMenuButton<String>(
              icon: CachedNetworkImage(
                imageUrl:
                    "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Ellipsis-icon.png",
                width: 18,
                height: 18,
                color: Colors.grey[600],
                placeholder: (context, url) =>
                    FaIcon(FontAwesomeIcons.ellipsis, color: Colors.grey[600]),
                errorWidget: (context, url, error) =>
                    FaIcon(FontAwesomeIcons.ellipsis, color: Colors.grey[600]),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) => _handleMenuAction(context, ref, value),
              itemBuilder: (context) => [
                if (post.isMine) ...[
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Pen-to-Square-icon.png",
                          width: 18,
                          height: 18,
                          color: Colors.blue,
                          placeholder: (context, url) => const FaIcon(
                              FontAwesomeIcons.penToSquare,
                              color: Colors.blue,
                              size: 18),
                          errorWidget: (context, url, error) => const FaIcon(
                              FontAwesomeIcons.penToSquare,
                              color: Colors.blue,
                              size: 18),
                        ),
                        SizedBox(width: 8),
                        Text(context.locale.languageCode == 'ar'
                            ? 'تعديل'
                            : 'Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Trash-Can-icon.png",
                          width: 18,
                          height: 18,
                          color: Colors.red,
                          placeholder: (context, url) => const FaIcon(
                              FontAwesomeIcons.trashCan,
                              color: Colors.red,
                              size: 18),
                          errorWidget: (context, url, error) => const FaIcon(
                              FontAwesomeIcons.trashCan,
                              color: Colors.red,
                              size: 18),
                        ),
                        SizedBox(width: 8),
                        Text(
                            context.locale.languageCode == 'ar'
                                ? 'حذف'
                                : 'Delete',
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                if (!post.isMine)
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Flag-icon.png",
                          width: 18,
                          height: 18,
                          color: Colors.orange,
                          placeholder: (context, url) => const FaIcon(
                              FontAwesomeIcons.flag,
                              color: Colors.orange,
                              size: 18),
                          errorWidget: (context, url, error) => const FaIcon(
                              FontAwesomeIcons.flag,
                              color: Colors.orange,
                              size: 18),
                        ),
                        SizedBox(width: 8),
                        Text(context.locale.languageCode == 'ar'
                            ? 'إبلاغ'
                            : 'Report'),
                      ],
                    ),
                  ),
                if (isAdmin && !post.isMine)
                  PopupMenuItem(
                    value: 'admin_delete',
                    child: Row(
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-User-Shield-icon.png",
                          width: 18,
                          height: 18,
                          color: Colors.red,
                          placeholder: (context, url) => const FaIcon(
                              FontAwesomeIcons.userShield,
                              color: Colors.red,
                              size: 18),
                          errorWidget: (context, url, error) => const FaIcon(
                              FontAwesomeIcons.userShield,
                              color: Colors.red,
                              size: 18),
                        ),
                        SizedBox(width: 8),
                        Text(
                            context.locale.languageCode == 'ar'
                                ? 'حذف (أدمن)'
                                : 'Delete (Admin)',
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        post.content,
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(maxHeight: 300),
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: post.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 200,
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          color: Colors.grey[300],
          child: CachedNetworkImage(
            imageUrl:
                "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Font_Awesome_5_solid_exclamation-circle.svg/512px-Font_Awesome_5_solid_exclamation-circle.svg.png",
            width: 48,
            height: 48,
            color: Colors.grey[400],
            placeholder: (context, url) =>
                const FaIcon(FontAwesomeIcons.circleExclamation),
            errorWidget: (context, url, error) =>
                const FaIcon(FontAwesomeIcons.circleExclamation),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, WidgetRef ref, ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (post.likesCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: CachedNetworkImage(
                    imageUrl:
                        "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Heart-icon.png",
                    width: 12,
                    height: 12,
                    color: Colors.white,
                    placeholder: (context, url) => const FaIcon(
                        FontAwesomeIcons.solidHeart,
                        size: 12,
                        color: Colors.white),
                    errorWidget: (context, url, error) => const FaIcon(
                        FontAwesomeIcons.solidHeart,
                        size: 12,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likesCount}',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
              const Spacer(),
              if (post.commentsCount > 0)
                Text(
                  '${post.commentsCount} ${context.locale.languageCode == 'ar' ? 'تعليق' : 'Comment'}',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
            ],
          ),
        ),

        // Divider
        Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Like button
              Expanded(
                child: _ActionButton(
                  icon: CachedNetworkImage(
                    imageUrl: post.isLikedByMe
                        ? "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Heart-icon.png"
                        : "https://icons.iconarchive.com/icons/fa-team/fontawesome-regular/128/FontAwesome-Regular-Heart-icon.png",
                    width: 18,
                    height: 18,
                    color: post.isLikedByMe ? Colors.red : Colors.grey[600],
                    placeholder: (context, url) => FaIcon(
                      post.isLikedByMe
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.heart,
                      size: 18,
                      color: post.isLikedByMe ? Colors.red : Colors.grey[600],
                    ),
                    errorWidget: (context, url, error) => FaIcon(
                      post.isLikedByMe
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.heart,
                      size: 18,
                      color: post.isLikedByMe ? Colors.red : Colors.grey[600],
                    ),
                  ),
                  label:
                      context.locale.languageCode == 'ar' ? 'أعجبني' : 'Like',
                  color: post.isLikedByMe ? Colors.red : null,
                  onTap: () =>
                      ref.read(postsProvider.notifier).toggleLike(post.id),
                ),
              ),

              // Comment button
              Expanded(
                child: _ActionButton(
                  icon: CachedNetworkImage(
                    imageUrl:
                        "https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Comment-icon.png",
                    width: 18,
                    height: 18,
                    color: Colors.grey[600],
                    placeholder: (context, url) => FaIcon(
                        FontAwesomeIcons.comment,
                        size: 18,
                        color: Colors.grey[600]),
                    errorWidget: (context, url, error) => FaIcon(
                        FontAwesomeIcons.comment,
                        size: 18,
                        color: Colors.grey[600]),
                  ),
                  label:
                      context.locale.languageCode == 'ar' ? 'تعليق' : 'Comment',
                  onTap: () => _showCommentsSheet(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePostScreen(postToEdit: post),
        ),
      );
    } else if (action == 'delete' || action == 'admin_delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.locale.languageCode == 'ar'
              ? 'حذف المنشور'
              : 'Delete Post'),
          content: Text(context.locale.languageCode == 'ar'
              ? 'هل أنت متأكد من حذف هذا المنشور؟'
              : 'Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                  context.locale.languageCode == 'ar' ? 'إلغاء' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                  context.locale.languageCode == 'ar' ? 'حذف' : 'Delete',
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success =
            await ref.read(postsProvider.notifier).deletePost(post.id);
        if (context.mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.locale.languageCode == 'ar'
                    ? 'تم حذف المنشور'
                    : 'Post deleted')),
          );
        }
      }
    } else if (action == 'report') {
      _showReportDialog(context, ref);
    }
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.locale.languageCode == 'ar'
            ? 'إبلاغ عن المنشور'
            : 'Report Post'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.locale.languageCode == 'ar'
                ? 'سبب الإبلاغ...'
                : 'Reason for reporting...',
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(context.locale.languageCode == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref
                    .read(postsProvider.notifier)
                    .reportPost(post.id, controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.locale.languageCode == 'ar'
                            ? 'تم إرسال البلاغ'
                            : 'Report sent')),
                  );
                }
              }
            },
            child:
                Text(context.locale.languageCode == 'ar' ? 'إرسال' : 'Submit'),
          ),
        ],
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostCommentsSheet(postId: post.id),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
