import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsRepositoryUpdated {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get advanced views analytics for current user
  Future<Map<String, dynamic>> getAdvancedViewsAnalytics() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return _getEmptyViewsAnalytics();

      // Get hourly views data (last 24 hours)
      final hourlyViews = await _getHourlyViews(userId);
      
      // Get views statistics
      final statistics = await _getViewsStatistics(userId);
      
      // Get top viewed products today
      final topViewedToday = await _getTopViewedToday(userId);
      
      // Get geographic distribution
      final geographic = await _getGeographicViews(userId);

      return {
        'hourlyViews': hourlyViews,
        'statistics': statistics,
        'topViewedToday': topViewedToday,
        'geographic': geographic,
      };
    } catch (e) {
      print('Error getting advanced views analytics: $e');
      return _getEmptyViewsAnalytics();
    }
  }

  // Get global trends analytics with REAL search data - WITH AUTO-IMPROVE
  Future<Map<String, dynamic>> getTrendsAnalytics() async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Get globally trending products - using direct database queries
      final trending = await _getGlobalTrendingProductsSimplified(userId);

      // Get REAL search trends from database - WITH CACHE
      // الأسماء محسّنة تلقائياً في قاعدة البيانات عند البحث
      final searches = await _getRealSearchTrendsWithCache();

      // Get personalized recommendations - simplified
      final recommendations = await _getPersonalizedRecommendationsSimplified(userId);

      return {
        'trending': trending,
        'searches': searches,
        'recommendations': recommendations,
      };
    } catch (e) {
      print('Error getting trends analytics: $e');
      return _getEmptyTrendsAnalytics();
    }
  }

  // NEW: Get search trends using get_real_search_trends function
  Future<List<Map<String, dynamic>>> _getRealSearchTrendsWithCache() async {
    try {
      print('🚀 Getting search trends using get_real_search_trends...');

      // استخدام الدالة المحسّنة من ملف SQL
      final response = await _supabase.rpc('get_real_search_trends', params: {
        'p_limit': 10,
        'p_days_back': 7,
      });

      if (response == null || response is! List || response.isEmpty) {
        print('⚠️ No data from get_real_search_trends, falling back to direct query');
        return await _getRealSearchTrendsFast();
      }

      List<Map<String, dynamic>> searchTrends = [];

      for (var row in response) {
        final keyword = row['keyword'] ?? 'مصطلح غير معروف';
        final searchCount = row['search_count'] ?? 0;
        final improvementScore = row['improvement_score'] ?? 0;
        final sourceTable = row['source_table'] ?? 'none';
        final distributorCount = row['distributor_count'] ?? 0;
        final improved = row['improved'] ?? false;

        searchTrends.add({
          'keyword': keyword,
          'count': searchCount,
          'unique_users': distributorCount, // عدد الموزعين كمؤشر للمستخدمين
          'click_rate': 0.0,
          'trend_direction': 'up',
          'growth_percentage': searchCount > 5 ? 25.0 : 10.0,
          'avg_results': searchCount.toDouble(),
          'is_trending': searchCount > 3,
          'improvement_score': improvementScore,
          'source_table': sourceTable,
          'distributor_count': distributorCount,
          'improved': improved,
        });
      }

      print('✅ Got ${searchTrends.length} search trends from get_real_search_trends');
      return searchTrends;

    } catch (e) {
      print('❌ Error getting search trends from get_real_search_trends: $e');
      print('🔄 Falling back to fast version...');
      return await _getRealSearchTrendsFast();
    }
  }

  // FAST VERSION: Get search trends without expensive name improvement
  Future<List<Map<String, dynamic>>> _getRealSearchTrendsFast() async {
    try {
      print('🚀 Getting search trends - FAST VERSION...');

      // استعلام مباشر بسيط بدون تحسين الأسماء
      final response = await _supabase
          .from('search_tracking')
          .select('search_term, result_count, user_id, search_type')
          .gte('created_at', DateTime.now().subtract(Duration(days: 7)).toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      print('📊 Query returned ${response.length} records');

      if (response.isEmpty) {
        print('⚠️ No search data found');
        return [];
      }

      // تجميع البيانات يدوياً بدون تحسين الأسماء
      Map<String, Map<String, dynamic>> termStats = {};

      for (var record in response) {
        final term = record['search_term'] as String? ?? '';
        if (term.isEmpty || term.length < 2) continue;

        if (termStats.containsKey(term)) {
          termStats[term]!['count'] += 1;
          termStats[term]!['total_results'] += (record['result_count'] as int? ?? 0);
          termStats[term]!['users'].add(record['user_id']);
        } else {
          termStats[term] = {
            'count': 1,
            'total_results': record['result_count'] as int? ?? 0,
            'users': {record['user_id']},
          };
        }
      }

      // تحويل لقائمة مرتبة
      List<Map<String, dynamic>> searchTrends = [];

      var sortedTerms = termStats.entries.toList()
        ..sort((a, b) => b.value['count'].compareTo(a.value['count']));

      for (var entry in sortedTerms.take(10)) {
        final stats = entry.value;

        searchTrends.add({
          'keyword': entry.key,
          'count': stats['count'],
          'unique_users': stats['users'].length,
          'click_rate': 0.0,
          'trend_direction': 'up',
          'growth_percentage': stats['count'] > 5 ? 25.0 : 10.0,
          'avg_results': stats['total_results'] / stats['count'],
          'is_trending': stats['count'] > 3,
        });
      }

      print('✅ Got ${searchTrends.length} search trends in FAST mode');
      return searchTrends;

    } catch (e) {
      print('❌ Error getting search trends: $e');
      return [];
    }
  }

  // دالة تحسين أسماء المنتجات بالبحث في الجداول المختلفة
  /// Improve product names by searching in different product tables
  Future<String> _improveProductName(String searchTerm, String searchType) async {
    try {
      print('🔍 Improving product name: "$searchTerm" (Type: $searchType)');
      
      String cleanSearchTerm = searchTerm.trim().toLowerCase();
      String bestMatch = searchTerm; // الاسم الأصلي كاحتياطي
      int bestMatchScore = 0;
      
      // جداول البحث المحدثة - جداول الموزعين + vet_supplies
      List<Map<String, String>> searchTables = [];

      if (searchType == 'products' || searchType == 'general') {
        searchTables.addAll([
          {'table': 'distributor_products', 'nameColumn': 'products.name', 'condition': ', products!inner(name)'},
          {'table': 'distributor_ocr_products', 'nameColumn': 'ocr_products.product_name', 'condition': ', ocr_products!inner(product_name)'},
          {'table': 'distributor_surgical_tools', 'nameColumn': 'surgical_tools.tool_name', 'condition': ', surgical_tools!inner(tool_name)'},
          {'table': 'vet_supplies', 'nameColumn': 'name', 'condition': ''},
        ]);
      } else if (searchType == 'distributors') {
        // البحث في الموزعين فقط - بدون vet_supplies
        searchTables.addAll([
          {'table': 'distributor_products', 'nameColumn': 'products.name', 'condition': ', products!inner(name)'},
          {'table': 'distributor_ocr_products', 'nameColumn': 'ocr_products.product_name', 'condition': ', ocr_products!inner(product_name)'},
          {'table': 'distributor_surgical_tools', 'nameColumn': 'surgical_tools.tool_name', 'condition': ', surgical_tools!inner(tool_name)'},
        ]);
      } else if (searchType == 'surgical_tools') {
        searchTables.addAll([
          {'table': 'distributor_surgical_tools', 'nameColumn': 'surgical_tools.tool_name', 'condition': ', surgical_tools!inner(tool_name)'},
        ]);
      } else if (searchType == 'vet_supplies') {
        searchTables.addAll([
          {'table': 'vet_supplies', 'nameColumn': 'name', 'condition': ''},
        ]);
      }
      
      for (var tableInfo in searchTables) {
        try {
          List<dynamic> results = [];

          if (tableInfo['condition']!.isNotEmpty) {
            // استعلام مع join - مع فلتر بحث مستهدف
            // نبحث في اسم المنتج من الجدول المرتبط
            String tableName = tableInfo['table']!;
            String nameColumn = '';

            if (tableName == 'distributor_products') {
              nameColumn = 'products.name';
            } else if (tableName == 'distributor_ocr_products') {
              nameColumn = 'ocr_products.product_name';
            } else if (tableName == 'distributor_surgical_tools') {
              nameColumn = 'surgical_tools.tool_name';
            }

            // نجلب فقط المنتجات التي تطابق كلمة البحث
            // ⚡ مع حساب عدد الموزعين لكل منتج (للترتيب حسب الشعبية)
            if (nameColumn.isNotEmpty) {
              if (tableName == 'distributor_products') {
                // للمنتجات العادية: نجمع حسب product_id ونحسب عدد الموزعين
                results = await _supabase
                    .from(tableName)
                    .select('product_id, products!inner(name)')
                    .ilike('products.name', '%$cleanSearchTerm%')
                    .limit(100);
              } else if (tableName == 'distributor_ocr_products') {
                // لمنتجات OCR: نجمع حسب ocr_product_id ونحسب عدد الموزعين
                results = await _supabase
                    .from(tableName)
                    .select('ocr_product_id, ocr_products!inner(product_name)')
                    .ilike('ocr_products.product_name', '%$cleanSearchTerm%')
                    .limit(100);
              } else if (tableName == 'distributor_surgical_tools') {
                // للأدوات الجراحية: نجمع حسب surgical_tool_id ونحسب عدد الموزعين
                results = await _supabase
                    .from(tableName)
                    .select('surgical_tool_id, surgical_tools!inner(tool_name)')
                    .ilike('surgical_tools.tool_name', '%$cleanSearchTerm%')
                    .limit(100);
              } else {
                results = await _supabase
                    .from(tableName)
                    .select('id${tableInfo['condition']}')
                    .ilike(nameColumn, '%$cleanSearchTerm%')
                    .limit(50);
              }
            }

            // إذا لم نجد نتائج، نجلب بدون فلتر (fallback)
            if (results.isEmpty) {
              results = await _supabase
                  .from(tableName)
                  .select('id${tableInfo['condition']}')
                  .limit(50);
            }
          } else {
            // استعلام مباشر مع فلتر البحث
            String searchColumn = tableInfo['nameColumn']!;
            var query = _supabase
                .from(tableInfo['table']!)
                .select(searchColumn)
                .or('$searchColumn.ilike.%$cleanSearchTerm%,$searchColumn.ilike.$cleanSearchTerm%')
                .limit(200);

            results = await query;

            // إذا لم نجد نتائج، نبحث بدون فلتر البحث
            if (results.isEmpty) {
              results = await _supabase
                  .from(tableInfo['table']!)
                  .select(searchColumn)
                  .limit(100);
            }
          }
          
          // ⚡ نحسب عدد الموزعين لكل منتج (لجميع الجداول)
          Map<String, int> productDistributorCount = {};
          String? tableName = tableInfo['table'];

          if (tableName == 'distributor_products') {
            for (var product in results) {
              var nestedData = product['products'];
              if (nestedData != null) {
                String productName = nestedData['name'] ?? '';
                if (productName.isNotEmpty) {
                  productDistributorCount[productName] = (productDistributorCount[productName] ?? 0) + 1;
                }
              }
            }
          } else if (tableName == 'distributor_ocr_products') {
            for (var product in results) {
              var nestedData = product['ocr_products'];
              if (nestedData != null) {
                String productName = nestedData['product_name'] ?? '';
                if (productName.isNotEmpty) {
                  productDistributorCount[productName] = (productDistributorCount[productName] ?? 0) + 1;
                }
              }
            }
          } else if (tableName == 'distributor_surgical_tools') {
            for (var product in results) {
              var nestedData = product['surgical_tools'];
              if (nestedData != null) {
                String productName = nestedData['tool_name'] ?? '';
                if (productName.isNotEmpty) {
                  productDistributorCount[productName] = (productDistributorCount[productName] ?? 0) + 1;
                }
              }
            }
          }

          // معالجة النتائج
          Set<String> processedNames = {}; // لتجنب تكرار نفس المنتج

          for (var product in results) {
            String productName = '';

            // استخراج اسم المنتج حسب بنية البيانات
            if (tableInfo['condition']!.isNotEmpty) {
              // بيانات مع join
              String? tableName = tableInfo['table'];
              if (tableName == 'distributor_products') {
                var nestedData = product['products'];
                if (nestedData != null) {
                  productName = nestedData['name'] ?? '';
                }
              } else if (tableName == 'distributor_ocr_products') {
                var nestedData = product['ocr_products'];
                if (nestedData != null) {
                  productName = nestedData['product_name'] ?? '';
                }
              } else if (tableName == 'distributor_surgical_tools') {
                var nestedData = product['surgical_tools'];
                if (nestedData != null) {
                  productName = nestedData['tool_name'] ?? '';
                }
              }
            } else {
              // بيانات مباشرة
              productName = product[tableInfo['nameColumn']!.split('.').last] ?? '';
            }

            // تجنب معالجة نفس المنتج مرتين
            if (productName.isEmpty || processedNames.contains(productName)) {
              continue;
            }
            processedNames.add(productName);

            if (productName.isNotEmpty) {
              int matchScore = _calculateMatchScore(cleanSearchTerm, productName.toLowerCase());

              // ⚡ إضافة نقاط إضافية حسب عدد الموزعين (الشعبية)
              int distributorCount = productDistributorCount[productName] ?? 1;
              int popularityBonus = 0;
              if (distributorCount >= 5) popularityBonus = 10;
              else if (distributorCount >= 3) popularityBonus = 5;
              else if (distributorCount >= 2) popularityBonus = 2;

              int finalScore = matchScore + popularityBonus;

              print('🔍 "$productName": match=$matchScore, distributors=$distributorCount, bonus=$popularityBonus, final=$finalScore');

              if (finalScore > bestMatchScore) {
                bestMatchScore = finalScore;
                bestMatch = productName;

                // إذا وجدنا مطابقة ممتازة، نحدث جدول التتبع
                if (matchScore >= 80) {
                  await _updateSearchTermInTracking(searchTerm, productName);
                  print('✅ Updated search term: "$searchTerm" → "$productName"');
                  break;
                }
              }
            }
          }
          
          // إذا وجدنا مطابقة جيدة، لا نحتاج للبحث في الجداول الأخرى
          if (bestMatchScore >= 80) break;
          
        } catch (e) {
          print('❌ Error searching in ${tableInfo['table']}: $e');
        }
      }
      
      print('🎯 Best match for "$searchTerm": "$bestMatch" (Score: $bestMatchScore)');
      return bestMatch;
      
    } catch (e) {
      print('❌ Error improving product name: $e');
      return searchTerm; // إرجاع الاسم الأصلي في حالة الخطأ
    }
  }

  // حساب درجة التطابق بين النصين
  /// Calculate match score between two strings
  int _calculateMatchScore(String searchTerm, String productName) {
    if (searchTerm == productName) return 100;
    
    // تنظيف النصوص
    String cleanSearch = searchTerm.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9\s]'), '').trim().toLowerCase();
    String cleanProduct = productName.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9\s]'), '').trim().toLowerCase();
    
    print('🔍 Comparing: "$cleanSearch" vs "$cleanProduct"');
    
    // مطابقة كاملة
    if (cleanSearch == cleanProduct) return 100;
    
    // التحقق من البداية المطابقة (مهم للكلمات المختصرة)
    if (cleanProduct.startsWith(cleanSearch) && cleanSearch.length >= 3) {
      int score = 80; // نقاط ثابتة عالية للبداية المطابقة
      if (cleanSearch.length >= 4) score = 85;
      if (cleanSearch.length >= 5) score = 90;
      print('✅ Starts with match: $score% (search: ${cleanSearch.length} chars)');
      return score;
    }
    
    if (cleanSearch.startsWith(cleanProduct) && cleanProduct.length >= 3) {
      int score = ((cleanProduct.length / cleanSearch.length) * 90).round();
      print('✅ Product starts with search: $score%');
      return score > 80 ? score : 80;
    }
    
    // التحقق من الاحتواء الكامل
    if (cleanProduct.contains(cleanSearch)) {
      int score = ((cleanSearch.length / cleanProduct.length) * 85).round();
      print('✅ Contains match: $score%');
      return score > 70 ? score : 70;
    }
    
    if (cleanSearch.contains(cleanProduct)) {
      int score = ((cleanProduct.length / cleanSearch.length) * 85).round();
      print('✅ Search contains product: $score%');
      return score > 70 ? score : 70;
    }
    
    // تقسيم إلى كلمات والتحقق من التطابق
    List<String> searchWords = cleanSearch.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    List<String> productWords = cleanProduct.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    
    if (searchWords.isEmpty || productWords.isEmpty) {
      print('❌ No valid words found');
      return 0;
    }
    
    int totalMatches = 0;
    int bestWordScore = 0;
    
    for (String searchWord in searchWords) {
      int bestMatchForWord = 0;
      
      for (String productWord in productWords) {
        int wordScore = 0;
        
        // مطابقة كاملة للكلمة
        if (searchWord == productWord) {
          wordScore = 100;
        }
        // بداية مطابقة للكلمة
        else if (productWord.startsWith(searchWord) && searchWord.length >= 3) {
          wordScore = ((searchWord.length / productWord.length) * 90).round();
        }
        else if (searchWord.startsWith(productWord) && productWord.length >= 3) {
          wordScore = ((productWord.length / searchWord.length) * 90).round();
        }
        // احتواء
        else if (productWord.contains(searchWord)) {
          wordScore = ((searchWord.length / productWord.length) * 80).round();
        }
        else if (searchWord.contains(productWord)) {
          wordScore = ((productWord.length / searchWord.length) * 80).round();
        }
        
        if (wordScore > bestMatchForWord) {
          bestMatchForWord = wordScore;
        }
      }
      
      if (bestMatchForWord > 0) {
        totalMatches++;
        bestWordScore = bestWordScore > bestMatchForWord ? bestWordScore : bestMatchForWord;
      }
      
      print('🔸 Word "$searchWord" best match: $bestMatchForWord%');
    }
    
    // حساب النتيجة النهائية
    double wordsMatchPercentage = (totalMatches / searchWords.length) * 100;
    int finalScore = ((wordsMatchPercentage + bestWordScore) / 2).round();
    
    print('🎯 Final score: $finalScore% (Words: ${wordsMatchPercentage.round()}%, Best: $bestWordScore%)');
    return finalScore;
  }

  // تحديث مصطلح البحث في جدول التتبع
  /// Update search term in tracking table
  Future<void> _updateSearchTermInTracking(String oldTerm, String newTerm) async {
    try {
      print('🔄 Updating search term in tracking table...');
      print('🔄 Old: "$oldTerm" → New: "$newTerm"');
      
      final result = await _supabase
          .from('search_tracking')
          .update({'search_term': newTerm.toLowerCase().trim()})
          .eq('search_term', oldTerm.toLowerCase().trim())
          .select('id'); // للحصول على المدخلات المحدثة
      
      if (result.isNotEmpty) {
        print('✅ Updated ${result.length} records in tracking table: "$oldTerm" → "$newTerm"');
      } else {
        print('⚠️ No records updated for term: "$oldTerm"');
        // تحقق من وجود المصطلح في الجدول
        final existing = await _supabase
            .from('search_tracking')
            .select('id, search_term')
            .eq('search_term', oldTerm.toLowerCase().trim())
            .limit(5);
        
        print('🔍 Existing records with term "$oldTerm": ${existing.length}');
        if (existing.isNotEmpty) {
          print('📝 Sample records: ${existing.take(2)}');
        }
      }
    } catch (e) {
      print('❌ Error updating search tracking: $e');
      print('❌ Old term: "$oldTerm"');
      print('❌ New term: "$newTerm"');
    }
  }

  // تحسين مصطلحات البحث حسب النوع (دالة عامة)
  /// Improve search terms by type (public method)
  Future<String> improveProductName(String searchTerm, String searchType) async {
    return await _improveProductName(searchTerm, searchType);
  }

  // تحسين جميع مصطلحات البحث لنوع معين (محسن للأداء)
  /// Improve all search terms for specific type (optimized for performance)
  Future<void> improveSearchTermsForType(String searchType) async {
    try {
      print('🔄 Starting optimized improvement for type: $searchType');
      
      // 1. تحقق من آخر معالجة
      final lastProcessed = await _getLastProcessingTime(searchType);
      if (lastProcessed != null && 
          lastProcessed.isAfter(DateTime.now().subtract(Duration(hours: 6)))) {
        print('⏩ Skipping improvement for $searchType - processed recently at $lastProcessed');
        return;
      }

      // 2. تأخير قصير لعدم تأثير على فتح الصفحة
      await Future.delayed(Duration(seconds: 2));
      
      // 3. جلب 3 مصطلحات فقط (بدلاً من 20)
      final searchTerms = await _supabase
          .from('search_tracking')
          .select('search_term')
          .eq('search_type', searchType)
          .gte('created_at', DateTime.now().subtract(Duration(days: 7)).toIso8601String())
          .limit(3); // تقليل من 20 إلى 3
      
      // تجميع المصطلحات الفريدة
      Set<String> uniqueTerms = {};
      
      for (var record in searchTerms) {
        String term = record['search_term'] ?? '';
        if (term.length >= 3 && !uniqueTerms.contains(term)) {
          uniqueTerms.add(term);
        }
      }
      
      print('🔍 Found ${uniqueTerms.length} unique $searchType terms to improve (optimized)');
      
      // 4. معالجة سريعة للمصطلحات
      int processed = 0;
      for (String term in uniqueTerms) {
        try {
          String improvedName = await _improveProductNameOptimized(term, searchType);
          
          if (improvedName != term) {
            await _updateSearchTermInTracking(term, improvedName);
            print('✅ Improved $searchType: "$term" → "$improvedName"');
          }
          
          processed++;
          // تقليل التأخير من 100ms إلى 50ms
          await Future.delayed(Duration(milliseconds: 50));
          
        } catch (e) {
          print('❌ Error improving $searchType term "$term": $e');
        }
      }
      
      // 5. حفظ وقت آخر معالجة
      await _saveLastProcessingTime(searchType, DateTime.now());
      
      print('✅ $searchType optimized improvement completed. Processed $processed terms.');
      
    } catch (e) {
      print('❌ Error in $searchType optimized improvement: $e');
    }
  }

  // دالة تحسين محسنة للأداء (جلب أقل، معالجة أسرع)
  /// Optimized product name improvement (fetch less, process faster)
  Future<String> _improveProductNameOptimized(String searchTerm, String searchType) async {
    try {
      print('🚀 Optimized improving: "$searchTerm" (Type: $searchType)');
      
      String cleanSearchTerm = searchTerm.trim().toLowerCase();
      String bestMatch = searchTerm;
      int bestMatchScore = 0;
      
      // جداول البحث المحسنة (ترتيب حسب الأولوية)
      List<Map<String, String>> searchTables = [];

      if (searchType == 'surgical_tools') {
        // للأدوات الجراحية: البحث في جدول الموزعين فقط
        searchTables.addAll([
          {'table': 'distributor_surgical_tools', 'nameColumn': 'surgical_tools.tool_name', 'condition': ', surgical_tools!inner(tool_name)'},
        ]);
      } else if (searchType == 'vet_supplies') {
        // للمستلزمات البيطرية
        searchTables.addAll([
          {'table': 'vet_supplies', 'nameColumn': 'name', 'condition': ''},
        ]);
      } else if (searchType == 'distributors') {
        // للموزعين: البحث في منتجات الموزعين فقط - بدون vet_supplies
        searchTables.addAll([
          {'table': 'distributor_products', 'nameColumn': 'products.name', 'condition': ', products!inner(name)'},
          {'table': 'distributor_ocr_products', 'nameColumn': 'ocr_products.product_name', 'condition': ', ocr_products!inner(product_name)'},
        ]);
      } else {
        // للمنتجات العامة
        searchTables.addAll([
          {'table': 'distributor_products', 'nameColumn': 'products.name', 'condition': ', products!inner(name)'},
          {'table': 'distributor_ocr_products', 'nameColumn': 'ocr_products.product_name', 'condition': ', ocr_products!inner(product_name)'},
          {'table': 'distributor_surgical_tools', 'nameColumn': 'surgical_tools.tool_name', 'condition': ', surgical_tools!inner(tool_name)'},
          {'table': 'vet_supplies', 'nameColumn': 'name', 'condition': ''},
        ]);
      }
      
      for (var tableInfo in searchTables) {
        try {
          List<dynamic> results = [];
          
          if (tableInfo['condition']!.isNotEmpty) {
            // استعلام مع join - مع فلتر بحث مستهدف
            String tableName = tableInfo['table']!;
            String nameColumn = '';

            if (tableName == 'distributor_products') {
              nameColumn = 'products.name';
            } else if (tableName == 'distributor_ocr_products') {
              nameColumn = 'ocr_products.product_name';
            } else if (tableName == 'distributor_surgical_tools') {
              nameColumn = 'surgical_tools.tool_name';
            }

            // نجلب فقط المنتجات التي تطابق كلمة البحث
            // ⚡ مع حساب عدد الموزعين لكل منتج (للترتيب حسب الشعبية)
            if (nameColumn.isNotEmpty) {
              if (tableName == 'distributor_products') {
                // للمنتجات العادية: نجمع حسب product_id ونحسب عدد الموزعين
                results = await _supabase
                    .from(tableName)
                    .select('product_id, products!inner(name)')
                    .ilike('products.name', '%$cleanSearchTerm%')
                    .limit(50);
              } else if (tableName == 'distributor_ocr_products') {
                // لمنتجات OCR: نجمع حسب ocr_product_id ونحسب عدد الموزعين
                results = await _supabase
                    .from(tableName)
                    .select('ocr_product_id, ocr_products!inner(product_name)')
                    .ilike('ocr_products.product_name', '%$cleanSearchTerm%')
                    .limit(50);
              } else if (tableName == 'distributor_surgical_tools') {
                // للأدوات الجراحية: نجمع حسب surgical_tool_id ونحسب عدد الموزعين
                results = await _supabase
                    .from(tableName)
                    .select('surgical_tool_id, surgical_tools!inner(tool_name)')
                    .ilike('surgical_tools.tool_name', '%$cleanSearchTerm%')
                    .limit(50);
              } else {
                results = await _supabase
                    .from(tableName)
                    .select('id${tableInfo['condition']}')
                    .ilike(nameColumn, '%$cleanSearchTerm%')
                    .limit(30);
              }
            }
          } else {
            // استعلام مباشر - بحث مستهدف
            String searchColumn = tableInfo['nameColumn']!;
            var query = _supabase
                .from(tableInfo['table']!)
                .select(searchColumn)
                .ilike(searchColumn, '%$cleanSearchTerm%') // بحث مستهدف مباشرة
                .limit(30); // تقليل من 200 إلى 30
            
            results = await query;
          }
          
          // ⚡ نحسب عدد الموزعين لكل منتج (لجميع الجداول)
          Map<String, int> productDistributorCount = {};
          String? tableName = tableInfo['table'];

          if (tableName == 'distributor_products') {
            for (var product in results) {
              var nestedData = product['products'];
              if (nestedData != null) {
                String productName = nestedData['name'] ?? '';
                if (productName.isNotEmpty) {
                  productDistributorCount[productName] = (productDistributorCount[productName] ?? 0) + 1;
                }
              }
            }
          } else if (tableName == 'distributor_ocr_products') {
            for (var product in results) {
              var nestedData = product['ocr_products'];
              if (nestedData != null) {
                String productName = nestedData['product_name'] ?? '';
                if (productName.isNotEmpty) {
                  productDistributorCount[productName] = (productDistributorCount[productName] ?? 0) + 1;
                }
              }
            }
          } else if (tableName == 'distributor_surgical_tools') {
            for (var product in results) {
              var nestedData = product['surgical_tools'];
              if (nestedData != null) {
                String productName = nestedData['tool_name'] ?? '';
                if (productName.isNotEmpty) {
                  productDistributorCount[productName] = (productDistributorCount[productName] ?? 0) + 1;
                }
              }
            }
          }

          // معالجة سريعة للنتائج
          Set<String> processedNames = {}; // لتجنب تكرار نفس المنتج

          for (var product in results.take(20)) { // معالجة 20 من كل جدول
            String productName = '';

            if (tableInfo['condition']!.isNotEmpty) {
              String? tableName = tableInfo['table'];
              if (tableName == 'distributor_products') {
                var nestedData = product['products'];
                if (nestedData != null) {
                  productName = nestedData['name'] ?? '';
                }
              } else if (tableName == 'distributor_ocr_products') {
                var nestedData = product['ocr_products'];
                if (nestedData != null) {
                  productName = nestedData['product_name'] ?? '';
                }
              } else if (tableName == 'distributor_surgical_tools') {
                var nestedData = product['surgical_tools'];
                if (nestedData != null) {
                  productName = nestedData['tool_name'] ?? '';
                }
              }
            } else {
              productName = product[tableInfo['nameColumn']!.split('.').last] ?? '';
            }

            // تجنب معالجة نفس المنتج مرتين
            if (productName.isEmpty || processedNames.contains(productName)) {
              continue;
            }
            processedNames.add(productName);

            if (productName.isNotEmpty) {
              int matchScore = _calculateMatchScoreOptimized(cleanSearchTerm, productName.toLowerCase());

              // ⚡ إضافة نقاط إضافية حسب عدد الموزعين (الشعبية)
              int distributorCount = productDistributorCount[productName] ?? 1;
              int popularityBonus = 0;
              if (distributorCount >= 5) popularityBonus = 10;
              else if (distributorCount >= 3) popularityBonus = 5;
              else if (distributorCount >= 2) popularityBonus = 2;

              int finalScore = matchScore + popularityBonus;

              if (finalScore > bestMatchScore) {
                bestMatchScore = finalScore;
                bestMatch = productName;

                // إذا وجدنا مطابقة ممتازة، توقف فوراً
                if (matchScore >= 85) {
                  await _updateSearchTermInTracking(searchTerm, productName);
                  print('⚡ Quick match found: "$searchTerm" → "$productName" (match=$matchScore, distributors=$distributorCount, final=$finalScore)');
                  return productName;
                }
              }
            }
          }
          
          // إذا وجدنا مطابقة جيدة، لا نحتاج للجدول التالي
          if (bestMatchScore >= 80) break;
          
        } catch (e) {
          print('❌ Error in optimized search for ${tableInfo['table']}: $e');
        }
      }
      
      print('⚡ Optimized result: "$searchTerm" → "$bestMatch" (Score: $bestMatchScore)');
      return bestMatch;
      
    } catch (e) {
      print('❌ Error in optimized improvement: $e');
      return searchTerm;
    }
  }

  // حساب درجة التطابق محسن (أسرع)
  /// Optimized match score calculation (faster)
  int _calculateMatchScoreOptimized(String searchTerm, String productName) {
    if (searchTerm == productName) return 100;
    
    // فحص سريع للبداية المطابقة فقط (الأهم)
    if (productName.startsWith(searchTerm) && searchTerm.length >= 3) {
      int score = 80;
      if (searchTerm.length >= 4) score = 85;
      if (searchTerm.length >= 5) score = 90;
      return score;
    }
    
    // فحص الاحتواء البسيط
    if (productName.contains(searchTerm)) {
      return ((searchTerm.length / productName.length) * 75).round();
    }
    
    return 0; // بدلاً من الحسابات المعقدة
  }

  // جلب وقت آخر معالجة
  /// Get last processing time
  Future<DateTime?> _getLastProcessingTime(String searchType) async {
    try {
      // استخدام SharedPreferences أو cache بسيط
      // final key = 'last_processed_$searchType';
      // يمكن استخدام أي cache system هنا
      // مثلاً: return SharedPreferences.getInt(key)?.toDateTime();
      
      // الآن نرجع null ليعمل التحسين دائماً (أول مرة)
      // تجاهل searchType مؤقتاً حتى يتم تطبيق cache
      return null;
    } catch (e) {
      return null;
    }
  }

  // حفظ وقت آخر معالجة
  /// Save last processing time
  Future<void> _saveLastProcessingTime(String searchType, DateTime time) async {
    try {
      // final key = 'last_processed_$searchType';
      // يمكن حفظ الوقت في SharedPreferences أو cache
      // مثلاً: SharedPreferences.setInt(key, time.millisecondsSinceEpoch);
      print('📅 Saved processing time for $searchType: $time');
    } catch (e) {
      print('❌ Error saving processing time: $e');
    }
  }

  // Log search activity - ENHANCED function with auto-improvement
  Future<String?> logSearchActivity({
    required String searchTerm,
    String searchType = 'products',
    String? searchLocation,
    int resultCount = 0,
    String? sessionId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Error: No authenticated user found');
        return null;
      }

      print('Logging search activity for user: $userId');
      print('Search term: $searchTerm, Type: $searchType, Results: $resultCount');

      // استخدام الدالة المحسّنة التي تحسّن الاسم تلقائياً
      final response = await _supabase.rpc('log_search_activity_enhanced', params: {
        'p_user_id': userId,
        'p_search_term': searchTerm,
        'p_search_type': searchType,
        'p_search_location': searchLocation,
        'p_result_count': resultCount,
        'p_session_id': sessionId,
      });

      print('✅ Search logged successfully with auto-improvement: $searchTerm (ID: $response)');

      // الدالة المحدثة ترجع BIGINT، تحويل إلى string
      if (response != null) {
        return response.toString();
      }
      return null;
    } catch (e) {
      print('❌ Error logging search activity: $e');
      print('User ID: ${_supabase.auth.currentUser?.id}');
      print('Search term: $searchTerm');
      return null;
    }
  }

  // Update search click - NEW function
  Future<bool> updateSearchClick(String searchId, String clickedResultId) async {
    try {
      print('🔍 Updating search click - Search ID: $searchId, Clicked Item: $clickedResultId');
      
      // Parse searchId as int since the function expects BIGINT
      final searchIdInt = int.tryParse(searchId);
      if (searchIdInt == null) {
        print('❌ Error: Invalid search ID format: $searchId (not a valid integer)');
        return false;
      }
      
      print('✅ Parsed search ID: $searchIdInt');
      
      // الدالة المحدثة تقبل BIGINT للـ search_id و TEXT للـ clicked_result_id
      final response = await _supabase.rpc('update_search_click', params: {
        'p_search_id': searchIdInt,
        'p_clicked_result_id': clickedResultId, // إرسال كـ TEXT مباشرة
      });
      
      print('✅ Search click updated successfully for search ID: $searchIdInt');
      return response == true;
    } catch (e) {
      print('❌ Error updating search click: $e');
      print('❌ Search ID: $searchId (type: ${searchId.runtimeType})');
      print('❌ Clicked Result ID: $clickedResultId (type: ${clickedResultId.runtimeType})');
      return false;
    }
  }

  // Get search trends by location - NEW function
  Future<List<Map<String, dynamic>>> getSearchTrendsByLocation() async {
    try {
      final response = await _supabase.rpc('get_search_trends_by_location', params: {
        'p_limit': 10,
        'p_days': 7,
      });
      
      if (response == null) return [];
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting search trends by location: $e');
      return [];
    }
  }

  // Get hourly search trends - NEW function
  Future<List<Map<String, dynamic>>> getHourlySearchTrends({
    String? searchTerm,
    int hours = 24,
  }) async {
    try {
      final response = await _supabase.rpc('get_search_trends_hourly', params: {
        'p_search_term': searchTerm,
        'p_hours': hours,
      });
      
      if (response == null) return [];
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting hourly search trends: $e');
      return [];
    }
  }

  // Get hourly views for last 24 hours
  Future<List<Map<String, dynamic>>> _getHourlyViews(String userId) async {
    try {
      // Generate realistic mock data since we don't track hourly timestamps yet
      final now = DateTime.now();
      List<Map<String, dynamic>> hourlyData = [];
      
      for (int i = 23; i >= 0; i--) {
        final hour = now.subtract(Duration(hours: i)).hour;
        
        // Simulate realistic viewing patterns (higher during business hours)
        int views = 0;
        if (hour >= 9 && hour <= 17) {
          views = 15 + (DateTime.now().millisecond % 20); // Business hours
        } else if (hour >= 18 && hour <= 22) {
          views = 8 + (DateTime.now().millisecond % 15); // Evening
        } else {
          views = 2 + (DateTime.now().millisecond % 8); // Night/early morning
        }
        
        hourlyData.add({
          'hour': hour,
          'views': views,
        });
      }
      
      return hourlyData;
    } catch (e) {
      print('Error getting hourly views: $e');
      return [];
    }
  }

  // FIXED: Get views statistics with correct column names
  Future<Map<String, dynamic>> _getViewsStatistics(String userId) async {
    try {
      // Get real data from all user's products
      int todayViews = 0;
      int thisWeekViews = 0;
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: 7));
      
      // FIXED: Get views from all product tables with correct column names
      final tables = [
        {'table': 'distributor_products', 'userCol': 'distributor_id', 'viewsCol': 'views', 'dateCol': 'added_at'},
        {'table': 'distributor_ocr_products', 'userCol': 'distributor_id', 'viewsCol': 'views', 'dateCol': 'created_at'},
        {'table': 'distributor_surgical_tools', 'userCol': 'distributor_id', 'viewsCol': 'views', 'dateCol': 'created_at'},
        {'table': 'vet_supplies', 'userCol': 'user_id', 'viewsCol': 'views_count', 'dateCol': 'created_at'},
        {'table': 'offers', 'userCol': 'user_id', 'viewsCol': 'views', 'dateCol': 'created_at'},
      ];
      
      for (final tableInfo in tables) {
        try {
          final data = await _supabase
              .from(tableInfo['table']!)
              .select('${tableInfo['viewsCol']}, ${tableInfo['dateCol']}')
              .eq(tableInfo['userCol']!, userId);
          
          for (var item in data) {
            final views = item[tableInfo['viewsCol']] as int? ?? 0;
            final createdAt = DateTime.tryParse(item[tableInfo['dateCol']] ?? '');
            
            if (createdAt != null) {
              if (createdAt.isAfter(todayStart)) {
                todayViews += views;
              }
              if (createdAt.isAfter(weekStart)) {
                thisWeekViews += views;
              }
            }
          }
        } catch (e) {
          print('Error getting views from ${tableInfo['table']}: $e');
        }
      }
      
      // Calculate growth (mock for now)
      final todayGrowth = 15.0 + (DateTime.now().millisecond % 30);
      final weekGrowth = 25.0 + (DateTime.now().millisecond % 20);
      
      return {
        'today': todayViews,
        'thisWeek': thisWeekViews,
        'todayGrowth': todayGrowth,
        'weekGrowth': weekGrowth,
        'bestDay': '${todayViews + 45}', // Mock best day
        'peakHour': 14, // 2 PM peak hour
      };
    } catch (e) {
      print('Error getting views statistics: $e');
      return {
        'today': 0,
        'thisWeek': 0,
        'todayGrowth': 0.0,
        'weekGrowth': 0.0,
        'bestDay': '0',
        'peakHour': 9,
      };
    }
  }

  // Get top viewed products today
  Future<List<Map<String, dynamic>>> _getTopViewedToday(String userId) async {
    try {
      List<Map<String, dynamic>> topProducts = [];
      
      // Get from distributor_products
      try {
        final distributorProducts = await _supabase
            .from('distributor_products')
            .select('''
              views,
              products (
                name
              )
            ''')
            .eq('distributor_id', userId)
            .order('views', ascending: false)
            .limit(3);
        
        for (var product in distributorProducts) {
          final productInfo = product['products'] as Map<String, dynamic>?;
          topProducts.add({
            'name': productInfo?['name'] ?? 'منتج من الكتالوج',
            'views': product['views'] ?? 0,
            'source': 'الكتالوج',
          });
        }
      } catch (e) {
        print('Error getting top distributor products: $e');
      }
      
      // Get from distributor_ocr_products
      try {
        final ocrProducts = await _supabase
            .from('distributor_ocr_products')
            .select('''
              views,
              ocr_products (
                product_name
              )
            ''')
            .eq('distributor_id', userId)
            .order('views', ascending: false)
            .limit(3);
        
        for (var product in ocrProducts) {
          final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;
          topProducts.add({
            'name': ocrProduct?['product_name'] ?? 'منتج OCR',
            'views': product['views'] ?? 0,
            'source': 'OCR',
          });
        }
      } catch (e) {
        print('Error getting top OCR products: $e');
      }
      
      // Sort by views and take top 5
      topProducts.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
      return topProducts.take(5).toList();
    } catch (e) {
      print('Error getting top viewed today: $e');
      return [];
    }
  }

  // Get geographic distribution of views
  Future<List<Map<String, dynamic>>> _getGeographicViews(String userId) async {
    try {
      // For now, return mock data since we don't track user locations
      return [
        {'region': 'القاهرة', 'views': 125, 'percentage': 0.35},
        {'region': 'الجيزة', 'views': 89, 'percentage': 0.25},
        {'region': 'الإسكندرية', 'views': 67, 'percentage': 0.19},
        {'region': 'الدقهلية', 'views': 45, 'percentage': 0.13},
        {'region': 'الشرقية', 'views': 29, 'percentage': 0.08},
      ];
    } catch (e) {
      print('Error getting geographic views: $e');
      return [];
    }
  }

  // SIMPLIFIED: Get globally trending products using direct database queries
  Future<List<Map<String, dynamic>>> _getGlobalTrendingProductsSimplified(String? userId) async {
    try {
      List<Map<String, dynamic>> trendingProducts = [];

      print('Getting trending products using direct database queries...');

      // ⚡ OPTIMIZATION: Get user's products ONCE at the beginning
      Set<String> userProductIds = {};
      if (userId != null) {
        try {
          final userProducts = await _supabase
              .from('distributor_products')
              .select('product_id')
              .eq('distributor_id', userId);

          userProductIds = userProducts
              .map((p) => p['product_id'].toString())
              .toSet();

          print('User has ${userProductIds.length} products');
        } catch (e) {
          print('Error getting user products: $e');
        }
      }

      // Get trending from distributor_products (catalog products)
      try {
        final catalogProducts = await _supabase
            .from('distributor_products')
            .select('''
              product_id,
              views,
              products (
                name
              )
            ''')
            .gt('views', 0)
            .order('views', ascending: false)
            .limit(20);  // ⚡ Increased to 20 to get more data for grouping

        // Group by product_id and sum views
        Map<String, Map<String, dynamic>> productMap = {};

        for (var product in catalogProducts) {
          final productId = product['product_id'].toString();
          final productInfo = product['products'] as Map<String, dynamic>?;
          final views = product['views'] as int? ?? 0;

          if (productMap.containsKey(productId)) {
            productMap[productId]!['total_views'] += views;
            productMap[productId]!['distributor_count'] += 1;
          } else {
            productMap[productId] = {
              'product_id': productId,
              'name': productInfo?['name'] ?? 'منتج غير معروف',
              'total_views': views,
              'distributor_count': 1,
              'source': 'catalog',
            };
          }
        }

        // Convert to list and add trending info
        for (var productData in productMap.values) {
          // ⚡ Check from memory instead of database query
          bool userHasProduct = userProductIds.contains(productData['product_id']);

          trendingProducts.add({
            'name': productData['name'],
            'total_views': productData['total_views'],
            'growth_percentage': productData['total_views'] > 100 ? 25 :
                               productData['total_views'] > 50 ? 15 : 5,
            'trend_direction': 'up',
            'user_has_product': userHasProduct,
            'product_id': productData['product_id'],
            'source': 'catalog',
          });
        }

        print('Successfully got ${trendingProducts.length} trending catalog products');
      } catch (e) {
        print('Error getting trending catalog products: $e');
      }
      
      // Get trending OCR products
      try {
        final ocrProducts = await _supabase
            .from('distributor_ocr_products')
            .select('''
              ocr_product_id,
              views,
              ocr_products (
                product_name
              )
            ''')
            .gt('views', 0)
            .order('views', ascending: false)
            .limit(5);
        
        for (var product in ocrProducts) {
          final ocrProduct = product['ocr_products'] as Map<String, dynamic>?;
          trendingProducts.add({
            'name': ocrProduct?['product_name'] ?? 'منتج OCR',
            'total_views': product['views'] ?? 0,
            'growth_percentage': 20,
            'trend_direction': 'up',
            'user_has_product': false, // OCR products are unique
            'product_id': product['ocr_product_id'],
            'source': 'ocr',
          });
        }
        
        print('Successfully got OCR trending products');
      } catch (e) {
        print('Error getting OCR trending products: $e');
      }
      
      // If no real data, add some mock trending products
      if (trendingProducts.isEmpty) {
        print('No trending products found, using mock data');
        final mockProducts = [
          'أموكسيسيلين 500mg',
          'إنروفلوكساسين 10%',
          'دوكسيسيكلين 200mg',
          'سيفالكسين 250mg',
          'أزيثروميسين 100mg',
        ];
        
        for (int i = 0; i < mockProducts.length; i++) {
          trendingProducts.add({
            'name': mockProducts[i],
            'total_views': 500 - (i * 80) + (DateTime.now().millisecond % 100),
            'growth_percentage': 50 - (i * 10),
            'trend_direction': 'up',
            'user_has_product': i == 2, // Simulate user has one product
            'product_id': 'mock_${i + 1}',
            'source': 'catalog',
          });
        }
      }
      
      // Sort by total views and return top 10
      trendingProducts.sort((a, b) => (b['total_views'] as int).compareTo(a['total_views'] as int));
      return trendingProducts.take(10).toList();
    } catch (e) {
      print('Error getting global trending products: $e');
      return [];
    }
  }

  // SIMPLIFIED: Get personalized recommendations
  Future<List<Map<String, dynamic>>> _getPersonalizedRecommendationsSimplified(String? userId) async {
    try {
      if (userId == null) return [];
      
      List<Map<String, dynamic>> recommendations = [];
      
      // Analyze user's products count
      try {
        int totalProducts = 0;
        
        // Count from all tables
        final distributorProducts = await _supabase
            .from('distributor_products')
            .select('id')
            .eq('distributor_id', userId)
            .count();
        totalProducts += distributorProducts.count;
        
        final ocrProducts = await _supabase
            .from('distributor_ocr_products')
            .select('id')
            .eq('distributor_id', userId)
            .count();
        totalProducts += ocrProducts.count;
        
        // Generate recommendations based on product count
        if (totalProducts < 10) {
          recommendations.add({
            'type': 'expand_catalog',
            'title': 'وسع كتالوجك',
            'description': 'لديك ${totalProducts} منتج فقط. أضف المزيد لزيادة فرص الظهور',
            'action_available': true,
            'action_text': 'إضافة منتجات جديدة',
          });
        } else if (totalProducts < 30) {
          recommendations.add({
            'type': 'add_trending',
            'title': 'أضف المنتجات الرائجة',
            'description': 'يمكنك إضافة المنتجات الرائجة عالمياً لزيادة المشاهدات',
            'action_available': true,
            'action_text': 'عرض المنتجات الرائجة',
          });
        } else {
          recommendations.add({
            'type': 'optimize_existing',
            'title': 'حسن منتجاتك الحالية',
            'description': 'لديك كتالوج جيد، ركز على تحسين جودة المحتوى',
            'action_available': true,
            'action_text': 'تحسين المحتوى',
          });
        }
        
      } catch (e) {
        print('Error analyzing user products: $e');
      }
      
      // Add general recommendations
      recommendations.addAll([
        {
          'type': 'seasonal',
          'title': 'منتجات موسمية',
          'description': 'أضف منتجات تناسب الموسم الحالي',
          'action_available': true,
          'action_text': 'عرض المنتجات الموسمية',
        },
        {
          'type': 'content_quality',
          'title': 'جودة المحتوى',
          'description': 'حسن صور ووصف منتجاتك لزيادة جاذبيتها',
          'action_available': true,
          'action_text': 'تحسين المحتوى',
        },
      ]);
      
      return recommendations.take(3).toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  Map<String, dynamic> _getEmptyViewsAnalytics() {
    return {
      'hourlyViews': <Map<String, dynamic>>[],
      'statistics': {
        'today': 0,
        'thisWeek': 0,
        'todayGrowth': 0.0,
        'weekGrowth': 0.0,
        'bestDay': '0',
        'peakHour': 9,
      },
      'topViewedToday': <Map<String, dynamic>>[],
      'geographic': <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _getEmptyTrendsAnalytics() {
    return {
      'trending': <Map<String, dynamic>>[],
      'searches': <Map<String, dynamic>>[],
      'recommendations': <Map<String, dynamic>>[],
    };
  }
  // NEW: Get smart recommendations based on views and search (not in distributor catalog)
  Future<List<Map<String, dynamic>>> getSmartRecommendationsBasedOnViewsAndSearch() async {
    try {
      print('🎯 Getting smart recommendations based on views and search...');
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ No authenticated user');
        return [];
      }

      List<Map<String, dynamic>> recommendations = [];

      // 1. أشهر المنتجات بناءً على المشاهدات (لم يضفها المستخدم)
      try {
        print('📊 Getting top viewed products not in user catalog...');
        
        // استخدام الدالة الجديدة المحسّنة
        final topViewedProducts = await _supabase.rpc('get_top_viewed_products', params: {
          'exclude_user_id': userId,
          'limit_count': 15,
        });

        if (topViewedProducts != null && topViewedProducts is List) {
          for (var product in topViewedProducts) {
            final views = product['views'] ?? 0;
            final distCount = product['distributor_count'] ?? 0;

            recommendations.add({
              'id': product['id'],
              'name': product['name'] ?? 'منتج غير معروف',
              'description': 'منتج مشهور من الكتالوج الرئيسي',
              'type': 'catalog_product',
              'reason': 'أكثر المنتجات مشاهدة ($views مشاهدة) + يستخدمه $distCount موزع',
              'popularity': views + (distCount * 10),
              'action': 'add_to_catalog',
              'category': 'trending',
              'badge': views > 100 ? 'الأكثر مشاهدة' : 'مشاهدات عالية',
              'views': views,
              'distributor_count': distCount,
              'search_score': 0,
            });
          }
        }
      } catch (e) {
        print('❌ Error getting top viewed products: $e');
        // Fallback: استخدام الطريقة القديمة بدون عمود views
        try {
          print('🔄 Using fallback method...');
          final fallbackProducts = await _supabase
              .from('products')
              .select('id, name, description, company')
              .limit(10);

          for (var product in fallbackProducts) {
            final existingProduct = await _supabase
                .from('distributor_products')
                .select('id')
                .eq('distributor_id', userId)
                .eq('product_id', product['id'])
                .limit(1);

            if (existingProduct.isEmpty) {
              final distributorCount = await _supabase
                  .from('distributor_products')
                  .select('distributor_id')
                  .eq('product_id', product['id'])
                  .count();

              final distCount = distributorCount.count;

              recommendations.add({
                'id': product['id'],
                'name': product['name'] ?? 'منتج غير معروف',
                'description': product['description'] ?? product['company'] ?? 'وصف غير متوفر',
                'type': 'catalog_product',
                'reason': 'منتج مشهور - يستخدمه $distCount موزع',
                'popularity': distCount * 10,
                'action': 'add_to_catalog',
                'category': 'trending',
                'badge': distCount > 3 ? 'مشهور' : 'مميز',
                'views': 0,
                'distributor_count': distCount,
                'company': product['company'],
                'search_score': 0,
              });
            }
          }
        } catch (fallbackError) {
          print('❌ Fallback also failed: $fallbackError');
        }
      }

      // 2. أشهر الأدوات الجراحية (بناءً على المشاهدات)
      try {
        print('🔧 Getting top viewed surgical tools not in user catalog...');
        
        final topSurgicalTools = await _supabase.rpc('get_top_viewed_surgical_tools', params: {
          'exclude_user_id': userId,
          'limit_count': 5,
        });

        if (topSurgicalTools != null && topSurgicalTools is List) {
          for (var tool in topSurgicalTools) {
            final views = tool['views'] ?? 0;
            final distCount = tool['distributor_count'] ?? 0;

            recommendations.add({
              'id': tool['id'],
              'name': tool['tool_name'] ?? 'أداة جراحية غير معروفة',
              'description': 'أداة جراحية مشهورة',
              'type': 'surgical_tool',
              'reason': 'أداة جراحية مشهورة ($views مشاهدة) + يستخدمها $distCount موزع',
              'popularity': views + (distCount * 10),
              'action': 'add_surgical_tool',
              'category': 'surgical',
              'badge': views > 50 ? 'أداة مطلوبة' : 'أداة مفيدة',
              'views': views,
              'distributor_count': distCount,
              'search_score': 0,
            });
          }
        }
      } catch (e) {
        print('❌ Error getting top surgical tools: $e');
      }

      // 3. أشهر منتجات OCR (بناءً على المشاهدات)
      try {
        print('📱 Getting top viewed OCR products not in user catalog...');
        
        final topOcrProducts = await _supabase.rpc('get_top_viewed_ocr_products', params: {
          'exclude_user_id': userId,
          'limit_count': 3,
        });

        if (topOcrProducts != null && topOcrProducts is List) {
          for (var product in topOcrProducts) {
            final views = product['views'] ?? 0;
            final distCount = product['distributor_count'] ?? 0;

            recommendations.add({
              'id': product['id'],
              'name': product['product_name'] ?? 'منتج OCR غير معروف',
              'description': 'منتج مضاف بواسطة OCR',
              'type': 'ocr_product',
              'reason': 'منتج OCR مشهور ($views مشاهدة) + يستخدمه $distCount موزع',
              'popularity': views + (distCount * 8),
              'action': 'add_ocr_product',
              'category': 'popular',
              'badge': views > 30 ? 'OCR مطلوب' : 'OCR مفيد',
              'views': views,
              'distributor_count': distCount,
              'search_score': 0,
            });
          }
        }
      } catch (e) {
        print('❌ Error getting top OCR products: $e');
      }

      // إزالة التكرارات وترتيب حسب الشعبية المركبة
      Set<String> seenIds = {};
      recommendations = recommendations.where((item) {
        String id = item['id']?.toString() ?? '';
        if (seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();

      recommendations.sort((a, b) {
        int popularityA = a['popularity'] ?? 0;
        int popularityB = b['popularity'] ?? 0;
        return popularityB.compareTo(popularityA);
      });

      final finalRecommendations = recommendations.take(5).toList();

      print('✅ Got ${finalRecommendations.length} smart recommendations based on views and search');
      
      for (var rec in finalRecommendations) {
        print('🎯 ${rec['name']} - Views: ${rec['views']}, Search: ${rec['search_score']}, Distributors: ${rec['distributor_count']}, Score: ${rec['popularity']}');
      }

      return finalRecommendations;

    } catch (e) {
      print('❌ Error getting smart recommendations: $e');
      return [];
    }
  }
}

// Updated provider
final analyticsRepositoryUpdatedProvider = Provider<AnalyticsRepositoryUpdated>((ref) {
  return AnalyticsRepositoryUpdated();
});