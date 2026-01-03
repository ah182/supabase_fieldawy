// ignore_for_file: unused_import

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:collection/collection.dart';
import 'package:fieldawy_store/features/leaderboard/presentation/screens/leaderboard_screen.dart';
import 'package:fieldawy_store/features/home/presentation/mixins/search_tracking_mixin.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/application/favorites_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/profile_screen.dart';
import 'package:fieldawy_store/features/stories/application/stories_provider.dart';
import 'package:fieldawy_store/features/stories/application/story_filters_provider.dart';
import 'package:fieldawy_store/main.dart';
import 'package:fieldawy_store/widgets/product_card.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:fieldawy_store/widgets/user_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/user_data_provider.dart';
import '../widgets/home_tabs_content.dart';
import '../widgets/product_dialogs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/courses/application/courses_provider.dart';
import 'package:fieldawy_store/features/books/application/books_provider.dart';
import 'package:fieldawy_store/features/products/application/expire_drugs_provider.dart';
import 'package:fieldawy_store/features/products/application/surgical_tools_home_provider.dart';
import 'package:fieldawy_store/features/products/application/offers_home_provider.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:fieldawy_store/features/products/presentation/widgets/smart_alternatives_section.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/search_history_view.dart';
import 'package:fieldawy_store/features/home/application/search_history_provider.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/quick_filters_bar.dart';
import 'package:fieldawy_store/features/home/application/search_filters_provider.dart';
import 'package:fieldawy_store/features/stories/presentation/widgets/stories_bar.dart';



class _TabInfo {
  const _TabInfo(this.icon, this.text);
  final IconData icon;
  final String text;
}

class HomeScreen extends ConsumerStatefulWidget {
  final int? initialTabIndex;
  final String? distributorId;
  
