import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/comments/domain/product_comment_model.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart';

class ProductCommentsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ProductComment>> getComments(String productId, String distributorId) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('get_product_comments', params: {
          'p_product_id': productId,
          'p_distributor_id': distributorId,
        });

        if (response is List) {
          return response.map((e) => ProductComment.fromJson(e)).toList();
        }
        return [];
      } catch (e) {
        print('Error fetching product comments: $e');
        return [];
      }
    });
  }

  Future<ProductComment?> addComment(String productId, String distributorId, String content) async {
    return await NetworkGuard.execute(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) throw Exception('Not authenticated');

        // Call the RPC that handles insertion and limit checking
        // But wait, the RPC just returns the comment row, not the joined user data.
        // We probably want to fetch the fresh list OR handle it locally.
        // For simplicity, let's fetch the fresh list or just return basic info. 
        // Actually, let's update the RPC to return full object OR just fetch again.
        // Let's rely on re-fetching or optimistic updates in UI. 
        // For this method, let's just return success status or simple object.
        
        final response = await _supabase.rpc('add_product_comment', params: {
          'p_product_id': productId,
          'p_distributor_id': distributorId,
          'p_content': content,
        });

        // The RPC returns just the comment row. 
        // We can manually attach current user info if needed, but for now let's just return null and trigger refresh.
        // OR better: construct a ProductComment from the response + current user info.
        
        final row = response as Map<String, dynamic>;
        
        // Fetch fresh user data from public.users to ensure photo is correct
        final userData = await _supabase
            .from('users')
            .select('display_name, photo_url, role')
            .eq('id', userId)
            .maybeSingle();

        return ProductComment(
          id: row['id'],
          productId: row['product_id'],
          distributorId: row['distributor_id'],
          userId: row['user_id'],
          content: row['content'],
          likesCount: 0,
          dislikesCount: 0,
          createdAt: DateTime.parse(row['created_at']),
          userName: userData?['display_name'] ?? 'User',
          userPhoto: userData?['photo_url'],
          userRole: userData?['role'],
          isMine: true,
          myInteraction: null,
        );

      } catch (e) {
        print('Error adding product comment: $e');
        rethrow; // Let UI handle "Limit exceeded" etc.
      }
    });
  }

  Future<bool> deleteComment(String commentId) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.from('product_comments').delete().eq('id', commentId);
        return true;
      } catch (e) {
        print('Error deleting product comment: $e');
        return false;
      }
    });
  }

  Future<bool> toggleInteraction(String commentId, String interactionType) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.rpc('toggle_product_comment_interaction', params: {
          'p_comment_id': commentId,
          'p_interaction_type': interactionType,
        });
        return true;
      } catch (e) {
        print('Error interacting with product comment: $e');
        return false;
      }
    });
  }
}
