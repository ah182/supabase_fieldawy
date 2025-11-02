import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/services/search_tracking_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/dashboard/data/analytics_repository_updated.dart';


/// Mixin لإضافة تتبع البحث للشاشات المختلفة
/// Search tracking mixin for different screens
mixin SearchTrackingMixin {
  
  /// تسجيل عملية بحث في قاعدة البيانات
  /// Log search activity to database
  Future<String?> trackSearch({
    required WidgetRef ref,
    required String searchTerm,
    required String searchType,
    required int resultCount,
  }) async {
    try {
      if (searchTerm.trim().isEmpty) return null;
      
      final searchTrackingService = ref.read(searchTrackingServiceProvider);
      final currentUser = ref.read(userDataProvider).asData?.value;
      
      // الحصول على موقع المستخدم (أول محافظة في القائمة)
      String? userLocation;
      if (currentUser?.governorates != null && currentUser!.governorates!.isNotEmpty) {
        userLocation = currentUser.governorates!.first;
      }
      
      final searchId = await searchTrackingService.logSearch(
        searchTerm: searchTerm,
        searchType: searchType,
        userLocation: userLocation,
        resultCount: resultCount,
      );
      
      print('🔍 Search tracked: "$searchTerm" (Type: $searchType, Results: $resultCount, ID: $searchId)');
      return searchId;
    } catch (e) {
      print('❌ Error tracking search: $e');
      return null;
    }
  }
  
  /// تسجيل النقر على نتيجة بحث
  /// Log click on search result
  Future<void> trackSearchClick({
    required WidgetRef ref,
    required String? searchId,
    required String clickedItemId,
    String? itemType,
  }) async {
    try {
      if (searchId == null) return;
      
      final searchTrackingService = ref.read(searchTrackingServiceProvider);
      final success = await searchTrackingService.logSearchClick(
        searchId: searchId,
        clickedItemId: clickedItemId,
        itemType: itemType,
      );
      
      if (success) {
        print('👆 Search click tracked: $clickedItemId from search $searchId');
      }
    } catch (e) {
      print('❌ Error tracking search click: $e');
    }
  }
  
  /// تسجيل بحث المنتجات
  /// Track product search
  Future<String?> trackProductSearch({
    required WidgetRef ref,
    required String searchTerm,
    required List results,
  }) async {
    return trackSearch(
      ref: ref,
      searchTerm: searchTerm,
      searchType: 'products',
      resultCount: results.length,
    );
  }
  
  /// تسجيل بحث الموزعين
  /// Track distributor search
  Future<String?> trackDistributorSearch({
    required WidgetRef ref,
    required String searchTerm,
    required List results,
  }) async {
    return trackSearch(
      ref: ref,
      searchTerm: searchTerm,
      searchType: 'distributors',
      resultCount: results.length,
    );
  }
  
  /// تسجيل بحث المستلزمات البيطرية
  /// Track vet supplies search
  Future<String?> trackVetSuppliesSearch({
    required WidgetRef ref,
    required String searchTerm,
    required List results,
  }) async {
    return trackSearch(
      ref: ref,
      searchTerm: searchTerm,
      searchType: 'vet_supplies',
      resultCount: results.length,
    );
  }
  
  /// تسجيل بحث الأدوات الجراحية
  /// Track surgical tools search
  Future<String?> trackSurgicalToolsSearch({
    required WidgetRef ref,
    required String searchTerm,
    required List results,
  }) async {
    return trackSearch(
      ref: ref,
      searchTerm: searchTerm,
      searchType: 'surgical_tools',
      resultCount: results.length,
    );
  }
  
  /// تسجيل بحث العروض
  /// Track offers search
  Future<String?> trackOffersSearch({
    required WidgetRef ref,
    required String searchTerm,
    required List results,
  }) async {
    return trackSearch(
      ref: ref,
      searchTerm: searchTerm,
      searchType: 'offers',
      resultCount: results.length,
    );
  }
  
  /// تسجيل بحث الكورسات
  /// Track courses search
  Future<String?> trackCoursesSearch({
    required WidgetRef ref,
    required String searchTerm,
    required List results,
  }) async {
    return trackSearch(
      ref: ref,
      searchTerm: searchTerm,
      searchType: 'courses',
      resultCount: results.length,
    );
  }
  
  /// تسجيل بحث الكتب
  /// Track books search
  Future<String?> trackBooksSearch({
    required WidgetRef ref,
    required String searchTerm,
    required List results,
  }) async {
    return trackSearch(
      ref: ref,
      searchTerm: searchTerm,
      searchType: 'books',
      resultCount: results.length,
    );
  }
  
  /// تحديد نوع البحث حسب التاب الحالي
  /// Determine search type based on current tab
  String getSearchTypeFromTabIndex(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'products'; // Home Tab
      case 1: return 'products'; // Price Action Tab
      case 2: return 'products'; // Expire Soon Tab
      case 3: return 'surgical_tools'; // Surgical & Diagnostic Tab
      case 4: return 'offers'; // Offers Tab
      case 5: return 'courses'; // Courses Tab
      case 6: return 'books'; // Books Tab
      default: return 'general';
    }
  }

  /// تحسين اسم المنتج بالبحث في الجداول المختلفة (للمستلزمات البيطرية)
  /// Improve product name by searching in different tables (for vet supplies)
  Future<String> improveVetSupplyName(WidgetRef ref, String searchTerm) async {
    try {
      final analyticsRepo = ref.read(analyticsRepositoryUpdatedProvider);
      
      // استخدام نفس الدالة من analytics_repository_updated
      return await analyticsRepo.improveProductName(searchTerm, 'vet_supplies');
    } catch (e) {
      print('❌ Error improving vet supply name: $e');
      return searchTerm;
    }
  }

  /// تحسين اسم المنتج بالبحث في الجداول المختلفة (للموزعين)
  /// Improve product name by searching in different tables (for distributors)
  Future<String> improveDistributorProductName(WidgetRef ref, String searchTerm) async {
    try {
      final analyticsRepo = ref.read(analyticsRepositoryUpdatedProvider);
      
      // استخدام نفس الدالة من analytics_repository_updated
      return await analyticsRepo.improveProductName(searchTerm, 'distributors');
    } catch (e) {
      print('❌ Error improving distributor product name: $e');
      return searchTerm;
    }
  }

  /// تحسين جميع مصطلحات البحث للمستلزمات البيطرية
  /// Improve all search terms for vet supplies
  Future<void> improveAllVetSupplySearchTerms(WidgetRef ref) async {
    try {
      final analyticsRepo = ref.read(analyticsRepositoryUpdatedProvider);
      await analyticsRepo.improveSearchTermsForType('vet_supplies');
    } catch (e) {
      print('❌ Error improving all vet supply search terms: $e');
    }
  }

  /// تحسين جميع مصطلحات البحث للموزعين
  /// Improve all search terms for distributors
  Future<void> improveAllDistributorSearchTerms(WidgetRef ref) async {
    try {
      final analyticsRepo = ref.read(analyticsRepositoryUpdatedProvider);
      await analyticsRepo.improveSearchTermsForType('distributors');
    } catch (e) {
      print('❌ Error improving all distributor search terms: $e');
    }
  }
}