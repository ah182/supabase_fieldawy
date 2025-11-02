import 'dart:math';
import 'package:fieldawy_store/features/dashboard/data/analytics_repository_updated.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// خدمة تتبع عمليات البحث لتحليل الاتجاهات والترندات
/// Service for tracking search activities to analyze trends
class SearchTrackingService {
  final AnalyticsRepositoryUpdated _analyticsRepo;
  String? _currentSessionId;
  final List<String> _searchHistory = [];

  SearchTrackingService(this._analyticsRepo) {
    _generateNewSession();
  }

  /// إنشاء جلسة بحث جديدة
  /// Generate new search session
  void _generateNewSession() {
    _currentSessionId = const Uuid().v4();
  }

  /// تسجيل عملية بحث جديدة
  /// Log a new search activity
  Future<String?> logSearch({
    required String searchTerm,
    required String searchType,
    String? userLocation,
    int resultCount = 0,
  }) async {
    try {
      // تنظيف مصطلح البحث
      final cleanedTerm = _cleanSearchTerm(searchTerm);
      if (cleanedTerm.isEmpty) return null;

      // إضافة للتاريخ المحلي
      _searchHistory.add(cleanedTerm);
      if (_searchHistory.length > 50) {
        _searchHistory.removeAt(0); // الاحتفاظ بآخر 50 عملية بحث
      }

      // تسجيل في قاعدة البيانات
      final searchId = await _analyticsRepo.logSearchActivity(
        searchTerm: cleanedTerm,
        searchType: searchType,
        searchLocation: userLocation,
        resultCount: resultCount,
        sessionId: _currentSessionId,
      );

      print('🔍 Search logged: "$cleanedTerm" (Type: $searchType, Results: $resultCount)');
      return searchId;
    } catch (e) {
      print('❌ Error logging search: $e');
      return null;
    }
  }

  /// تسجيل النقر على نتيجة بحث
  /// Log click on search result
  Future<bool> logSearchClick({
    required String searchId,
    required String clickedItemId,
    String? itemType,
  }) async {
    try {
      final success = await _analyticsRepo.updateSearchClick(searchId, clickedItemId);
      
      if (success) {
        print('👆 Search click logged: $clickedItemId from search $searchId');
      }
      
      return success;
    } catch (e) {
      print('❌ Error logging search click: $e');
      return false;
    }
  }

  /// تسجيل بحث المنتجات
  /// Log product search
  Future<String?> logProductSearch({
    required String searchTerm,
    required List results,
    String? userLocation,
  }) async {
    return await logSearch(
      searchTerm: searchTerm,
      searchType: 'products',
      userLocation: userLocation,
      resultCount: results.length,
    );
  }

  /// تسجيل بحث الموزعين
  /// Log distributor search
  Future<String?> logDistributorSearch({
    required String searchTerm,
    required List results,
    String? userLocation,
  }) async {
    return await logSearch(
      searchTerm: searchTerm,
      searchType: 'distributors',
      userLocation: userLocation,
      resultCount: results.length,
    );
  }

  /// تسجيل بحث الفئات
  /// Log category search
  Future<String?> logCategorySearch({
    required String searchTerm,
    required List results,
    String? userLocation,
  }) async {
    return await logSearch(
      searchTerm: searchTerm,
      searchType: 'categories',
      userLocation: userLocation,
      resultCount: results.length,
    );
  }

  /// تسجيل بحث عام
  /// Log general search
  Future<String?> logGeneralSearch({
    required String searchTerm,
    required List results,
    String? userLocation,
  }) async {
    return await logSearch(
      searchTerm: searchTerm,
      searchType: 'general',
      userLocation: userLocation,
      resultCount: results.length,
    );
  }

  /// الحصول على اقتراحات البحث من التاريخ المحلي
  /// Get search suggestions from local history
  List<String> getSearchSuggestions(String partial) {
    if (partial.length < 2) return [];
    
    final suggestions = _searchHistory
        .where((term) => term.contains(partial.toLowerCase()))
        .toSet() // إزالة التكرارات
        .take(8)
        .toList();
    
    return suggestions;
  }

  /// الحصول على الكلمات المتكررة من التاريخ المحلي
  /// Get frequent terms from local history
  List<String> getFrequentSearchTerms() {
    final termCounts = <String, int>{};
    
    for (final term in _searchHistory) {
      termCounts[term] = (termCounts[term] ?? 0) + 1;
    }
    
    final sortedTerms = termCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTerms.take(10).map((e) => e.key).toList();
  }

