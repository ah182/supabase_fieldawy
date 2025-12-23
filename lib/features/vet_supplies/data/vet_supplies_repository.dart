import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VetSuppliesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  VetSuppliesRepository(this._cache);

  // Get all active vet supplies
  Future<List<VetSupply>> getAllVetSupplies() async {
    // استخدام Cache-First للمستلزمات البيطرية (تتغير ببطء)
    return await _cache.cacheFirst<List<VetSupply>>(
      key: 'all_vet_supplies',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: _fetchAllVetSupplies,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => VetSupply.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<VetSupply>> _fetchAllVetSupplies() async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('get_all_vet_supplies');
        
        if (response == null) {
          return [];
        }

        final List<dynamic> data = response as List<dynamic>;
        
        // Cache as JSON
        _cache.set('all_vet_supplies', data, duration: CacheDurations.long);
        
        return data.map((json) => VetSupply.fromJson(Map<String, dynamic>.from(json))).toList();
      } catch (e) {
        throw Exception('Failed to fetch vet supplies: $e');
      }
    });
  }

  // Get current user's vet supplies
  Future<List<VetSupply>> getMyVetSupplies() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // استخدام Stale-While-Revalidate لمستلزمات المستخدم
    return await _cache.staleWhileRevalidate<List<VetSupply>>(
      key: 'my_vet_supplies_$userId',
      duration: CacheDurations.medium, // 30 دقيقة
      staleTime: const Duration(minutes: 10), // تحديث بعد 10 دقائق
      fetchFromNetwork: () => _fetchMyVetSupplies(userId),
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => VetSupply.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<VetSupply>> _fetchMyVetSupplies(String userId) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('get_my_vet_supplies', params: {
          'p_user_id': userId,
        });

        if (response == null) {
          return [];
        }

        final List<dynamic> data = response as List<dynamic>;
        
        // Cache as JSON
        _cache.set('my_vet_supplies_$userId', data, duration: CacheDurations.medium);
        
        return data.map((json) => VetSupply.fromJson(Map<String, dynamic>.from(json))).toList();
      } catch (e) {
        throw Exception('Failed to fetch my vet supplies: $e');
      }
    });
  }

  // Get vet supplies for a specific distributor
  Future<List<VetSupply>> getVetSuppliesByDistributorId(String distributorId) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('get_my_vet_supplies', params: {
          'p_user_id': distributorId,
        });

        if (response == null) {
          return [];
        }

        final List<dynamic> data = response as List<dynamic>;
        
        // Cache as JSON (optional, maybe use a different key)
        _cache.set('distributor_vet_supplies_$distributorId', data, duration: CacheDurations.medium);
        
        return data.map((json) => VetSupply.fromJson(Map<String, dynamic>.from(json))).toList();
      } catch (e) {
        throw Exception('Failed to fetch distributor vet supplies: $e');
      }
    });
  }

  // Create a new vet supply
  Future<String> createVetSupply({
    required String name,
    required String description,
    required double price,
    required String imageUrl,
    required String phone,
    required String package,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        final response = await _supabase.rpc('create_vet_supply', params: {
          'p_name': name,
          'p_description': description,
          'p_price': price,
          'p_image_url': imageUrl,
          'p_phone': phone,
          'p_package': package,
        });

        // حذف الكاش بعد الإضافة
        _invalidateVetSuppliesCache();

        return response as String;
      } catch (e) {
        throw Exception('Failed to create vet supply: $e');
      }
    });
  }

  // Update a vet supply
  Future<bool> updateVetSupply({
    required String id,
    required String name,
    required String description,
    required double price,
    required String imageUrl,
    required String phone,
    required String package,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.rpc('update_vet_supply', params: {
          'p_supply_id': id,
          'p_name': name,
          'p_description': description,
          'p_price': price,
          'p_image_url': imageUrl,
          'p_phone': phone,
          'p_package': package,
        });

        // حذف الكاش بعد التعديل
        _invalidateVetSuppliesCache();

        return true;
      } catch (e) {
        throw Exception('Failed to update vet supply: $e');
      }
    });
  }

  // Delete a vet supply
  Future<bool> deleteVetSupply(String id) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase.rpc('delete_vet_supply', params: {
          'p_supply_id': id,
        });

        // حذف الكاش بعد الحذف
        _invalidateVetSuppliesCache();

        return true;
      } catch (e) {
        throw Exception('Failed to delete vet supply: $e');
      }
    });
  }

  /// حذف كاش المستلزمات البيطرية
  void _invalidateVetSuppliesCache() {
    _cache.invalidate('all_vet_supplies');
    _cache.invalidateWithPrefix('my_vet_supplies_');
    print('🧹 Vet supplies cache invalidated');
  }

  // Increment views count
  // Increment views count - SINGLE FUNCTION ONLY
  Future<void> incrementViews(String id) async {
    try {
      await NetworkGuard.execute(() async {
        await _supabase.rpc('increment_vet_supply_views', params: {
          'p_supply_id': id,
        });
      });
    } catch (e) {
      // Silently fail - views count is not critical
      print('Failed to increment views: $e');
    }
  }

  // ===== ADMIN METHODS =====

  // Admin: Get all vet supplies (including inactive)
  Future<List<VetSupply>> adminGetAllVetSupplies() async {
    return await NetworkGuard.execute(() async {
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
              package,
              status,
              views_count,
              created_at,
              updated_at
            ''')
            .order('created_at', ascending: false);

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
    });
  }

  // Admin: Delete any vet supply
  Future<bool> adminDeleteVetSupply(String id) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase
            .from('vet_supplies')
            .delete()
            .eq('id', id);

        return true;
      } catch (e) {
        throw Exception('Failed to delete vet supply: $e');
      }
    });
  }

  // Admin: Update vet supply status
  Future<bool> adminUpdateVetSupplyStatus(String id, String status) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase
            .from('vet_supplies')
            .update({'status': status})
            .eq('id', id);

        return true;
      } catch (e) {
        throw Exception('Failed to update vet supply status: $e');
      }
    });
  }

  // Admin: Update vet supply (full edit)
  Future<bool> adminUpdateVetSupply({
    required String id,
    required String name,
    required String description,
    required double price,
    required String phone,
    required String package,
    required String status,
  }) async {
    return await NetworkGuard.execute(() async {
      try {
        await _supabase
            .from('vet_supplies')
            .update({
              'name': name,
              'description': description,
              'price': price,
              'phone': phone,
              'package': package,
              'status': status,
            })
            .eq('id', id);

        // حذف الكاش بعد التعديل
        _invalidateVetSuppliesCache();

        return true;
      } catch (e) {
        throw Exception('Failed to update vet supply: $e');
      }
    });
  }
}

// Provider
final vetSuppliesRepositoryProvider = Provider<VetSuppliesRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return VetSuppliesRepository(cache);
});