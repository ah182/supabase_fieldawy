import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SurgicalToolsHomeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  SurgicalToolsHomeRepository(this._cache);

  /// الحصول على جميع الأدوات الجراحية من جميع الموزعين
  Future<List<ProductModel>> getAllSurgicalTools() async {
    // استخدام Cache-First للأدوات الجراحية (تتغير ببطء)
    return await _cache.cacheFirst<List<ProductModel>>(
      key: 'all_surgical_tools_home',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: _fetchAllSurgicalTools,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => ProductModel.fromMap(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<ProductModel>> _fetchAllSurgicalTools() async {
    // جلب جميع الأدوات الجراحية من جميع الموزعين
    final rows = await _supabase
        .from('distributor_surgical_tools')
        .select('''
          id,
          description,
          price,
          status,
          distributor_name,
          created_at,
          views,
          surgical_tools (
            id,
            tool_name,
            company,
            image_url
          )
        ''')
        .order('created_at', ascending: false);

    // تحويل البيانات إلى ProductModel
    final tools = <ProductModel>[];
    for (final row in rows) {
      final surgicalTool = row['surgical_tools'] as Map<String, dynamic>?;
      if (surgicalTool != null) {
        tools.add(ProductModel(
          id: row['id']?.toString() ?? '',
          name: surgicalTool['tool_name']?.toString() ?? '',
          description: row['description']?.toString() ?? '',
          activePrinciple: row['status']?.toString(),
          company: surgicalTool['company']?.toString(),
          action: '',
          package: '',
          imageUrl: (surgicalTool['image_url']?.toString() ?? '').startsWith('http')
              ? surgicalTool['image_url'].toString()
              : '',
          price: (row['price'] as num?)?.toDouble(),
          distributorId: row['distributor_name']?.toString(),
          createdAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null,
          availablePackages: [],
          selectedPackage: null,
          isFavorite: false,
          oldPrice: null,
          priceUpdatedAt: null,
          views: (row['views'] as int?) ?? 0,
          surgicalToolId: surgicalTool['id']?.toString(),
        ));
      }
    }

    // Cache as JSON
    final jsonList = tools.map((t) => t.toMap()).toList();
    _cache.set('all_surgical_tools_home', jsonList, duration: CacheDurations.long);

    return tools;
  }

  /// حذف كاش الأدوات الجراحية
  void invalidateSurgicalToolsCache() {
    _cache.invalidate('all_surgical_tools_home');
    print('🧹 Surgical tools cache invalidated');
  }
}

// Provider
final surgicalToolsHomeRepositoryProvider = Provider<SurgicalToolsHomeRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return SurgicalToolsHomeRepository(cache);
});
