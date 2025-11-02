import 'package:fieldawy_store/features/leaderboard/presentation/screens/leaderboard_screen.dart';
import 'package:fieldawy_store/features/home/application/selected_tab_provider.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/home_tabs_content.dart';
import 'package:fieldawy_store/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fieldawy_store/widgets/product_card.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/product_dialogs.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';

// ✅ إضافة import لنظام تتبع البحث
import 'package:fieldawy_store/services/search_tracking_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';

class _TabInfo {
  const _TabInfo(this.icon, this.text);
  final IconData icon;
  final String text;
}

final _tabsInfo = [
  _TabInfo(Icons.apps_rounded, 'Home'),
  _TabInfo(Icons.trending_up_rounded, 'Price Action'),
  _TabInfo(Icons.schedule_rounded, 'Expire Soon'),
  _TabInfo(Icons.medical_services_outlined, 'Surgical & Diagnostic'),
  _TabInfo(Icons.local_offer_outlined, 'Offers'),
  _TabInfo(Icons.school_rounded, 'Courses'),
  _TabInfo(Icons.menu_book_rounded, 'Books'),
];

class HomeScreenWithSearchTracking extends ConsumerStatefulWidget {
  final int? initialTabIndex;
  final String? distributorId;
  
  const HomeScreenWithSearchTracking({
    super.key,
    this.initialTabIndex,
    this.distributorId,
  });

  @override
  ConsumerState<HomeScreenWithSearchTracking> createState() => _HomeScreenWithSearchTrackingState();
}