  const HomeScreen({
    super.key,
    this.initialTabIndex,
    this.distributorId,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, SearchTrackingMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  bool _hasNavigatedToDistributor = false;
  String? _currentSearchId; // ID البحث الحالي لتتبع النقرات
  
  Timer? _debounce;
  Timer? _countdownTimer;
  
  String _ghostText = '';
  String _fullSuggestion = '';

  String _getCurrentTabId() {
    switch (_tabController.index) {
      case 0: return 'home';
      case 1: return 'price_action';
      case 2: return 'expire_soon';
      case 3: return 'surgical';
      case 4: return 'offers';
      case 5: return 'courses';
      case 6: return 'books';
      default: return 'home';
    }
  }

  // دالة لعرض الستوريهات في ديالوج جذاب
  void _showStoriesDialog(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    bool showStoryFilters = false; // حالة محلية للتحكم في ظهور الفلتر داخل الديالوج
    
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      body: StatefulBuilder( // استخدام StatefulBuilder للتحكم في حالة الفلتر داخل الديالوج
        builder: (context, setDialogState) {
          return Consumer(
            builder: (context, ref, child) {
              final storiesAsync = ref.watch(storiesProvider);
              final storyFilters = ref.watch(storyFiltersProvider); // مراقبة فلتر الستوري
              final isFilterActive = storyFilters.isNearest || storyFilters.selectedGovernorate != null;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isAr ? 'استوري الموزعين' : 'Distributor Stories',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // بادج العدد
                              storiesAsync.maybeWhen(
                                data: (groups) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${groups.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // أيقونة الفلتر
                            IconButton(
                              icon: Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: isFilterActive ? Theme.of(context).colorScheme.primary : Colors.grey,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  showStoryFilters = !showStoryFilters;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // الفلاتر المخصصة للستوري
                    if (showStoryFilters) ...[
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: QuickFiltersBar(showCheapest: false, useStoryFilters: true),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 16),
                    const SizedBox(
                      height: 100,
                      child: StoriesBar(limitItems: true),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isAr ? 'إغلاق' : 'Close'),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            },
          );
        }
      ),
    ).show();
  }

  // دالة لعرض سجل البحث في ديالوج جذاب (في الأعلى)
  void _showSearchHistoryDialog(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final tabId = _getCurrentTabId();
    
    final history = ref.read(searchHistoryProvider)[tabId] ?? [];
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'لا يوجد سجل بحث حالياً' : 'No search history available')),
      );
      return;
    }

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      alignment: const Alignment(0, -0.5), // موضع متوازن
      body: SearchHistoryView(
        tabId: tabId,
        onClose: () => Navigator.pop(context),
        onTermSelected: (term) {
          _searchController.text = term;
          setState(() {
            _searchQuery = term;
            _debouncedSearchQuery = term;
          });
          ref.read(searchHistoryProvider.notifier).addSearchTerm(term, tabId);
          Navigator.pop(context);
          _focusNode.unfocus();
        },
      ),
    ).show();
  }

  // دالة لعرض الفلاتر السريعة في ديالوج جذاب (في الأعلى)
  void _showSearchFiltersDialog(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      alignment: const Alignment(0, -0.5), // موضع متوازن
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAr ? 'الفلاتر السريعة' : 'Quick Filters',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                // زر مسح الكل للفلاتر (مباشر بدون Consumer إضافي للسرعة)
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Consumer(
                      builder: (context, ref, child) {
                        final filters = ref.watch(searchFiltersProvider);
                        final hasActiveFilters = filters.isCheapest || filters.isNearest || filters.selectedGovernorate != null;
                        
                        if (!hasActiveFilters) return const SizedBox.shrink();
                        
                        return InkWell(
                          onTap: () {
                            ref.read(searchFiltersProvider.notifier).resetFilters();
                            // لا نحتاج لغلق وفتح الديالوج، التحديث سيتم تلقائياً
                          },
                          child: Text(
                            isAr ? 'مسح الكل' : 'Clear All',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ],
            ),

            const SizedBox(height: 16),
            const QuickFiltersBar(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).show();
  }

  List<_TabInfo> _getTabs() {
    return [
      _TabInfo(Icons.apps_rounded, 'home.tabs.home'.tr()),
      _TabInfo(Icons.trending_up_rounded, 'home.tabs.price_action'.tr()),
      _TabInfo(Icons.schedule_rounded, 'home.tabs.expire_soon'.tr()),
      _TabInfo(Icons.medical_services_outlined, 'home.tabs.surgical'.tr()),
      _TabInfo(Icons.local_offer_outlined, 'home.tabs.offers'.tr()),
      _TabInfo(Icons.school_rounded, 'home.tabs.courses'.tr()),
      _TabInfo(Icons.menu_book_rounded, 'home.tabs.books'.tr()),
    ];
  }

  // دالة مساعدة لبناء أزرار البحث الجذابة (أيقونات داخل بادج متدرج عند التفعيل - مصغرة جداً)
  Widget _buildSearchActionButton({
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    List<Color>? gradientColors,
    bool isEnabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: isEnabled ? () {
        HapticFeedback.lightImpact();
        onTap();
      } : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: (isActive && isEnabled && gradientColors != null)
              ? LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isEnabled 
              ? (isActive 
                  ? (gradientColors == null ? color : null) 
                  : (isDark ? Colors.white.withOpacity(0.08) : color.withOpacity(0.05)))
              : Colors.grey.withOpacity(0.1),
          boxShadow: (isActive && isEnabled) ? [
            BoxShadow(
              color: (gradientColors?.last ?? color).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ] : [],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isEnabled 
              ? (isActive 
                  ? Colors.white 
                  : (isDark ? Colors.white70 : color.withOpacity(0.6))) // توضيح الأيقونة أكثر في الدارك
              : Colors.grey.withOpacity(0.4),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // استخدام initialTabIndex إذا تم توفيره من الإشعار
    final initialIndex = widget.initialTabIndex ?? 0;
    _tabController = TabController(
      length: 7, 
      vsync: this,
      initialIndex: initialIndex.clamp(0, 6),
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
        
        // إخفاء الكيبورد عند تغيير التاب
        _hideKeyboard();
        
        // إعادة تعيين النص الشبحي عند تغيير التاب
        setState(() {
          _ghostText = '';
          _fullSuggestion = '';
        });
      }
    });
    
    // التنقل لصفحة الموزع إذا تم توفير distributorId من الإشعار
    if (widget.distributorId != null && !_hasNavigatedToDistributor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToDistributor(widget.distributorId!);
      });
    }

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      
      // إخفاء الكيبورد عند التمرير
      _hideKeyboard();
      
      final threshold = _scrollController.position.maxScrollExtent - 200;
      final state = ref.read(paginatedProductsProvider);

      if (_scrollController.position.pixels >= threshold &&
          !state.isLoading &&
          state.hasMore) {
        ref.read(paginatedProductsProvider.notifier).fetchNextPage();
      }
    });

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 1000), () { // تقليل التأخير  ثانية
        if (mounted) {
          setState(() {
            _debouncedSearchQuery = _searchController.text;
          });
          
          // تتبع البحث فقط إذا كان النص ليس فارغاً وطوله 3 حروف أو أكثر
          if (_searchController.text.trim().length >= 3) {
            _trackCurrentSearch();
          }
        }
      });
    });

    // إضافة listener للـ focus node لتحسين تجربة المستخدم
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          // تحديث الواجهة عند تغيير حالة الـ focus
        });
        
        // تأثيرات haptic عند التركيز وإلغاء التركيز
        if (_focusNode.hasFocus) {
          HapticFeedback.selectionClick();
        } else {
          // تتبع البحث النهائي عند فقدان التركيز
          if (_searchController.text.trim().length >= 3) {
            _trackCurrentSearch();
          }
          
          // إخفاء النص الشبحي عند فقدان التركيز إذا كان مربع البحث فارغاً
          if (_searchController.text.isEmpty) {
            _ghostText = '';
            _fullSuggestion = '';
          }
        }
      }
    });
  }

  /// تتبع البحث الحالي في قاعدة البيانات
  /// Track current search in database
  Future<void> _trackCurrentSearch() async {
    if (_debouncedSearchQuery.trim().isEmpty) {
      _currentSearchId = null;
      return;
    }

    try {
      // التحقق من أن الـ widget لا يزال موجوداً
      if (!mounted) return;
      
      // تحديد نوع البحث حسب التاب الحالي
      final searchType = getSearchTypeFromTabIndex(_tabController.index);
      
      // الحصول على النتائج المفلترة لحساب العدد
      final filteredProducts = _getFilteredProductsForCurrentTab();
      
      print('🔍 Tracking search: "${_debouncedSearchQuery}" (Type: $searchType, Results: ${filteredProducts.length})');
      
      // تتبع البحث
      _currentSearchId = await trackSearch(
        ref: ref,
        searchTerm: _debouncedSearchQuery,
        searchType: searchType,
        resultCount: filteredProducts.length,
      );
      
      // التحقق مرة أخرى بعد العملية غير المتزامنة
      if (!mounted) return;
      
      if (_currentSearchId != null) {
        print('✅ Search tracked with ID: $_currentSearchId');
      } else {
        print('❌ Failed to track search: no ID returned');
      }
    } catch (e) {
      print('❌ Error tracking search: $e');
    }
  }

  /// الحصول على المنتجات المفلترة للتاب الحالي
  /// Get filtered products for current tab
  List _getFilteredProductsForCurrentTab() {
    final allProductsForSearch = ref.read(allDistributorProductsProvider).asData?.value ?? [];
    final query = _debouncedSearchQuery.toLowerCase().trim();
    
    if (query.isEmpty) return allProductsForSearch;

    return allProductsForSearch.where((product) {
      final productName = product.name.toLowerCase();
      final distributorName = (product.distributorId ?? '').toLowerCase();
      final activePrinciple = (product.activePrinciple ?? '').toLowerCase();
      final packageSize = (product.selectedPackage ?? '').toLowerCase();
      final company = (product.company ?? '').toLowerCase();
      final description = (product.description ?? '').toLowerCase();
      final action = (product.action ?? '').toLowerCase();

      return productName.contains(query) ||
          activePrinciple.contains(query) ||
          distributorName.contains(query) ||
          company.contains(query) ||
          packageSize.contains(query) ||
          description.contains(query) ||
          action.contains(query);
    }).toList();
  }

  void _navigateToDistributor(String distributorIdOrName) async {
    if (_hasNavigatedToDistributor) return;
    
    print('📍 التنقل لصفحة الموزع: $distributorIdOrName');
    
    // التأكد من أن context متاح
    if (!mounted) return;
    
    try {
      final supabase = Supabase.instance.client;
      
      // التحقق مما إذا كان المدخل UUID
      final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false)
          .hasMatch(distributorIdOrName);
          
      String resolvedId = distributorIdOrName;
      String resolvedName = 'Distributor';
      
      if (isUuid) {
        // إذا كان UUID، نجلب الاسم
        final response = await supabase
            .from('users')
            .select('display_name')
            .eq('id', distributorIdOrName)
            .maybeSingle();
        resolvedName = response?['display_name'] ?? 'Distributor';
      } else {
        // إذا كان اسماً، نجلب الـ UUID
        // في حالة "gamal ahmed"، هذا هو المسار الصحيح
        final response = await supabase
            .from('users')
            .select('id, display_name')
            .eq('display_name', distributorIdOrName)
            .maybeSingle();
            
        if (response != null) {
          resolvedId = response['id'];
          resolvedName = response['display_name'];
        } else {
            print('❌ لم يتم العثور على موزع بهذا الاسم: $distributorIdOrName');
            _hasNavigatedToDistributor = false;
            // يمكن إضافة SnackBar هنا لإبلاغ المستخدم
            return;
        }
      }
      
      if (!mounted) return;
      
      // فتح صفحة منتجات الموزع
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DistributorProductsScreen(
            distributorId: resolvedId,
            distributorName: resolvedName,
          ),
        ),
      );
      _hasNavigatedToDistributor = true;
    } catch (e) {
      print('❌ خطأ في جلب بيانات الموزع: $e');
      _hasNavigatedToDistributor = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // دالة مساعدة لإخفاء الكيبورد
  void _hideKeyboard() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      HapticFeedback.lightImpact();
      setState(() {
        if (_searchController.text.isEmpty) {
          _ghostText = '';
          _fullSuggestion = '';
        }
      });
    }
  }

  // دالة للحصول على منتجات التاب الحالي للنص الشبحي
  List<ProductModel> _getCurrentTabProducts() {
    final allProductsForSearch = ref.read(allDistributorProductsProvider).asData?.value ?? [];
    final currentTabIndex = _tabController.index;
    
    try {
      switch (currentTabIndex) {
        case 0: // Home Tab
          return allProductsForSearch;
        case 1: // Price Action Tab
          return _getPriceActionProducts();
        case 2: // Expire Soon Tab
          return _getExpireSoonProducts();
        case 3: // Surgical & Diagnostic Tab
          return _getSurgicalProducts();
        case 4: // Offers Tab
          return _getOffersProducts();
        case 5: // Courses Tab
          // للكورسات، نحتاج لإنشاء منتجات وهمية للنص الشبحي
          return _createDummyProductsFromCourses();
        case 6: // Books Tab
          // للكتب، نحتاج لإنشاء منتجات وهمية للنص الشبحي
          return _createDummyProductsFromBooks();
        default:
          return allProductsForSearch;
      }
    } catch (e) {
      // في حالة حدوث خطأ، إرجاع جميع المنتجات
      return allProductsForSearch;
    }
  }

  // دالة لإنشاء منتجات وهمية من الكورسات للنص الشبحي
  List<ProductModel> _createDummyProductsFromCourses() {
    try {
      final coursesAsync = ref.read(allCoursesNotifierProvider);
      return coursesAsync.when(
        data: (courses) => courses.map((course) => ProductModel(
          id: course.id,
          name: course.title,
          imageUrl: course.imageUrl,
          price: course.price,
          distributorId: 'course',
          activePrinciple: course.description,
          availablePackages: [],
        )).toList(),
        loading: () => <ProductModel>[],
        error: (_, __) => <ProductModel>[],
      );
    } catch (e) {
      return <ProductModel>[];
    }
  }

  // دالة لإنشاء منتجات وهمية من الكتب للنص الشبحي
  List<ProductModel> _createDummyProductsFromBooks() {
    try {
      final booksAsync = ref.read(allBooksNotifierProvider);
      return booksAsync.when(
        data: (books) => books.map((book) => ProductModel(
          id: book.id,
          name: book.name,
          imageUrl: book.imageUrl,
          price: book.price,
          distributorId: 'book',
          activePrinciple: book.author,
          company: book.description,
          availablePackages: [],
        )).toList(),
        loading: () => <ProductModel>[],
        error: (_, __) => <ProductModel>[],
      );
    } catch (e) {
      return <ProductModel>[];
    }
  }

  // دالة للحصول على منتجات منتهية الصلاحية
  List<ProductModel> _getExpireSoonProducts() {
    try {
      final expireDrugsAsync = ref.read(expireDrugsProvider);
      return expireDrugsAsync.when(
        data: (items) => items.map((item) => item.product).toList(),
        loading: () => <ProductModel>[],
        error: (_, __) => <ProductModel>[],
      );
    } catch (e) {
      return <ProductModel>[];
    }
  }

  // دالة للحصول على الأدوات الجراحية
  List<ProductModel> _getSurgicalProducts() {
    try {
      final toolsAsync = ref.read(surgicalToolsHomeProvider);
      return toolsAsync.when(
        data: (tools) => tools.map((tool) => ProductModel(
          id: tool.id,
          name: tool.name,
          imageUrl: tool.imageUrl,
          price: tool.price,
          distributorId: tool.distributorId ?? 'surgical',
          activePrinciple: tool.activePrinciple,
          company: tool.company,
          description: tool.description,
          availablePackages: [],
        )).toList(),
        loading: () => <ProductModel>[],
        error: (_, __) => <ProductModel>[],
      );
    } catch (e) {
      return <ProductModel>[];
    }
  }

  // دالة للحصول على منتجات العروض
  List<ProductModel> _getOffersProducts() {
    try {
      final offersAsync = ref.read(offersHomeProvider);
      return offersAsync.when(
        data: (items) => items.map((item) => item.product).toList(),
        loading: () => <ProductModel>[],
        error: (_, __) => <ProductModel>[],
      );
    } catch (e) {
      return <ProductModel>[];
    }
  }

  // دالة للحصول على منتجات تحديث الأسعار
  List<ProductModel> _getPriceActionProducts() {
    try {
      final priceUpdatesAsync = ref.read(priceUpdatesProvider);
      return priceUpdatesAsync.when(
        data: (products) => products,
        loading: () => <ProductModel>[],
        error: (_, __) => <ProductModel>[],
      );
    } catch (e) {
      return <ProductModel>[];
    }
  }



  int _calculateSearchScore(ProductModel product, String query) {
    int score = 0;
    final productName = product.name.toLowerCase();
    final activePrinciple = (product.activePrinciple ?? '').toLowerCase();
    final distributorName = (product.distributorId ?? '').toLowerCase();
    final company = (product.company ?? '').toLowerCase();
    final packageSize = (product.selectedPackage ?? '').toLowerCase();
    final description = (product.description ?? '').toLowerCase();

    if (productName.contains(query)) score += 10;
    if (activePrinciple.contains(query)) score += 8;
    if (distributorName.contains(query)) score += 6;
    if (company.contains(query)) score += 4;
    if (packageSize.contains(query)) score += 2;
    if (description.contains(query)) score += 2;
    if (productName.startsWith(query)) score += 5;
    if (activePrinciple.startsWith(query)) score += 3;
    if (distributorName.startsWith(query)) score += 3;

    return score;
  }

  void _showProductDetailDialog(
      BuildContext context, WidgetRef ref, ProductModel product) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Material(
              type: MaterialType.transparency,
              child: _buildProductDetailDialog(context, ref, product),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation1,
            curve: Curves.elasticOut,
          ),
          child: FadeTransition(
            opacity: animation1,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildProductDetailDialog(
      BuildContext context, WidgetRef ref, ProductModel product) {
    String? role;
    bool isLoadingRole = true;
    String? latestDistributorName;

    return StatefulBuilder(
      builder: (context, setState) {
        // دالة لجلب بيانات المستخدم (الدور والاسم الأحدث) إذا لم تكن متوفرة في الـ provider
        Future<void> loadUserRole() async {
          if (product.distributorUuid == null || !isLoadingRole) return;
          try {
            final response = await Supabase.instance.client
                .from('users')
                .select('role, display_name')
                .eq('id', product.distributorUuid!)
                .maybeSingle();
            if (context.mounted) {
              setState(() {
                role = response?['role']?.toString();
                isLoadingRole = false;
              });
            }
          } catch (e) {
            if (context.mounted) setState(() => isLoadingRole = false);
          }
        }

        // تشغيل الجلب
        loadUserRole();

        final size = MediaQuery.of(context).size;
        final isSmallScreen = size.width < 600;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Consumer(
          builder: (context, ref, child) {
            // جلب أحدث اسم للموزع من الـ provider لضمان التحديث الفوري
            final distributorsAsync = ref.watch(distributorsProvider);
            latestDistributorName = distributorsAsync.maybeWhen(
              data: (distributors) {
                final dist = distributors.firstWhereOrNull((d) => d.id == product.distributorUuid);
                return dist?.displayName;
              },
              orElse: () => null,
            );

            // الاسم النهائي للعرض
            final displayName = latestDistributorName ?? product.distributorId;

            String formatPackageText(String package) {
              final currentLocale = Localizations.localeOf(context).languageCode;
              if (currentLocale == 'ar' &&
                  package.toLowerCase().contains(' ml') &&
                  package.toLowerCase().contains('vial')) {
                final parts = package.split(' ');
                if (parts.length >= 3) {
                  final number = parts.firstWhere(
                      (part) => RegExp(r'^\d+').hasMatch(part),
                      orElse: () => '');
                  final unit = parts.firstWhere(
                      (part) => part.toLowerCase().contains(' ml'),
                      orElse: () => '');
                  final container = parts.firstWhere(
                      (part) => part.toLowerCase().contains('vial'),
                      orElse: () => '');
                  if (number.isNotEmpty && unit.isNotEmpty && container.isNotEmpty) {
                    return '$number$unit $container';
                  }
                }
              }
              return package;
            }

            final containerColor = isDark
                ? Colors.grey.shade800.withOpacity(0.5)
                : Colors.white.withOpacity(0.8);
            final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
            final priceColor =
                isDark ? Colors.lightGreenAccent.shade200 : Colors.green.shade700;
                 final favoriteColor =
                 isDark ? Colors.redAccent.shade100 : Colors.red.shade400;
            final packageBgColor = isDark
                ? const Color.fromARGB(255, 216, 222, 249).withOpacity(0.1)
                : Colors.blue.shade50.withOpacity(0.8);
            final packageBorderColor = isDark
                ? const Color.fromARGB(255, 102, 126, 162)
                : Colors.blue.shade200;
            final imageBgColor = isDark
                ? const Color.fromARGB(255, 21, 15, 15).withOpacity(0.3)
                : Colors.white.withOpacity(0.7);
            final backgroundColor =
                isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE3F2FD);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: isSmallScreen ? size.width * 0.95 : 400,
                height: size.height * 0.85,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.grey.shade600.withOpacity(0.3)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: containerColor,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.arrow_back, color: iconColor),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              Row(
                                children: [
                                  if (product.distributorUuid != null) ...[
                                    GestureDetector(
                                      onTap: () {
                                        if (role == 'doctor') {
                                          UserDetailsSheet.show(context, ref, product.distributorUuid!);
                                        } else {
                                          DistributorDetailsSheet.show(
                                              context, product.distributorUuid!);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          role == 'doctor' ? Icons.person : Icons.location_on,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  GestureDetector(
                                    onTap: () async {
                                      if (role == 'doctor') {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('تنبيه'),
                                            content: Text('هذا المنتج تمت إضافته بواسطة طبيب، والأطباء ليس لديهم كتالوج منتجات خاص بهم.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text('حسناً'),
                                              ),
                                            ],
                                          ),
                                        );
                                        return;
                                      }
                                      if (displayName != null) {
                                        // Show loading indicator
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(child: CircularProgressIndicator()),
                                        );

                                        // Small delay for UX
                                        await Future.delayed(const Duration(milliseconds: 400));

                                        if (!context.mounted) return;
                                        Navigator.of(context).pop(); // Close loading
                                        Navigator.of(context).pop(); // Close the original dialog
                                        
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) => DrawerWrapper(
                                              distributorId: displayName,
                                            ),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        displayName ??
                                            'home.product_dialog.unknown_distributor'.tr(),
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (product.company != null && product.company!.isNotEmpty)
                            Text(
                              product.company!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (product.activePrinciple != null &&
                              product.activePrinciple!.isNotEmpty)
                            Text(
                              product.activePrinciple!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Text(
                                  '${product.price?.toStringAsFixed(0) ?? '0'} ${'EGP'.tr()}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: priceColor,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Consumer(
                                builder: (context, ref, child) {
                                  final favoritesMap = ref.watch(favoritesProvider);
                                  final isFavorite = favoritesMap.containsKey(
                                      '${product.id}_${product.distributorId}_${product.selectedPackage}');
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: containerColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFavorite ? Colors.red : favoriteColor,
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(favoritesProvider.notifier)
                                            .toggleFavorite(product);
                                        scaffoldMessengerKey.currentState?.showSnackBar(
                                          SnackBar(
                                            elevation: 0,
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: Colors.transparent,
                                            content: AwesomeSnackbarContent(
                                              title: 'Favorite Status',
                                              key: ValueKey(
                                                  'favorite_snackbar_${DateTime.now().millisecondsSinceEpoch}'),
                                              message: isFavorite
                                                  ? 'تمت إزالة ${product.name} من المفضلة'
                                                  : 'تمت إضافة ${product.name} للمفضلة',
                                              contentType: isFavorite
                                                  ? ContentType.failure
                                                  : ContentType.success,
                                            ),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: RepaintBoundary(
                              child: Container(
                                height: 250,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: imageBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: ImageLoadingIndicator(size: 50),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 60,
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'home.product_dialog.active_principle'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: '',
                                  style: TextStyle(
                                    color: Colors.transparent,
                                  ),
                                ),
                                TextSpan(
                                  text: product.activePrinciple ?? 'غير محدد',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (product.selectedPackage != null &&
                              product.selectedPackage!.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: packageBgColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: packageBorderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                      color: isDark
                                          ? const Color.fromARGB(255, 6, 149, 245)
                                          : const Color.fromARGB(255, 4, 90, 160),
                                    ),
                                    const SizedBox(width: 8),
                                    Directionality(
                                      textDirection: ui.TextDirection.ltr,
                                      child: Text(
                                        formatPackageText(product.selectedPackage!),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // === Smart Alternatives Section ===
                          SmartAlternativesSection(
                            product: product,
                            onProductTap: (altProduct) {
                              Navigator.of(context).pop(); // Close current dialog
                              // Small delay to allow dialog to close smoothly
                              Future.delayed(const Duration(milliseconds: 100), () {
                                if (mounted) {
                                  _showProductDetailDialog(context, ref, altProduct);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primaryContainer.withOpacity(0.3),
                                    theme.colorScheme.secondaryContainer
                                        .withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'home.product_dialog.medical_info_note'.tr(),
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontSize: 16,
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isAr = Localizations.localeOf(context).languageCode == 'ar'; // تعريف المتغير هنا
    final paginatedState = ref.watch(paginatedProductsProvider);
    final products = paginatedState.products;
    final allDistributorProductsAsync =
        ref.watch(allDistributorProductsProvider);
    final currentUserAsync = ref.watch(userDataProvider);
    final distributorsAsync = ref.watch(distributorsProvider);
    final query = _debouncedSearchQuery.toLowerCase().trim();

    final allProductsForSearch =
        allDistributorProductsAsync.asData?.value ?? [];
    
    // جلب المنتجات منتهية الصلاحية لاستبعادها من بحث الهوم
    final expireSoonItems = ref.watch(expireDrugsProvider).asData?.value ?? [];
    final expireSoonIds = expireSoonItems.map((item) => item.product.id).toSet();

    final List<ProductModel> productsToFilter =
        query.isNotEmpty 
            ? (_tabController.index == 0 
                ? allProductsForSearch.where((p) => !expireSoonIds.contains(p.id)).toList()
                : allProductsForSearch)
            : products;

    // إنشاء Map للموزعين لسهولة الوصول
    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    final filteredProducts = () {
      final filters = ref.watch(searchFiltersProvider); // مراقبة حالة الفلاتر
      
      List<ProductModel> list = query.isEmpty ? productsToFilter : productsToFilter.where((product) {
        final productName = product.name.toLowerCase();
        final distributorName = (product.distributorId ?? '').toLowerCase();
        final activePrinciple = (product.activePrinciple ?? '').toLowerCase();
        final packageSize = (product.selectedPackage ?? '').toLowerCase();
        final company = (product.company ?? '').toLowerCase();
        final description = (product.description ?? '').toLowerCase();
        final action = (product.action ?? '').toLowerCase();

        return productName.contains(query) ||
            activePrinciple.contains(query) ||
            distributorName.contains(query) ||
            company.contains(query) ||
            packageSize.contains(query) ||
            description.contains(query) ||
            action.contains(query);
      }).toList();

      // إنشاء نسخة قابلة للتعديل من القائمة لإصلاح خطأ Cannot modify an unmodifiable list
      list = List<ProductModel>.from(list);

      // 1. فلترة المحافظة (إذا تم اختيار محافظة)
      if (filters.selectedGovernorate != null) {
        list = list.where((product) {
          final distributor = distributorsMap[product.distributorUuid ?? product.distributorId];
          if (distributor == null) return false;
          final List<String> govList = List<String>.from(distributor.governorates ?? []);
          return govList.contains(filters.selectedGovernorate);
        }).toList();
      }

      // 2. الترتيب (Sorting)
      list.sort((a, b) {
        // أ) الترتيب حسب السعر (لو فلتر الأرخص مفعل)
        if (filters.isCheapest) {
          final priceA = a.price ?? double.infinity;
          final priceB = b.price ?? double.infinity;
          if (priceA != priceB) return priceA.compareTo(priceB);
        }

        // ب) الترتيب حسب القرب الجغرافي (لو فلتر الأقرب مفعل أو كترتيب ثانوي)
        final currentUser = currentUserAsync.asData?.value;
        if (currentUser != null && distributorsMap.isNotEmpty) {
          final distributorA = distributorsMap[a.distributorUuid ?? a.distributorId];
          final distributorB = distributorsMap[b.distributorUuid ?? b.distributorId];

          if (distributorA != null && distributorB != null) {
            final proximityA = LocationProximity.calculateProximityScore(
              userGovernorates: currentUser.governorates,
              userCenters: currentUser.centers,
              distributorGovernorates: distributorA.governorates,
              distributorCenters: distributorA.centers,
            );

            final proximityB = LocationProximity.calculateProximityScore(
              userGovernorates: currentUser.governorates,
              userCenters: currentUser.centers,
              distributorGovernorates: distributorB.governorates,
              distributorCenters: distributorB.centers,
            );

            if (proximityA != proximityB) return proximityB.compareTo(proximityA);
          }
        }

        // ج) الترتيب حسب قوة البحث (Search Score) كخيار أخير
        if (query.isNotEmpty) {
          final scoreA = _calculateSearchScore(a, query);
          final scoreB = _calculateSearchScore(b, query);
          return scoreB.compareTo(scoreA);
        }

        return 0;
      });

      return list;
    }();

    Widget homeTabContent = RefreshIndicator(
      onRefresh: () => ref.read(paginatedProductsProvider.notifier).refresh(),
      child: () {
        if (products.isEmpty && !paginatedState.hasMore && query.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text('home.search.no_products'.tr()),
              ],
            ),
          );
        }

        if (paginatedState.isLoading && products.isEmpty || (paginatedState.isLoading && !paginatedState.hasMore)) {
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => const ProductCardShimmer(),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          );
        }

        if (query.isNotEmpty && allDistributorProductsAsync.isLoading) {
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => const ProductCardShimmer(),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          );
        }

        // إضافة عرض رسالة "لا توجد نتائج" عند الفلترة
        if (filteredProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 80, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'home.search.no_results'.tr(namedArgs: {'query': query.isNotEmpty ? query : 'الفلاتر المختارة'}),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                if (ref.watch(searchFiltersProvider).isCheapest || 
                    ref.watch(searchFiltersProvider).isNearest || 
                    ref.watch(searchFiltersProvider).selectedGovernorate != null)
                  TextButton(
                    onPressed: () => ref.read(searchFiltersProvider.notifier).resetFilters(),
                    child: Text(isAr ? 'إعادة تعيين الفلاتر' : 'Reset Filters'),
                  ),
              ],
            ),
          );
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = filteredProducts[index];
                    return RepaintBoundary(
                      child: _KeepAlive(
                        child: ViewTrackingProductCard(
                          key: ValueKey('${product.id}_search'), // مفتاح فريد لضمان إعادة إنشاء الحالة عند تغير المنتج
                          product: product,
                          searchQuery: _debouncedSearchQuery, // جعل كارت البحث يبدو مثل الكارت العادي بدون علامة البحث
                          productType: 'search_result', // نوع مخصص للبحث لتتبع المشاهدات بشكل مستقل
                          trackViewOnVisible: true, // تفعيل تتبع المشاهدة عند الظهور في البحث
                          onTap: () {
                            // تتبع النقرة على المنتج إذا كان هناك بحث نشط
                            if (_currentSearchId != null && _debouncedSearchQuery.isNotEmpty) {
                              print('👆 Tracking click: Product ID: ${product.id}, Search ID: $_currentSearchId');
                              trackSearchClick(
                                ref: ref,
                                searchId: _currentSearchId,
                                clickedItemId: product.id,
                                itemType: 'product',
                              );
                            } else {
                              print('⚠️ No search tracking - Search ID: $_currentSearchId, Query: $_debouncedSearchQuery');
                            }
                            _showProductDetailDialog(context, ref, product);
                          },
                        ),
                      ),
                    );
                  },
                  childCount: filteredProducts.length,
                ),
              ),
            ),
            if (paginatedState.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: ProductCardShimmer()),
                ),
              ),
          ],
        );
      }(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // إخفاء الكيبورد عند اللمس خارج شريط البحث
        _hideKeyboard();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                centerTitle: false, // لضمان بقاء العنوان جهة اليسار بجانب الأيقونة
                titleSpacing: 0, // إزالة المسافة الافتراضية
                title: Text(
                  'home_label'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                pinned: true,
                floating: false,
                snap: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    // إخفاء الكيبورد عند فتح القائمة الجانبية
                    _hideKeyboard();
                    ZoomDrawer.of(context)!.toggle();
                  },
                ),
                actions: [
                  // --- أيقونة الستوري ---
                  Consumer(
                    builder: (context, ref, child) {
                      final storiesAsync = ref.watch(storiesProvider);
                      return storiesAsync.maybeWhen(
                        data: (groups) {
                          // Always show the icon, even if groups is empty
                          return IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(),
                            icon: Stack(
                              children: [
                                Icon(Icons.emergency_recording_rounded, 
                                  color: Theme.of(context).colorScheme.primary, 
                                  size: 22 
                                ),
                                if (groups.isNotEmpty)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(minWidth: 7, minHeight: 7),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: () => _showStoriesDialog(context),
                          );
                        },
                        // Show icon even in loading/error state to prevent layout jump
                        orElse: () => IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.emergency_recording_rounded, 
                              color: Theme.of(context).colorScheme.primary, 
                              size: 22 
                            ),
                            onPressed: () => _showStoriesDialog(context),
                          ),
                      );
                    }
                  ),
                  // --- أيقونة الليدربورد ---
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.emoji_events, size: 22), // تم إزالة const من هنا
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LeaderboardScreen(),
                        ),
                      );
                    },
                  ),
                  // --- صورة الملف الشخصي ---
                  Consumer(
                    builder: (context, ref, child) {
                      final userDataAsync = ref.watch(userDataProvider);
                      return userDataAsync.when(
                        data: (user) {
                          if (user?.photoUrl != null &&
                              user!.photoUrl!.isNotEmpty) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12, left: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 14, // زيادة 1 بكسل (الإجمالي 2 بكسل في القطر)
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: user.photoUrl!,
                                      width: 28, // زيادة 2 بكسل
                                      height: 28, // زيادة 2 بكسل
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary),
                                      errorWidget: (context, url, error) => Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (error, stack) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(130), // ارتفاع ثابت وبسيط
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Row(
                          children: [
                            // شريط البحث
                            Expanded(
                              child: Stack(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        ref.read(searchHistoryProvider.notifier).addSearchTerm(value, _getCurrentTabId());
                                      }
                                      _focusNode.unfocus();
                                    },
                                    onTap: () {
                                      if (!_focusNode.hasFocus) {
                                        HapticFeedback.selectionClick();
                                      }
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                        if (value.isNotEmpty) {
                                          List<ProductModel> currentTabProducts = _getCurrentTabProducts();
                                          final filtered = currentTabProducts.where((product) {
                                            final productName = product.name.toLowerCase();
                                            return productName.startsWith(value.toLowerCase());
                                          }).toList();
                                          if (filtered.isNotEmpty) {
                                            final suggestion = filtered.first;
                                            _ghostText = suggestion.name;
                                            _fullSuggestion = suggestion.name;
                                          } else {
                                            _ghostText = '';
                                            _fullSuggestion = '';
                                          }
                                        } else {
                                          _ghostText = '';
                                          _fullSuggestion = '';
                                        }
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'home.search.hint'.tr(),
                                      hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: _focusNode.hasFocus 
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        size: 22,
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                  _ghostText = '';
                                                  _fullSuggestion = '';
                                                });
                                                HapticFeedback.lightImpact();
                                              },
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: Theme.of(context).brightness == Brightness.dark
                                          ? Theme.of(context).colorScheme.surface.withOpacity(0.8)
                                          : Theme.of(context).colorScheme.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3), width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3), width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                  // الجوست تيكست
                                  if (_ghostText.isNotEmpty && _focusNode.hasFocus)
                                    Positioned(
                                      top: 12,
                                      right: 37,
                                     
                                      child: AnimatedOpacity(
                                        opacity: _searchQuery.isNotEmpty ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: GestureDetector(
                                          onTap: () {
                                            if (_fullSuggestion.isNotEmpty) {
                                              _searchController.text = _fullSuggestion;
                                              setState(() {
                                                _searchQuery = _fullSuggestion;
                                                _debouncedSearchQuery = _fullSuggestion;
                                                _ghostText = '';
                                                _fullSuggestion = '';
                                              });
                                              ref.read(searchHistoryProvider.notifier).addSearchTerm(_searchController.text, _getCurrentTabId());
                                              HapticFeedback.selectionClick();
                                              _focusNode.requestFocus();
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.auto_awesome, size: 12, color: Theme.of(context).colorScheme.primary),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    _ghostText,
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.primary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // أزرار الأكشن (ديالوج السجل والفلتر)
                            const SizedBox(width: 8),
                            Consumer(
                              builder: (context, ref, child) {
                                final filters = ref.watch(searchFiltersProvider);
                                final history = ref.watch(searchHistoryProvider)[_getCurrentTabId()] ?? [];
                                final isFilterActive = filters.isCheapest || filters.isNearest || filters.selectedGovernorate != null;
                                final isHistoryActive = history.contains(_searchQuery) && _searchQuery.isNotEmpty;

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSearchActionButton(
                                      icon: Icons.history_rounded,
                                      color: Colors.indigo,
                                      isActive: isHistoryActive,
                                      gradientColors: [Colors.indigo, Colors.blueAccent],
                                      onTap: () => _showSearchHistoryDialog(context),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildSearchActionButton(
                                      icon: Icons.tune_rounded,
                                      color: Colors.teal,
                                      isActive: isFilterActive,
                                      gradientColors: [Colors.teal, Colors.cyan.shade600],
                                      isEnabled: !(_tabController.index == 5 || _tabController.index == 6),
                                      // تعطيل الفلتر في تاب الكورسات (5) والكتب (6)
                                      onTap: (_tabController.index == 5 || _tabController.index == 6) 
                                          ? () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(isAr ? 'الفلترة غير متاحة في هذا القسم' : 'Filters not available in this section'),
                                                  duration: const Duration(seconds: 1),
                                                ),
                                              );
                                            }
                                          : () => _showSearchFiltersDialog(context),
                                    ),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,

                          /// Indicator بشكل أنيق مع Gradient + حواف ناعمة
                          indicator: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),

                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 5),

                          labelColor: Colors.white,
                          unselectedLabelColor:
                              Theme.of(context).colorScheme.onSurface.withOpacity(0.6),

                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          dividerColor: Colors.transparent,

                          tabs: _getTabs().map((tab) {
                            return Tab(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(tab.icon, size: 14),
                                    const SizedBox(width: 3),
                                    Text(tab.text),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              homeTabContent,
              PriceUpdateTab(searchQuery: _debouncedSearchQuery),
              ExpireSoonTab(searchQuery: _debouncedSearchQuery),
              SurgicalDiagnosticTab(searchQuery: _debouncedSearchQuery),
              OffersTab(searchQuery: _debouncedSearchQuery),
              CoursesTab(searchQuery: _debouncedSearchQuery),
              BooksTab(searchQuery: _debouncedSearchQuery),
            ],
          ),
        ),
      ),
    );
  }
}

class PriceUpdateTab extends ConsumerWidget {
  const PriceUpdateTab({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceUpdatesAsync = ref.watch(priceUpdatesProvider);
    final filters = ref.watch(searchFiltersProvider); // مراقبة الفلاتر
    final currentUserAsync = ref.watch(userDataProvider);
    final distributorsAsync = ref.watch(distributorsProvider);

    // إنشاء Map للموزعين
    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    return priceUpdatesAsync.when(
      loading: () => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.6,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ProductCardShimmer(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      error: (err, stack) => Center(
        child: Text('Error: ${err.toString()}'),
      ),
      data: (products) {
        // 1. فلترة البحث
        var list = searchQuery.isEmpty
            ? products
            : products.where((product) {
                final query = searchQuery.toLowerCase();
                return product.name.toLowerCase().contains(query) ||
                    (product.activePrinciple ?? '')
                        .toLowerCase()
                        .contains(query) ||
                    (product.company ?? '').toLowerCase().contains(query);
              }).toList();

        // 2. فلترة المحافظة
        if (filters.selectedGovernorate != null) {
          list = list.where((product) {
            final distributor = distributorsMap[product.distributorUuid ?? product.distributorId];
            if (distributor == null) return false;
            final List<String> govList = List<String>.from(distributor.governorates ?? []);
            return govList.contains(filters.selectedGovernorate);
          }).toList();
        }

        // 3. الترتيب
        list = List<ProductModel>.from(list); // نسخة قابلة للتعديل
        list.sort((a, b) {
          if (filters.isCheapest) {
            final priceA = a.price ?? double.infinity;
            final priceB = b.price ?? double.infinity;
            if (priceA != priceB) return priceA.compareTo(priceB);
          }

          final currentUser = currentUserAsync.asData?.value;
          if (currentUser != null && distributorsMap.isNotEmpty) {
            final distributorA = distributorsMap[a.distributorUuid ?? a.distributorId];
            final distributorB = distributorsMap[b.distributorUuid ?? b.distributorId];

            if (distributorA != null && distributorB != null) {
              final proximityA = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorA.governorates,
                distributorCenters: distributorA.centers,
              );

              final proximityB = LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributorB.governorates,
                distributorCenters: distributorB.centers,
              );

              if (proximityA != proximityB) return proximityB.compareTo(proximityA);
            }
          }
          return 0;
        });

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty
                      ? Icons.update_disabled_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? 'home.search.no_price_updates'.tr()
                      : 'home.search.no_results'.tr(namedArgs: {'query': searchQuery}),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(priceUpdatesProvider);
            await ref.read(priceUpdatesProvider.future);
          },
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.6,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final product = list[index];
              return ViewTrackingProductCard(
                product: product,
                searchQuery: searchQuery,
                productType: 'price_action',
                showPriceChange: true,
                trackViewOnVisible: true,
                onTap: () {
                  (context as Element)
                      .findAncestorStateOfType<_HomeScreenState>()
                      ?._showProductDetailDialog(context, ref, product);
                },
              );
            },
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
