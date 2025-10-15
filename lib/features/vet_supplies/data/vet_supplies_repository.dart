import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VetSuppliesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all active vet supplies
  Future<List<VetSupply>> getAllVetSupplies() async {
    try {
      final response = await _supabase.rpc('get_all_vet_supplies');
      
      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => VetSupply.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch vet supplies: $e');
    }
  }

  // Get current user's vet supplies
  Future<List<VetSupply>> getMyVetSupplies() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase.rpc('get_my_vet_supplies', params: {
        'p_user_id': userId,
      });

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => VetSupply.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch my vet supplies: $e');
    }
  }

  // Create a new vet supply
  Future<String> createVetSupply({
    required String name,
    required String description,
    required double price,
    required String imageUrl,
    required String phone,
  }) async {
    try {
      final response = await _supabase.rpc('create_vet_supply', params: {
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_image_url': imageUrl,
        'p_phone': phone,
      });

      return response as String;
    } catch (e) {
      throw Exception('Failed to create vet supply: $e');
    }
  }

  // Update a vet supply
  Future<bool> updateVetSupply({
    required String id,
    required String name,
    required String description,
    required double price,
    required String imageUrl,
    required String phone,
  }) async {
    try {
      await _supabase.rpc('update_vet_supply', params: {
        'p_supply_id': id,
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_image_url': imageUrl,
        'p_phone': phone,
      });

      return true;
    } catch (e) {
      throw Exception('Failed to update vet supply: $e');
    }
  }

  // Delete a vet supply
  Future<bool> deleteVetSupply(String id) async {
    try {
      await _supabase.rpc('delete_vet_supply', params: {
        'p_supply_id': id,
      });

      return true;
    } catch (e) {
      throw Exception('Failed to delete vet supply: $e');
    }
  }

  // Increment views count
  Future<void> incrementViews(String id) async {
    try {
      await _supabase.rpc('increment_vet_supply_views', params: {
        'p_supply_id': id,
      });
    } catch (e) {
      // Silently fail - views count is not critical
      print('Failed to increment views: $e');
    }
  }

  // ===== ADMIN METHODS =====

  // Admin: Get all vet supplies (including inactive)
  Future<List<VetSupply>> adminGetAllVetSupplies() async {
    try {
      final response = await _supabase
          .from('vet_supplies')
          .select('''
            id,
            user_id,
            name,
            description,
            price,
            image_url,
            phone,
            status,
            views_count,
            created_at,
            updated_at
          ''')
          .order('created_at', ascending: false);

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        final map = json as Map<String, dynamic>;
        // Add empty user_name since we don't need it for admin view
        map['user_name'] = '';
        return VetSupply.fromJson(map);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch all vet supplies: $e');
    }
  }

  // Admin: Delete any vet supply
  Future<bool> adminDeleteVetSupply(String id) async {
    try {
      await _supabase
          .from('vet_supplies')
          .delete()
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to delete vet supply: $e');
    }
  }

  // Admin: Update vet supply status
  Future<bool> adminUpdateVetSupplyStatus(String id, String status) async {
    try {
      await _supabase
          .from('vet_supplies')
          .update({'status': status})
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to update vet supply status: $e');
    }
  }

  // Admin: Update vet supply (full edit)
  Future<bool> adminUpdateVetSupply({
    required String id,
    required String name,
    required String description,
    required double price,
    required String phone,
    required String status,
  }) async {
    try {
      await _supabase
          .from('vet_supplies')
          .update({
            'name': name,
            'description': description,
            'price': price,
            'phone': phone,
            'status': status,
          })
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to update vet supply: $e');
    }
  }
}
