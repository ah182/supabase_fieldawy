import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/dashboard/application/dashboard_provider.dart';
import 'package:fieldawy_store/features/dashboard/data/analytics_repository_updated.dart';

/// Provider for trends analytics using updated repository
final trendsAnalyticsUpdatedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // Watch the refresh counter to trigger updates
  ref.watch(dashboardRefreshProvider);
  
  final repository = ref.watch(analyticsRepositoryUpdatedProvider);
  return await repository.getTrendsAnalytics();
});

class TrendsAnalyticsWidgetUpdated extends ConsumerWidget {
  const TrendsAnalyticsWidgetUpdated({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAnalyticsAsync = ref.watch(trendsAnalyticsUpdatedProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مؤشر الاتجاهات والترندات العالمية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.data_usage, color: Colors.green[700], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'بيانات حقيقية',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تحليل حقيقي للمنتجات الأكثر طلباً وعمليات البحث الفعلية',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            trendsAnalyticsAsync.when(
              data: (analytics) => Column(
                children: [
                  // Global trending products
                  _buildTrendingProducts(context, analytics['trending'] ?? []),
                  const SizedBox(height: 20),

                  // REAL Search trends
                  _buildRealSearchTrends(context, analytics['searches'] ?? []),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'خطأ في تحميل الترندات',
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(trendsAnalyticsUpdatedProvider);
                      },
                      child: Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingProducts(BuildContext context, List<Map<String, dynamic>> trending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '🔥 المنتجات الأكثر رواجاً عالمياً',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'مُحدث كل ساعة',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (trending.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.trending_up, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'لا توجد ترندات متاحة حالياً',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'جارٍ تحليل البيانات من جميع الموزعين...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trending.length > 10 ? 10 : trending.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final product = trending[index];
              
              final hasProduct = product['user_has_product'] ?? false;
              
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasProduct ? Colors.blue.withOpacity(0.05) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasProduct ? Colors.blue.withOpacity(0.3) : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    // Trend rank
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getTrendColor(index).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: _getTrendColor(index),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Product Image
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: _getTrendColor(index).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getTrendColor(index).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: _buildTrendingProductImage(
                          product['id']?.toString() ?? '',
                          product['name'] ?? '',
                          index,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Product info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['name'] ?? 'منتج غير معروف',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: hasProduct ? Colors.blue[700] : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasProduct)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'لديك',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Views badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getTrendColor(index).withOpacity(0.1),
                                  _getTrendColor(index).withOpacity(0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getTrendColor(index).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: _getTrendColor(index),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product['total_views']}',
                                  style: TextStyle(
                                    color: _getTrendColor(index),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                   "",
                                  style: TextStyle(
                                    color: _getTrendColor(index).withOpacity(0.8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action button
                    if (!hasProduct)
                      TextButton(
                        onPressed: () {
                          _showAddProductDialog(context, product);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: Text(
                          'أضف للكتالوج',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRealSearchTrends(BuildContext context, List<Map<String, dynamic>> searches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '🔍 الأكثر بحثاً - بيانات حقيقية',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.track_changes, color: Colors.orange[700], size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'أفضل 10',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (searches.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 32, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(
                    'لا توجد عمليات بحث حديثة',
                    style: TextStyle(color: Colors.orange[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سيتم عرض الكلمات الأكثر بحثاً عند توفر البيانات',
                    style: TextStyle(color: Colors.orange[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: searches.length > 10 ? 10 : searches.length, // حد أقصى 10
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final search = searches[index];
              final count = search['count'] ?? 0;
              final keyword = search['keyword'] ?? 'مصطلح غير معروف';
              final productId = search['product_id']?.toString() ?? '';
              final productName = search['product_name'] ?? keyword;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    // Search rank
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Product Image
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: _buildSearchProductImage(productId, keyword),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Search info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            keyword,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (productName != keyword) ...[
                            const SizedBox(height: 2),
                            Text(
                              productName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          // Geographic distribution for search terms
                          FutureBuilder<Map<String, dynamic>>(
                            future: _getRealSearchGeographicData(search['search_term'] ?? search['keyword'] ?? ''),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  height: 16,
                                  child: Center(
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.orange.withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              
                              Map<String, dynamic> geoData = snapshot.data ?? {};
                              if (geoData.isEmpty) {
                                return const SizedBox.shrink(); // لا توجد بيانات
                              }
                              
                              return _buildGeographicDistribution(
                                geoData,
                                'عمليات بحث',
                                Colors.orange,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Search count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildGeographicDistribution(Map<String, dynamic> distribution, String type, Color themeColor) {
    if (distribution.isEmpty) return const SizedBox.shrink();
    
    // تحويل البيانات إلى قائمة مرتبة
    List<MapEntry<String, dynamic>> sortedEntries = distribution.entries.toList()
      ..sort((a, b) => (b.value ?? 0).compareTo(a.value ?? 0));
    
    // أخذ أهم 3 محافظات فقط
    List<MapEntry<String, dynamic>> topGovernorates = sortedEntries.take(3).toList();
    
    if (topGovernorates.isEmpty) return const SizedBox.shrink();
    
    // حساب المجموع الكلي للنسب المئوية
    int totalCount = distribution.values.fold<int>(0, (int sum, dynamic value) => sum + ((value ?? 0) as num).toInt());
    
    if (totalCount == 0) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: topGovernorates.map((entry) {
        String governorate = entry.key;
        int count = entry.value ?? 0;
        
        // حساب النسبة المئوية
        double percentage = (count / totalCount) * 100;
        String percentageText = percentage >= 1 
            ? '${percentage.round()}%' 
            : '${percentage.toStringAsFixed(1)}%';
        
        // تحويل الأسماء الإنجليزية للمحافظات للعربية
        String arabicName = _getArabicGovernorate(governorate);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                size: 10,
                color: themeColor.withOpacity(0.8),
              ),
              const SizedBox(width: 3),
              Text(
                arabicName,
                style: TextStyle(
                  color: themeColor.withOpacity(0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  percentageText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getArabicGovernorate(String englishName) {
    // قاموس تحويل أسماء المحافظات من الإنجليزية للعربية
    Map<String, String> governorateMap = {
      'cairo': 'القاهرة',
      'giza': 'الجيزة',
      'alexandria': 'الإسكندرية',
      'qalyubia': 'القليوبية',
      'port_said': 'بورسعيد',
      'suez': 'السويس',
      'luxor': 'الأقصر',
      'aswan': 'أسوان',
      'asyut': 'أسيوط',
      'beheira': 'البحيرة',
      'beni_suef': 'بني سويف',
      'dakahlia': 'الدقهلية',
      'damietta': 'دمياط',
      'fayyum': 'الفيوم',
      'gharbia': 'الغربية',
      'ismailia': 'الإسماعيلية',
      'kafr_el_sheikh': 'كفر الشيخ',
      'matrouh': 'مطروح',
      'minya': 'المنيا',
      'monufia': 'المنوفية',
      'new_valley': 'الوادي الجديد',
      'north_sinai': 'شمال سيناء',
      'qena': 'قنا',
      'red_sea': 'البحر الأحمر',
      'sharqia': 'الشرقية',
      'sohag': 'سوهاج',
      'south_sinai': 'جنوب سيناء',
    };
    
    String lowerName = englishName.toLowerCase().replaceAll(' ', '_');
    return governorateMap[lowerName] ?? englishName;
  }


  Future<Map<String, dynamic>> _getRealSearchGeographicData(String keyword) async {
    try {
      print('🔍 Fetching real geographic data for search: $keyword');
      
      Map<String, dynamic> geoData = {};
      
      if (keyword.isEmpty) {
        print('❌ Empty keyword provided');
        return {};
      }
      
      // جلب البيانات من جدول search_tracking حسب search_location فقط
      try {
        // أولاً: جلب جميع البيانات للكلمة المفتاحية
        final searchResponse = await Supabase.instance.client
            .from('search_tracking')
            .select('search_location, search_term')
            .ilike('search_term', '%$keyword%')
            .not('search_location', 'is', null)
            .neq('search_location', '')
            .limit(200);
        
        print('🔍 Search query: search_term ILIKE %$keyword%');
        print('📊 Raw response: ${searchResponse.length} records found');
        
        // طباعة عينة من البيانات للتشخيص
        if (searchResponse.isNotEmpty) {
          print('📋 Sample data:');
          searchResponse.take(5).forEach((item) {
            print('   search_term: "${item['search_term']}", search_location: "${item['search_location']}"');
          });
        }
        
        for (var search in searchResponse) {
          String location = search['search_location']?.toString() ?? '';
          if (location.isNotEmpty && location.trim().isNotEmpty) {
            // تنظيف اسم المحافظة
            String cleanLocation = location.toLowerCase().trim();
            // إزالة أي أحرف غير مرغوب فيها
            cleanLocation = cleanLocation.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z\s]'), '').trim();
            
            if (cleanLocation.isNotEmpty) {
              geoData[cleanLocation] = (geoData[cleanLocation] ?? 0) + 1;
              print('   ✅ Added location: "$cleanLocation"');
            }
          }
        }
        
        print('✅ Found ${searchResponse.length} search location records from search_tracking');
        print('📊 Processed locations: ${geoData.keys.toList()}');
        
      } catch (e) {
        print('❌ Error fetching search tracking: $e');
      }
      
      // إذا لم نجد أي بيانات، نجرب بحث أوسع
      if (geoData.isEmpty) {
        try {
          print('🔄 No data found, trying broader search...');
          
          // جلب أحدث البيانات من search_tracking بدون تصفية الكلمة المفتاحية
          final fallbackResponse = await Supabase.instance.client
              .from('search_tracking')
              .select('search_location, search_term')
              .not('search_location', 'is', null)
              .neq('search_location', '')
              .order('created_at', ascending: false)
              .limit(50);
          
          print('📊 Fallback response: ${fallbackResponse.length} records found');
          
          for (var search in fallbackResponse) {
            String location = search['search_location']?.toString() ?? '';
            if (location.isNotEmpty && location.trim().isNotEmpty) {
              String cleanLocation = location.toLowerCase().trim();
              cleanLocation = cleanLocation.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z\s]'), '').trim();
              
              if (cleanLocation.isNotEmpty) {
                geoData[cleanLocation] = (geoData[cleanLocation] ?? 0) + 1;
              }
            }
          }
          
          print('✅ Fallback found ${geoData.length} unique locations');
          
        } catch (e) {
          print('❌ Error in fallback search: $e');
        }
      }
      
      print('📊 Final geo data for search "$keyword": $geoData');
      return geoData; // إرجاع البيانات حتى لو كانت فارغة
      
    } catch (e) {
      print('❌ Error fetching real search geographic data: $e');
      return {};
    }
  }


  Color _getTrendColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey[600]!;
      case 2:
        return Colors.orange[300]!;
      default:
        return Colors.green;
    }
  }

  void _showAddProductDialog(BuildContext context, Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة منتج رائج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل تريد إضافة "${product['name']}" لكتالوجك؟'),
            const SizedBox(height: 8),
            Text(
              'هذا المنتج حصل على ${product['total_views']} مشاهدة عالمية وهو في ازدياد بنسبة ${product['growth_percentage']}%',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToAddProduct(context, product);
            },
            child: Text('أضف الآن'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchProductImage(String productId, String keyword) {
    return FutureBuilder<String?>(
      future: _getSearchProductImageFromDatabase(productId, keyword),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.orange.withOpacity(0.7),
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return Image.network(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildSearchPlaceholder();
            },
          );
        }
        
        return _buildSearchPlaceholder();
      },
    );
  }

  Widget _buildSearchPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.orange.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.search,
          size: 18,
          color: Colors.orange.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildTrendingProductImage(String productId, String productName, int index) {
    return FutureBuilder<String?>(
      future: _getTrendingProductImageFromDatabase(productId, productName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getTrendColor(index).withOpacity(0.7),
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return Image.network(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildTrendingPlaceholder(index);
            },
          );
        }
        
        return _buildTrendingPlaceholder(index);
      },
    );
  }

  Widget _buildTrendingPlaceholder(int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getTrendColor(index).withOpacity(0.2),
            _getTrendColor(index).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          index < 3 ? Icons.emoji_events : Icons.trending_up,
          size: 20,
          color: _getTrendColor(index).withOpacity(0.7),
        ),
      ),
    );
  }

  Future<String?> _getTrendingProductImageFromDatabase(String productId, String productName) async {
    try {
      print('🔥 Fetching image for trending product: $productName, ID: $productId');
      
      String? imageUrl;
      
      // البحث بالـ ID أولاً
      if (productId.isNotEmpty) {
        // البحث في جدول products
        try {
          final response = await Supabase.instance.client
              .from('products')
              .select('image_url, name')
              .eq('id', productId)
              .limit(1);
          
          if (response.isNotEmpty && response.first['image_url'] != null) {
            imageUrl = response.first['image_url']?.toString();
            print('✅ Found trending product: ${response.first['name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error fetching trending from products: $e');
        }
        
        // البحث في distributor_products
        try {
          final distributorResponse = await Supabase.instance.client
              .from('distributor_products')
              .select('products!inner(image_url, name)')
              .eq('id', productId)
              .limit(1);
          
          if (distributorResponse.isNotEmpty && distributorResponse.first['products'] != null) {
            final product = distributorResponse.first['products'];
            imageUrl = product['image_url']?.toString();
            print('✅ Found trending distributor product: ${product['name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error fetching trending from distributor_products: $e');
        }
        
        // البحث في surgical_tools
        try {
          final surgicalResponse = await Supabase.instance.client
              .from('surgical_tools')
              .select('image_url, tool_name')
              .eq('id', productId)
              .limit(1);
          
          if (surgicalResponse.isNotEmpty && surgicalResponse.first['image_url'] != null) {
            imageUrl = surgicalResponse.first['image_url']?.toString();
            print('✅ Found trending surgical tool: ${surgicalResponse.first['tool_name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error fetching trending from surgical_tools: $e');
        }
      }
      
      // البحث بالاسم إذا لم نجد بالـ ID
      if (productName.isNotEmpty) {
        // البحث في products بالاسم
        try {
          final nameResponse = await Supabase.instance.client
              .from('products')
              .select('image_url, name')
              .ilike('name', '%$productName%')
              .limit(1);
          
          if (nameResponse.isNotEmpty && nameResponse.first['image_url'] != null) {
            imageUrl = nameResponse.first['image_url']?.toString();
            print('✅ Found trending product by name: ${nameResponse.first['name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error searching trending by name: $e');
        }
        
        // البحث في surgical_tools بالاسم
        try {
          final surgicalNameResponse = await Supabase.instance.client
              .from('surgical_tools')
              .select('image_url, tool_name')
              .ilike('tool_name', '%$productName%')
              .limit(1);
          
          if (surgicalNameResponse.isNotEmpty && surgicalNameResponse.first['image_url'] != null) {
            imageUrl = surgicalNameResponse.first['image_url']?.toString();
            print('✅ Found trending surgical by name: ${surgicalNameResponse.first['tool_name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error searching trending surgical by name: $e');
        }
        
        // البحث في ocr_products بالاسم
        try {
          final ocrNameResponse = await Supabase.instance.client
              .from('ocr_products')
              .select('image_url, product_name')
              .ilike('product_name', '%$productName%')
              .limit(1);
          
          if (ocrNameResponse.isNotEmpty && ocrNameResponse.first['image_url'] != null) {
            imageUrl = ocrNameResponse.first['image_url']?.toString();
            print('✅ Found trending OCR by name: ${ocrNameResponse.first['product_name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error searching trending OCR by name: $e');
        }
      }
      
      print('⚠️ No image found for trending product: $productName');
      return null;
      
    } catch (e) {
      print('❌ Error fetching trending product image: $e');
      return null;
    }
  }

  Future<String?> _getSearchProductImageFromDatabase(String productId, String keyword) async {
    try {
      print('🔍 Fetching image for search: $keyword, Product ID: $productId');
      
      String? imageUrl;
      
      // إذا كان هناك product_id محدد، استخدمه
      if (productId.isNotEmpty) {
        // البحث في جدول products
        try {
          final response = await Supabase.instance.client
              .from('products')
              .select('image_url, name')
              .eq('id', productId)
              .limit(1);
          
          if (response.isNotEmpty && response.first['image_url'] != null) {
            imageUrl = response.first['image_url']?.toString();
            print('✅ Found search product: ${response.first['name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error fetching from products: $e');
        }
        
        // البحث في distributor_products
        try {
          final distributorResponse = await Supabase.instance.client
              .from('distributor_products')
              .select('products!inner(image_url, name)')
              .eq('id', productId)
              .limit(1);
          
          if (distributorResponse.isNotEmpty && distributorResponse.first['products'] != null) {
            final product = distributorResponse.first['products'];
            imageUrl = product['image_url']?.toString();
            print('✅ Found search distributor product: ${product['name']}, Image: $imageUrl');
            return imageUrl;
          }
        } catch (e) {
          print('❌ Error fetching from distributor_products: $e');
        }
      }
      
      // البحث بناءً على الكلمة المفتاحية في products
      try {
        final keywordResponse = await Supabase.instance.client
            .from('products')
            .select('image_url, name')
            .ilike('name', '%$keyword%')
            .limit(1);
        
        if (keywordResponse.isNotEmpty && keywordResponse.first['image_url'] != null) {
          imageUrl = keywordResponse.first['image_url']?.toString();
          print('✅ Found product by keyword: ${keywordResponse.first['name']}, Image: $imageUrl');
          return imageUrl;
        }
      } catch (e) {
        print('❌ Error searching by keyword: $e');
      }
      
      // البحث في surgical_tools
      try {
        final surgicalResponse = await Supabase.instance.client
            .from('surgical_tools')
            .select('image_url, tool_name')
            .ilike('tool_name', '%$keyword%')
            .limit(1);
        
        if (surgicalResponse.isNotEmpty && surgicalResponse.first['image_url'] != null) {
          imageUrl = surgicalResponse.first['image_url']?.toString();
          print('✅ Found surgical tool by keyword: ${surgicalResponse.first['tool_name']}, Image: $imageUrl');
          return imageUrl;
        }
      } catch (e) {
        print('❌ Error searching surgical tools: $e');
      }
      
      // البحث في ocr_products
      try {
        final ocrResponse = await Supabase.instance.client
            .from('ocr_products')
            .select('image_url, product_name')
            .ilike('product_name', '%$keyword%')
            .limit(1);
        
        if (ocrResponse.isNotEmpty && ocrResponse.first['image_url'] != null) {
          imageUrl = ocrResponse.first['image_url']?.toString();
          print('✅ Found OCR product by keyword: ${ocrResponse.first['product_name']}, Image: $imageUrl');
          return imageUrl;
        }
      } catch (e) {
        print('❌ Error searching OCR products: $e');
      }
      
      print('⚠️ No image found for search: $keyword');
      return null;
      
    } catch (e) {
      print('❌ Error fetching search product image: $e');
      return null;
    }
  }

  void _navigateToAddProduct(BuildContext context, Map<String, dynamic> product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('سيتم توجيهك لإضافة ${product['name']}'),
        action: SnackBarAction(
          label: 'إضافة',
          onPressed: () {
            // TODO: Navigate to add product screen
          },
        ),
      ),
    );
  }
}
