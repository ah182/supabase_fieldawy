import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart';

class ProductInteractionService {
  final SupabaseClient _supabase;

  ProductInteractionService(this._supabase);

  Future<String?> getUserInteraction(String productId, String distributorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await NetworkGuard.execute(() async {
        return await _supabase
            .from('product_interactions')
            .select('interaction_type')
            .eq('user_id', userId)
            .eq('product_id', productId)
            .eq('distributor_id', distributorId)
            .maybeSingle();
      });

      if (response != null) {
        return response['interaction_type'] as String?;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching interaction: $e');
      return null;
    }
  }

  Future<Map<String, int>> getInteractionCounts(String productId, String distributorId) async {
    try {
      final response = await NetworkGuard.execute(() async {
        return await _supabase.rpc('get_interaction_counts', params: {
          'p_id': productId,
          'd_id': distributorId,
        });
      });

      if (response != null) {
        return {
          'likes': response['likes'] as int? ?? 0,
          'dislikes': response['dislikes'] as int? ?? 0,
        };
      }
      return {'likes': 0, 'dislikes': 0};
    } catch (e) {
      print('Error fetching counts: $e');
      return {'likes': 0, 'dislikes': 0};
    }
  }

  Future<void> toggleInteraction({
    required String productId,
    required String distributorId,
    required String interactionType, // 'like' or 'dislike'
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await NetworkGuard.execute(() async {
      // Check if interaction already exists
      final existing = await _supabase
          .from('product_interactions')
          .select()
          .eq('user_id', userId)
          .eq('product_id', productId)
          .eq('distributor_id', distributorId)
          .maybeSingle();

      if (existing != null) {
        final currentType = existing['interaction_type'];
        if (currentType == interactionType) {
          // If clicking same type, remove it (toggle off)
          await _supabase
              .from('product_interactions')
              .delete()
              .eq('id', existing['id']);
        } else {
          // If clicking different type, update it
          await _supabase
              .from('product_interactions')
              .update({'interaction_type': interactionType})
              .eq('id', existing['id']);
        }
      } else {
        // Insert new interaction
        await _supabase.from('product_interactions').insert({
          'user_id': userId,
          'product_id': productId,
          'distributor_id': distributorId,
          'interaction_type': interactionType,
        });
      }
    });
  }
}

final productInteractionServiceProvider = Provider<ProductInteractionService>((ref) {
  return ProductInteractionService(Supabase.instance.client);
});