  /// مسح تاريخ البحث المحلي
  /// Clear local search history
  void clearSearchHistory() {
    _searchHistory.clear();
    _generateNewSession();
  }

  /// تنظيف مصطلح البحث
  /// Clean search term
  String _cleanSearchTerm(String term) {
    return term
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ') // استبدال المسافات المتعددة بمسافة واحدة
        .replaceAll(RegExp(r'[^\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFFa-zA-Z0-9\s\-_]'), ''); // الاحتفاظ بالعربي والإنجليزي والأرقام فقط
  }

  /// الحصول على إحصائيات الجلسة الحالية
  /// Get current session statistics
  Map<String, dynamic> getSessionStats() {
    final uniqueTerms = _searchHistory.toSet().length;
    final totalSearches = _searchHistory.length;
    
    return {
      'session_id': _currentSessionId,
      'total_searches': totalSearches,
      'unique_terms': uniqueTerms,
      'search_diversity': uniqueTerms > 0 ? (uniqueTerms / totalSearches) : 0.0,
      'recent_terms': _searchHistory.take(5).toList(),
    };
  }
}

/// Provider للخدمة
/// Service provider
final searchTrackingServiceProvider = Provider<SearchTrackingService>((ref) {
  final analyticsRepo = ref.watch(analyticsRepositoryUpdatedProvider);
  return SearchTrackingService(analyticsRepo);
});

/// مساعد لتسجيل عمليات البحث المختلفة
/// Helper for logging different search types
class SearchHelper {
  static final _random = Random();
  
  /// محاكاة موقع المستخدم إذا لم يكن متوفراً
  /// Simulate user location if not available
  static String? getMockUserLocation() {
    final locations = [
      'القاهرة', 'الجيزة', 'الإسكندرية', 'الدقهلية', 'الشرقية',
      'الغربية', 'المنوفية', 'القليوبية', 'كفر الشيخ', 'دمياط',
      'البحيرة', 'المنيا', 'أسيوط', 'سوهاج', 'الأقصر'
    ];
    
    return locations[_random.nextInt(locations.length)];
  }
  
  /// تحليل نوع البحث من المصطلح
  /// Analyze search type from term
  static String analyzeSearchType(String searchTerm) {
    final term = searchTerm.toLowerCase();
    
    if (term.contains('دكتور') || term.contains('طبيب') || term.contains('عيادة')) {
      return 'clinics';
    } else if (term.contains('موزع') || term.contains('شركة') || term.contains('مورد')) {
      return 'distributors';
    } else if (term.contains('عرض') || term.contains('خصم') || term.contains('تخفيض')) {
      return 'offers';
    } else if (term.contains('أدوات') || term.contains('جراحي') || term.contains('معدات')) {
      return 'surgical_tools';
    } else if (term.contains('بيطري') || term.contains('حيوان') || term.contains('قطط') || term.contains('كلاب')) {
      return 'vet_supplies';
    } else {
      return 'products';
    }
  }
  
  /// اقتراح كلمات مفتاحية ذات صلة
  /// Suggest related keywords
  static List<String> getRelatedKeywords(String searchTerm) {
    final term = searchTerm.toLowerCase();
    final relatedTerms = <String>[];
    
    // خريطة الكلمات ذات الصلة
    final relatedMap = {
      'مضاد': ['مضاد حيوي', 'مضاد التهاب', 'مضاد فطري', 'مضاد فيروسي'],
      'حيوي': ['مضاد حيوي', 'أموكسيسيلين', 'بنسلين', 'سيفالكسين'],
      'فيتامين': ['فيتامينات', 'فيتامين د', 'فيتامين ب', 'مكملات غذائية'],
      'قطط': ['أدوية قطط', 'طعام قطط', 'علاج قطط', 'لقاحات قطط'],
      'كلاب': ['أدوية كلاب', 'طعام كلاب', 'علاج كلاب', 'لقاحات كلاب'],
      'حقن': ['حقن بيطرية', 'حقن عضلية', 'حقن وريدية', 'سرنجات'],
      'جراحي': ['أدوات جراحية', 'معدات جراحية', 'مشارط', 'خيوط جراحية'],
    };
    
    for (final key in relatedMap.keys) {
      if (term.contains(key)) {
        relatedTerms.addAll(relatedMap[key]!);
      }
    }
    
    return relatedTerms.take(5).toList();
  }
}