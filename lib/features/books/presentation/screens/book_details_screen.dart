import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../comments/data/comments_repository.dart';
import '../../../comments/domain/comment_model.dart';
import '../../domain/book_model.dart';
import 'package:url_launcher/url_launcher.dart';

class BookDetailsScreen extends ConsumerStatefulWidget {
  final Book book;

  const BookDetailsScreen({
    super.key,
    required this.book,
  });

  @override
  ConsumerState<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends ConsumerState<BookDetailsScreen> {
  final _commentsRepository = CommentsRepository();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAddingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isAddingComment = true);

    final comment = await _commentsRepository.addComment(
      itemId: widget.book.id,
      commentText: _commentController.text,
      type: CommentType.book,
    );

    setState(() => _isAddingComment = false);

    if (comment != null) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إضافة التعليق بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل إضافة التعليق، حاول مرة أخرى'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التعليق'),
        content: const Text('هل أنت متأكد من حذف هذا التعليق؟'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _commentsRepository.deleteComment(
        commentId: commentId,
        type: CommentType.book,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف التعليق'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final message = Uri.encodeComponent('مرحباً، أنا مهتم بالكتاب: ${widget.book.name}');
    final whatsappUrl = 'https://wa.me/$cleanPhone?text=$message';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ===== Header مع صورة الكتاب =====
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // الصورة
                  CachedNetworkImage(
                    imageUrl: widget.book.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // عنوان الكتاب
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.book.author,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== المحتوى الرئيسي =====
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بطاقات الإحصائيات
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.attach_money,
                          label: 'السعر',
                          value: '${widget.book.price.toStringAsFixed(0)} ج.م',
                          color: Colors.green,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.visibility_outlined,
                          label: 'مشاهدات',
                          value: '${widget.book.views}',
                          color: Colors.blue,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: _commentsRepository.getCommentsCount(
                            itemId: widget.book.id,
                            type: CommentType.book,
                          ),
                          builder: (context, snapshot) {
                            return _buildStatCard(
                              icon: Icons.comment_outlined,
                              label: 'تعليقات',
                              value: '${snapshot.data ?? 0}',
                              color: Colors.orange,
                              theme: theme,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // معلومات الكتاب
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // المؤلف
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'المؤلف',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.book.author,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Divider(height: 24),
                        // الوصف
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'وصف الكتاب',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.book.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // زر التواصل
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _openWhatsApp(widget.book.phone),
                      icon: const Icon(Icons.phone_in_talk, color: Colors.white),
                      label: const Text(
                        'تواصل عبر واتساب',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // قسم التعليقات
                _buildCommentsSection(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header التعليقات
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.comment_bank_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'التعليقات',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Input لإضافة تعليق
          _buildCommentInput(theme),

          const SizedBox(height: 16),

          // قائمة التعليقات (محددة بـ 5 تعليقات)
          StreamBuilder<List<Comment>>(
            stream: _commentsRepository.watchComments(
              itemId: widget.book.id,
              type: CommentType.book,
              limit: 5, // تحديد 5 تعليقات فقط
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'حدث خطأ في تحميل التعليقات',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد تعليقات بعد',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'كن أول من يعلق!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return _buildCommentItem(comment, theme);
                },
              );
            },
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCommentInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar المستخدم
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Icon(
              Icons.person,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Input التعليق
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'اكتب تعليقك...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          // زر الإرسال
          _isAddingComment
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: _addComment,
                  icon: Icon(
                    Icons.send_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, ThemeData theme) {
    final currentUserId = _commentsRepository.currentUserId;
    final isOwner = currentUserId == comment.userId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
          backgroundImage: comment.userPhotoUrl != null
              ? CachedNetworkImageProvider(comment.userPhotoUrl!)
              : null,
          child: comment.userPhotoUrl == null
              ? Text(
                  comment.userName?.substring(0, 1).toUpperCase() ?? '؟',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        // محتوى التعليق
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الاسم والوقت
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName ?? 'مستخدم',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      comment.timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // نص التعليق
                Text(
                  comment.commentText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        // زر الحذف (للمستخدم فقط)
        if (isOwner)
          IconButton(
            onPressed: () => _deleteComment(comment.id),
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.red.withOpacity(0.7),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}
