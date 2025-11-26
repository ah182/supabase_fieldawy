import 'package:fieldawy_store/features/surgical_tools/domain/surgical_tool_model.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SurgicalToolsRepository {
  final SupabaseClient _supabase;
  final CachingService _cache;

  SurgicalToolsRepository({
    required SupabaseClient supabase,
    required CachingService cache,
  })  : _supabase = supabase,
        _cache = cache;

  // Admin: Get all surgical tools (catalog)
  Future<List<SurgicalTool>> adminGetAllSurgicalTools() async {
    // استخدام Cache-First للأدوات الجراحية (تتغير ببطء)
    return await _cache.cacheFirst<List<SurgicalTool>>(
      key: 'all_surgical_tools',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: _fetchAllSurgicalTools,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => SurgicalTool.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<SurgicalTool>> _fetchAllSurgicalTools() async {
    try {
      final response = await _supabase
          .from('surgical_tools')
          .select('''
            id,
            tool_name,
            company,
            image_url,
            created_by,
            created_at,
            updated_at
          ''')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      
      // Cache as JSON List
      _cache.set('all_surgical_tools', data, duration: CacheDurations.long);
      
      return data.map((json) => SurgicalTool.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch surgical tools: $e');
    }
  }

  // Admin: Get all distributor surgical tools with joined data
  Future<List<DistributorSurgicalTool>> adminGetAllDistributorSurgicalTools() async {
    // استخدام Cache-First للأدوات الجراحية للموزعين
    return await _cache.cacheFirst<List<DistributorSurgicalTool>>(
      key: 'all_distributor_surgical_tools',
      duration: CacheDurations.medium, // 30 دقيقة
      fetchFromNetwork: _fetchAllDistributorSurgicalTools,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => DistributorSurgicalTool.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<DistributorSurgicalTool>> _fetchAllDistributorSurgicalTools() async {
    try {
      final response = await _supabase
          .from('distributor_surgical_tools')
          .select('''
            id,
            distributor_id,
            distributor_name,
            surgical_tool_id,
            description,
            price,
            created_at,
            updated_at,
            surgical_tools!inner(
              tool_name,
              company,
              image_url
            )
          ''')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      
      // Process and flatten data
      final processedData = data.map((json) {
        final map = Map<String, dynamic>.from(json as Map<String, dynamic>);
        // Flatten the surgical_tools nested object
        if (map['surgical_tools'] != null) {
          final toolData = map['surgical_tools'] as Map<String, dynamic>;
          map['tool_name'] = toolData['tool_name'];
          map['company'] = toolData['company'];
          map['image_url'] = toolData['image_url'];
        }
        return map;
      }).toList();
      
      // Cache as JSON List
      _cache.set('all_distributor_surgical_tools', processedData, duration: CacheDurations.medium);
      
      return processedData.map((json) => DistributorSurgicalTool.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch distributor surgical tools: $e');
    }
  }

  // Admin: Delete surgical tool from catalog
  Future<bool> adminDeleteSurgicalTool(String id) async {
    try {
      await _supabase
          .from('surgical_tools')
          .delete()
          .eq('id', id);

      // حذف الكاش بعد الحذف
      _invalidateSurgicalToolsCache();

      return true;
    } catch (e) {
      throw Exception('Failed to delete surgical tool: $e');
    }
  }

  // Admin: Delete distributor surgical tool
  Future<bool> adminDeleteDistributorSurgicalTool(String id) async {
    try {
      await _supabase
          .from('distributor_surgical_tools')
          .delete()
          .eq('id', id);

      // حذف الكاش بعد الحذف
      _invalidateSurgicalToolsCache();

      return true;
    } catch (e) {
      throw Exception('Failed to delete distributor surgical tool: $e');
    }
  }

  // Admin: Update distributor surgical tool
  Future<bool> adminUpdateDistributorSurgicalTool({
    required String id,
    required String description,
    required double price,
  }) async {
    try {
      await _supabase
          .from('distributor_surgical_tools')
          .update({
            'description': description,
            'price': price,
          })
          .eq('id', id);

      // حذف الكاش بعد التعديل
      _invalidateSurgicalToolsCache();

      return true;
    } catch (e) {
      throw Exception('Failed to update distributor surgical tool: $e');
    }
  }

  /// حذف كاش الأدوات الجراحية
  void _invalidateSurgicalToolsCache() {
    _cache.invalidate('all_surgical_tools');
    _cache.invalidate('all_distributor_surgical_tools');
    print('🧹 Surgical tools cache invalidated');
  }
}

// Provider
final surgicalToolsRepositoryProvider = Provider<SurgicalToolsRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return SurgicalToolsRepository(
    supabase: Supabase.instance.client,
    cache: cache,
  );
});
