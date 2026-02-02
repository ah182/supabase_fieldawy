import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/posts/domain/post_comment_model.dart';
import 'package:fieldawy_store/features/posts/application/posts_provider.dart';

/// Provider for comments of a specific post
final postCommentsProvider = StateNotifierProviderFamily<PostCommentsNotifier,
    AsyncValue<List<PostCommentModel>>, String>(
  (ref, postId) => PostCommentsNotifier(ref, postId),
);

class PostCommentsNotifier
    extends StateNotifier<AsyncValue<List<PostCommentModel>>> {
  final Ref ref;
  final String postId;
  final _supabase = Supabase.instance.client;

  PostCommentsNotifier(this.ref, this.postId)
      : super(const AsyncValue.loading()) {
    fetchComments();
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch all comments for the post (flat list, nested client-side)
  Future<void> fetchComments() async {
    try {
      // Use the comments_with_details view which joins with users table
      final response = await _supabase
          .from('comments_with_details')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final List<PostCommentModel> allComments = (response as List).map((json) {
        return PostCommentModel.fromJson({
          ...json,
          'user_name': json['user_name'],
          'user_photo': json['user_photo'],
          'user_role': json['user_role'],
        }, currentUserId: _currentUserId);
      }).toList();

      // Build nested structure
      final nestedComments = _buildNestedComments(allComments);
      state = AsyncValue.data(nestedComments);
    } catch (e, st) {
      print('❌ Error fetching comments: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Build nested comment structure from flat list
  List<PostCommentModel> _buildNestedComments(
      List<PostCommentModel> allComments) {
    final Map<String, List<PostCommentModel>> repliesMap = {};
    final List<PostCommentModel> topLevelComments = [];

    // Group replies by parent ID
    for (final comment in allComments) {
      if (comment.parentId != null) {
        repliesMap.putIfAbsent(comment.parentId!, () => []);
        repliesMap[comment.parentId!]!.add(comment);
      } else {
        topLevelComments.add(comment);
      }
    }

    // Recursively attach replies to parent comments
    PostCommentModel attachReplies(PostCommentModel comment) {
      final directReplies = repliesMap[comment.id] ?? [];
      final nestedReplies = directReplies.map(attachReplies).toList();
      return comment.copyWithReplies(nestedReplies);
    }

    return topLevelComments.map(attachReplies).toList();
  }

  /// Add a new comment (or reply)
  Future<bool> addComment(String content, {String? parentId}) async {
    try {
      await _supabase.from('post_comments').insert({
        'post_id': postId,
        'user_id': _currentUserId,
        'parent_id': parentId,
        'content': content,
      });

      // Refresh comments
      await fetchComments();

      // Update post comment count
      ref.read(postsProvider.notifier).updateCommentCount(postId, 1);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      // Count how many comments will be deleted (including replies)
      final deleteCount = await _supabase
          .from('post_comments')
          .select()
          .or('id.eq.$commentId,parent_id.eq.$commentId')
          .count(CountOption.exact);

      await _supabase.from('post_comments').delete().eq('id', commentId);

      // Refresh comments
      await fetchComments();

      // Update post comment count
      ref
          .read(postsProvider.notifier)
          .updateCommentCount(postId, -deleteCount.count);

      return true;
    } catch (e) {
      return false;
    }
  }
}
