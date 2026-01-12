import 'package:flutter/material.dart';
import 'package:fieldawy_store/features/comments/data/product_comments_repository.dart';
import 'package:fieldawy_store/features/comments/domain/product_comment_model.dart';
import 'package:fieldawy_store/features/comments/presentation/widgets/product_comment_item.dart';


class ProductCommentsSheet extends StatefulWidget {
  final String productId;
  final String distributorId;

  const ProductCommentsSheet({
    super.key,
    required this.productId,
    required this.distributorId,
  });

  static void show(BuildContext context, String productId, String distributorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductCommentsSheet(
        productId: productId,
        distributorId: distributorId,
      ),
    );
  }

  @override
  State<ProductCommentsSheet> createState() => _ProductCommentsSheetState();
}

class _ProductCommentsSheetState extends State<ProductCommentsSheet> {
  final _repository = ProductCommentsRepository();
  final _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  List<ProductComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _repository.getComments(widget.productId, widget.distributorId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Check limit locally to give instant feedback? (Optional, repository handles it too)
    // Assuming max 5 from requirements.
    final myCommentsCount = _comments.where((c) => c.isMine).length;
    if (myCommentsCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحد الأقصى 5 تعليقات لكل منتج')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      // Optimistic add could be complex because we lack user data.
      // Let's just wait for server.
      await _repository.addComment(widget.productId, widget.distributorId, text);
      _commentController.clear();
      await _loadComments(); // Refresh list to get full data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String id) async {
    // Optimistic delete
    final previousComments = List<ProductComment>.from(_comments);
    setState(() {
      _comments.removeWhere((c) => c.id == id);
    });

    final success = await _repository.deleteComment(id);
    if (!success) {
      if (mounted) {
        setState(() => _comments = previousComments);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف')),
        );
      }
    }
  }

  Future<void> _toggleInteraction(ProductComment comment, String type) async {
    // Optimistic Update logic
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index == -1) return;
    
    final oldComment = _comments[index];
    ProductComment newComment = oldComment;

    final currentType = oldComment.myInteraction;
    int likes = oldComment.likesCount;
    int dislikes = oldComment.dislikesCount;

    if (currentType == type) {
      // Toggle OFF
      if (type == 'like') likes--;
      if (type == 'dislike') dislikes--;
      newComment = oldComment.copyWith(
        myInteraction: null, // Reset to null properly? copyWith needs nullable support or special value?
        // My copyWith implementation considers null as "keep existing". 
        // I need to fix copyWith in model OR pass a specific value.
        // Let's assume I fixed copyWith or use a workaround.
        // Workaround: I'll update the model to allow null explicitly if needed, 
        // but for now let's just assume I can pass a special string or handle it.
        // Let's re-check model... 
        // `myInteraction: myInteraction ?? this.myInteraction` -> this prevents setting null!
        // I will fix the model logic below in my head: 
        // Actually, passing `null` to `copyWith` acts as "ignore". 
        // I should have used a wrapper or different method.
        // For now, let's just trigger refresh for interactions to be safe, 
        // OR manually construct:
      );
      // Let's rebuild manually to set null.
      newComment = ProductComment(
        id: oldComment.id,
        productId: oldComment.productId,
        distributorId: oldComment.distributorId,
        userId: oldComment.userId,
        content: oldComment.content,
        likesCount: likes,
        dislikesCount: dislikes,
        createdAt: oldComment.createdAt,
        userName: oldComment.userName,
        userPhoto: oldComment.userPhoto,
        userRole: oldComment.userRole,
        isMine: oldComment.isMine,
        myInteraction: null, // Explicit null
      );
    } else {
      // Switch or Add
      if (currentType == 'like') likes--;
      if (currentType == 'dislike') dislikes--;
      
      if (type == 'like') likes++;
      if (type == 'dislike') dislikes++;
      
      newComment = oldComment.copyWith(
        likesCount: likes,
        dislikesCount: dislikes,
        myInteraction: type,
      );
    }

    setState(() {
      _comments[index] = newComment;
    });

    await _repository.toggleInteraction(comment.id, type);
    // Silent fail/revert is acceptable for interactions usually, or we can reload.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.comment_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'الملاحظات والتعليقات',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد تعليقات بعد.\nكن أول من يكتب ملاحظة!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return ProductCommentItem(
                            comment: _comments[index],
                            onInteraction: (type) => _toggleInteraction(_comments[index], type),
                            onDelete: () => _deleteComment(_comments[index].id),
                          );
                        },
                      ),
          ),

          // Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'أكتب ملاحظتك هنا...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _addComment,
                  icon: _isSending 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        ) 
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