class _HomeScreenWithSearchTrackingState extends ConsumerState<HomeScreenWithSearchTracking>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  
  // ✅ متغيرات نظام تتبع البحث
  String? _currentSearchId;
  String _lastSearchTerm = '';
  Timer? _searchTrackingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabsInfo.length,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );

    // ✅ إعداد debounced search مع تتبع البحث المحسن
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });

      // تطبيق debouncing للبحث فقط (بدون تتبع تلقائي)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_searchController.text == _searchQuery) {
          setState(() {
            _debouncedSearchQuery = _searchController.text;
          });
          
          // ✅ تسجيل البحث فقط للكلمات المكتملة (3 أحرف أو أكثر)
          // ولا يتم الحفظ إلا عند التوقف عن الكتابة لفترة طويلة
          _scheduleSearchTracking(_searchController.text);
        }
      });
    });

    _focusNode.addListener(() {
      setState(() {});
      if (!_focusNode.hasFocus) {
        // إخفاء النص الشبحي عند فقدان التركيز إذا كان مربع البحث فارغاً
        if (_searchController.text.isEmpty) {
          setState(() {
            _searchQuery = '';
            _debouncedSearchQuery = '';
          });
        }
      }
    });

    // مزامنة الفهرس المحدد مع provider
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        ref.read(selectedTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _searchTrackingTimer?.cancel();
    super.dispose();
  }

  // ✅ جدولة تتبع البحث - يحفظ فقط عند التوقف عن الكتابة
  void _scheduleSearchTracking(String searchTerm) {
    // إلغاء المؤقت السابق
    _searchTrackingTimer?.cancel();
    
    // التحقق من صحة البحث قبل الجدولة
    if (!_shouldTrackSearch(searchTerm)) {
      return;
    }
    
    // جدولة تتبع البحث بعد توقف طويل (2.5 ثانية)
    _searchTrackingTimer = Timer(const Duration(milliseconds: 2500), () {
      // التحقق مرة أخرى قبل الحفظ
      if (_searchController.text == searchTerm && _shouldTrackSearch(searchTerm)) {
        _trackSearchIfNeeded(searchTerm);
      }
    });
  }

  // ✅ فحص ما إذا كان يجب تتبع البحث
  bool _shouldTrackSearch(String searchTerm) {
    final cleanTerm = searchTerm.trim();
    
    // لا تحفظ النصوص الفارغة
    if (cleanTerm.isEmpty) return false;
    
    // لا تحفظ النصوص القصيرة جداً (أقل من 3 أحرف)
    if (cleanTerm.length < 3) return false;
    
    // لا تحفظ إذا كان نفس البحث السابق
    if (cleanTerm == _lastSearchTerm) return false;
    
    // لا تحفظ النصوص التي تحتوي على أحرف متكررة كثيرة (مثل "aaa")
    if (_isRepeatedCharacters(cleanTerm)) return false;
    
    // لا تحفظ الكلمات غير المكتملة (تنتهي بحروف مفردة)
    if (_isIncompleteWord(cleanTerm)) return false;
    
    return true;
  }

  // ✅ فحص الأحرف المتكررة
  bool _isRepeatedCharacters(String text) {
    if (text.length < 3) return false;
    
    // إذا كان أكثر من 60% من النص نفس الحرف
    final char = text[0].toLowerCase();
    final count = text.toLowerCase().split('').where((c) => c == char).length;
    return count / text.length > 0.6;
  }

  // ✅ فحص الكلمات غير المكتملة
  bool _isIncompleteWord(String text) {
    final lowerText = text.toLowerCase();
    
    // قائمة بادايات الكلمات الشائعة التي لا يجب حفظها
    final incompletePatterns = [
      'est', 'str', 'tra', 'pre', 'pro', 'ant', 'con', 'dis', 'int', 'exp',
      'act', 'inf', 'def', 'ref', 'eff', 'aff', 'suf', 'sup', 'sub', 'abs',
      'أس', 'إس', 'أن', 'إن', 'أم', 'إم', 'أت', 'إت', 'أب', 'إب',
      'مض', 'مس', 'مر', 'مل', 'مع', 'مق', 'مك', 'مط', 'مف', 'مغ'
    ];
    
    // إذا كان النص مطابقاً لأحد الأنماط غير المكتملة
    return incompletePatterns.any((pattern) => lowerText == pattern);
  }

  // ✅ دالة تتبع البحث المحسنة (مع فلاتر)
  Future<void> _trackSearchIfNeeded(String searchTerm) async {
    // فحص نهائي قبل الحفظ
    if (!_shouldTrackSearch(searchTerm)) {
      return;
    }

    await _performSearchTracking(searchTerm.trim(), isImmediate: false);
  }

  // ✅ تتبع البحث الفوري (عند الضغط على Enter - يتجاوز بعض الفلاتر)
  Future<void> _trackSearchIfNeededImmediate(String searchTerm) async {
    // فحص أساسي فقط للحفظ الفوري
    if (searchTerm.isEmpty || searchTerm.length < 2) {
      return;
    }

    // تجاهل التكرار للحفظ الفوري (المستخدم ضغط Enter عمداً)
    await _performSearchTracking(searchTerm, isImmediate: true);
  }

  // ✅ تنفيذ عملية التتبع الفعلية
  Future<void> _performSearchTracking(String searchTerm, {required bool isImmediate}) async {
    try {
      final searchTrackingService = ref.read(searchTrackingServiceProvider);
      final currentTabIndex = _tabController.index;
      
      // تحديد نوع البحث حسب التبويب الحالي
      String searchType = _getSearchTypeFromTab(currentTabIndex);
      
      // محاكاة عدد النتائج (في التطبيق الحقيقي، ستحصل على العدد الفعلي)
      int resultCount = await _simulateSearchResults(searchTerm, currentTabIndex);
      
      // تسجيل عملية البحث
      final searchId = await searchTrackingService.logSearch(
        searchTerm: searchTerm,
        searchType: searchType,
        userLocation: SearchHelper.getMockUserLocation(),
        resultCount: resultCount,
      );
      
      // حفظ معرف البحث الحالي
      _currentSearchId = searchId;
      _lastSearchTerm = searchTerm;
      
      final trackingType = isImmediate ? 'IMMEDIATE' : 'AUTO';
      print('✅ Search tracked [$trackingType]: "$searchTerm" in $searchType tab ($resultCount results)');
    } catch (e) {
      print('❌ Error tracking search: $e');
    }
  }

  // ✅ تحديد نوع البحث حسب التبويب
  String _getSearchTypeFromTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'general'; // Home
      case 1: return 'products'; // Price Action
      case 2: return 'products'; // Expire Soon
      case 3: return 'surgical_tools'; // Surgical & Diagnostic
      case 4: return 'offers'; // Offers
      case 5: return 'courses'; // Courses
      case 6: return 'books'; // Books
      default: return 'general';
    }
  }

  // ✅ محاكاة عدد نتائج البحث
  Future<int> _simulateSearchResults(String searchTerm, int tabIndex) async {
    try {
      // في التطبيق الحقيقي، ستحصل على العدد الفعلي من قاعدة البيانات
      // هنا نستخدم محاكاة بسيطة
      if (searchTerm.length < 3) return 0;
      
      // محاكاة نتائج حسب نوع التبويب
      switch (tabIndex) {
        case 1: // Price Action
        case 2: // Expire Soon
          return (searchTerm.length * 3) + DateTime.now().millisecond % 20;
        case 3: // Surgical Tools
          return (searchTerm.length * 2) + DateTime.now().millisecond % 15;
        case 4: // Offers
          return (searchTerm.length * 1) + DateTime.now().millisecond % 10;
        case 5: // Courses
          return DateTime.now().millisecond % 8;
        case 6: // Books
          return DateTime.now().millisecond % 12;
        default: // Home/General
          return (searchTerm.length * 4) + DateTime.now().millisecond % 25;
      }
    } catch (e) {
      return 0;
    }
  }

  // ✅ تتبع النقر على نتيجة البحث
  Future<void> _trackSearchClick(String itemId, String itemType) async {
    if (_currentSearchId == null) return;
    
    try {
      final searchTrackingService = ref.read(searchTrackingServiceProvider);
      await searchTrackingService.logSearchClick(
        searchId: _currentSearchId!,
        clickedItemId: itemId,
        itemType: itemType,
      );
      
      print('👆 Search click tracked: $itemId');
    } catch (e) {
      print('❌ Error tracking search click: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final selectedTabIndex = ref.watch(selectedTabProvider);
    
    // مزامنة فهرس التبويب مع الـ provider
    if (_tabController.index != selectedTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && selectedTabIndex < _tabsInfo.length) {
          _tabController.animateTo(selectedTabIndex);
        }
      });
    }

    return userData.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('خطأ: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userDataProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
      data: (user) => DefaultTabController(
        length: _tabsInfo.length,
        child: Scaffold(
          appBar: AppBar(
            // ✅ تحديث شريط البحث ليتضمن تتبع البحث
            title: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: _focusNode.hasFocus ? 2 : 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                // ✅ تتبع البحث الفوري عند الضغط على Enter (تجاوز كل الفلاتر)
                onSubmitted: (value) async {
                  _focusNode.unfocus();
                  _searchTrackingTimer?.cancel(); // إلغاء أي مؤقت منتظر
                  await _trackSearchIfNeededImmediate(value.trim());
                },
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: _getSearchHintForTab(_tabController.index),
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _debouncedSearchQuery = '';
                            });
                            _focusNode.unfocus();
                            // إعادة تعيين تتبع البحث
                            _searchTrackingTimer?.cancel();
                            _currentSearchId = null;
                            _lastSearchTerm = '';
                          },
                          tooltip: 'مسح البحث',
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            actions: [
              // Dashboard Button
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DashboardPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.dashboard_outlined),
                  tooltip: 'Dashboard',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // Leaderboard Button
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LeaderboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.leaderboard_outlined),
                  tooltip: 'Leaderboard',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: _tabsInfo.map((tabInfo) {
                return Tab(
                  icon: Icon(tabInfo.icon),
                  text: tabInfo.text.tr(),
                );
              }).toList(),
            ),
          ),
          body: GestureDetector(
            // إخفاء الكيبورد عند اللمس خارج شريط البحث
            onTap: () {
              if (_focusNode.hasFocus) {
                _focusNode.unfocus();
              }
            },
            child: TabBarView(
              controller: _tabController,
              children: [
                // ✅ تمرير دالة تتبع النقر للتبويبات
                _KeepAlive(child: _HomeTabWithTracking(
                  searchQuery: _debouncedSearchQuery,
                  onItemTap: _trackSearchClick,
                )),
                _KeepAlive(child: _PriceUpdateTab(searchQuery: _debouncedSearchQuery)),
                _KeepAlive(child: ExpireSoonTab(searchQuery: _debouncedSearchQuery)),
                _KeepAlive(child: SurgicalDiagnosticTab(searchQuery: _debouncedSearchQuery)),
                _KeepAlive(child: OffersTab(searchQuery: _debouncedSearchQuery)),
                _KeepAlive(child: CoursesTab(searchQuery: _debouncedSearchQuery)),
                _KeepAlive(child: BooksTab(searchQuery: _debouncedSearchQuery)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ تخصيص نص البحث حسب التبويب
  String _getSearchHintForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'ابحث عن دواء، مادة فعالة...';
      case 1: return 'ابحث في تحديثات الأسعار...';
      case 2: return 'ابحث في المنتجات منتهية الصلاحية...';
      case 3: return 'ابحث في الأدوات الجراحية...';
      case 4: return 'ابحث في العروض...';
      case 5: return 'ابحث في الكورسات...';
      case 6: return 'ابحث في الكتب...';
      default: return 'ابحث عن دواء، مادة فعالة...';
    }
  }
}

// ✅ تبويب الصفحة الرئيسية مع تتبع البحث
class _HomeTabWithTracking extends ConsumerWidget {
  final String searchQuery;
  final Function(String, String)? onItemTap;

  const _HomeTabWithTracking({
    required this.searchQuery,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProductsAsync = ref.watch(allDistributorProductsProvider);

    return allProductsAsync.when(
      loading: () => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const ProductCardShimmer(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ: ${err.toString()}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (products) {
        // تطبيق البحث
        final filteredProducts = searchQuery.isEmpty
            ? products
            : products.where((product) {
                final query = searchQuery.toLowerCase();
                return product.name.toLowerCase().contains(query) ||
                    (product.activePrinciple ?? '').toLowerCase().contains(query) ||
                    (product.company ?? '').toLowerCase().contains(query);
              }).toList();

        if (filteredProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty
                      ? Icons.inventory_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? 'لا توجد منتجات متاحة'
                      : 'لا توجد نتائج للبحث عن "$searchQuery"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(allDistributorProductsProvider.future),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return ViewTrackingProductCard(
                product: product,
                searchQuery: searchQuery,
                productType: 'home',
                trackViewOnVisible: true,
                // ✅ تتبع النقر على المنتج
                onTap: () {
                  // تسجيل النقر في نظام التتبع
                  onItemTap?.call(product.id, 'product');
                  
                  // عرض تفاصيل المنتج
                  showProductDialog(context, product);
                },
              );
            },
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }
}

// Simple PriceUpdateTab placeholder widget
class _PriceUpdateTab extends ConsumerWidget {
  const _PriceUpdateTab({required this.searchQuery});
  
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Price Update Tab - Coming Soon'),
        ],
      ),
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