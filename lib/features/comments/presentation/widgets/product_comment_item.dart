import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fieldawy_store/features/comments/domain/product_comment_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class ProductCommentItem extends StatelessWidget {
  final ProductComment comment;
  final VoidCallback? onDelete;
  final Function(String type) onInteraction;

  const ProductCommentItem({
    super.key,
    required this.comment,
    this.onDelete,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User Info & Time
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: comment.userPhoto != null
                    ? CachedNetworkImageProvider(comment.userPhoto!)
                    : null,
                child: comment.userPhoto == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName ?? 'Unknown User',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      timeago.format(comment.createdAt, locale: 'ar'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (comment.isMine)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Comment Content
          Text(
            comment.content,
            style: theme.textTheme.bodyMedium,
          ),
          
          const SizedBox(height: 8),
          
          // Actions: Like/Dislike
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Dislike
              _InteractionButton(
                icon: Icons.thumb_down_outlined,
                activeIcon: Icons.thumb_down,
                count: comment.dislikesCount,
                isActive: comment.myInteraction == 'dislike',
                color: Colors.red,
                onTap: () => onInteraction('dislike'),
              ),
              const SizedBox(width: 12),
              // Like
              _InteractionButton(
                icon: Icons.thumb_up_outlined,
                activeIcon: Icons.thumb_up,
                count: comment.likesCount,
                isActive: comment.myInteraction == 'like',
                color: Colors.blue,
                onTap: () => onInteraction('like'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _InteractionButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 16,
              color: isActive ? color : Colors.grey,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
