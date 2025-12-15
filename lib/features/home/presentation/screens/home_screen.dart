// ignore_for_file: unused_import

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
import 'package:fieldawy_store/main.dart';
import 'package:fieldawy_store/widgets/product_card.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/user_data_provider.dart';
import '../widgets/home_tabs_content.dart';
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
      _debounce = Timer(const Duration(milliseconds: 1000), () { // تأخير ثانية واحدة
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
        case 1: // Price Action Tab - استخدام جميع المنتجات حالياً
          return allProductsForSearch;
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
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                              onTap: () => DistributorDetailsSheet.show(
                                  context, product.distributorUuid!),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          GestureDetector(
                            onTap: () {
                              if (product.distributorId != null) {
                                Navigator.of(context).pop(); // Close the dialog
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => DrawerWrapper(
                                      distributorId: product.distributorId,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
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
                                product.distributorId ??
                                    'home.product_dialog.unknown_distributor'.tr(),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
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
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: imageBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.contain,
                          memCacheWidth: 800,
                          memCacheHeight: 800,
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
                        TextSpan(
                          text: '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedProductsProvider);
    final products = paginatedState.products;
    final allDistributorProductsAsync =
        ref.watch(allDistributorProductsProvider);
    final currentUserAsync = ref.watch(userDataProvider);
    final distributorsAsync = ref.watch(distributorsProvider);
    final query = _debouncedSearchQuery.toLowerCase().trim();

    final allProductsForSearch =
        allDistributorProductsAsync.asData?.value ?? [];
    final List<ProductModel> productsToFilter =
        query.isNotEmpty ? allProductsForSearch : products;

    // إنشاء Map للموزعين لسهولة الوصول
    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    final filteredProducts = () {
      if (query.isEmpty) return productsToFilter;

      final list = productsToFilter.where((product) {
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

      // ترتيب أولي حسب نتيجة البحث
      list.sort((a, b) {
        final scoreA = _calculateSearchScore(a, query);
        final scoreB = _calculateSearchScore(b, query);
        return scoreB.compareTo(scoreA);
      });

      // ترتيب ثانوي حسب القرب الجغرافي
      final currentUser = currentUserAsync.asData?.value;
      if (currentUser != null && distributorsMap.isNotEmpty) {
        list.sort((a, b) {
          final distributorA = distributorsMap[a.distributorId];
          final distributorB = distributorsMap[b.distributorId];

          if (distributorA == null && distributorB == null) return 0;
          if (distributorA == null) return 1;
          if (distributorB == null) return -1;

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

          // ترتيب تنازلي - الأقرب أولاً
          return proximityB.compareTo(proximityA);
        });
      }

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

        if (paginatedState.isLoading && products.isEmpty) {
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

        if (filteredProducts.isEmpty && query.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off_outlined,
                    size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text('home.search.no_results'.tr(namedArgs: {'query': _debouncedSearchQuery})),
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
                          searchQuery: _debouncedSearchQuery,
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
                title: Text('home_label'.tr()),
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
                  IconButton(
                    icon: const Icon(Icons.emoji_events),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LeaderboardScreen(),
                        ),
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final userDataAsync = ref.watch(userDataProvider);
                      return userDataAsync.when(
                        data: (user) {
                          if (user?.photoUrl != null &&
                              user!.photoUrl!.isNotEmpty) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18.0)
                                      .add(const EdgeInsets.only(top: 4.0)),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    child: ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: user.photoUrl!,
                                        width: 29,
                                        height: 29,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          width: 29,
                                          height: 29,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (error, stack) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(120),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          // حماية منطقة شريط البحث من إخفاء الكيبورد
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              // منع إخفاء الكيبورد عند اللمس على شريط البحث
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (value) {
                                // عند الضغط على زر البحث في لوحة المفاتيح، إخفاء الكيبورد
                                _focusNode.unfocus();
                              },
                              onTap: () {
                                // تحسين تجربة التفاعل عند النقر على مربع البحث
                                if (!_focusNode.hasFocus) {
                                  HapticFeedback.selectionClick();
                                }
                              },
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  if (value.isNotEmpty) {
                                    // الحصول على قائمة المنتجات حسب التاب الحالي
                                    List<ProductModel> currentTabProducts = _getCurrentTabProducts();
                                    
                                    final filtered = currentTabProducts.where((product) {
                                      final productName = product.name.toLowerCase();
                                      return productName
                                          .startsWith(value.toLowerCase());
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
                                hintStyle:
                                    Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                        ),
                                prefixIcon: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.search,
                                    color: _focusNode.hasFocus 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    size: 25,
                                  ),
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear, 
                                          size: 20,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _ghostText = '';
                                            _fullSuggestion = '';
                                          });
                                          HapticFeedback.lightImpact();
                                        },
                                        tooltip: 'home.search.clear'.tr(),
                                      )
                                    : null,
                                // تحسين الحدود والشكل
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).colorScheme.surface.withOpacity(0.8)
                                    : Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          ),
                          // النص الشبحي المحسن مع تأثيرات بصرية
                          if (_ghostText.isNotEmpty && _focusNode.hasFocus)
                            Positioned(
                              top: 17,
                              right: 55,
                              child: AnimatedOpacity(
                                opacity: _searchQuery.isNotEmpty ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: GestureDetector(
                                  onTap: () {
                                    if (_fullSuggestion.isNotEmpty) {
                                      _searchController.text = _fullSuggestion;
                                      setState(() {
                                        _searchQuery = _fullSuggestion;
                                        _ghostText = '';
                                        _fullSuggestion = '';
                                      });
                                      HapticFeedback.selectionClick();
                                      // إبقاء التركيز لتمكين المستخدم من المتابعة في الكتابة
                                      _focusNode.requestFocus();
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withOpacity(0.15)
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 14,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _ghostText,
                                            style: TextStyle(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.secondary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
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
        final filteredProducts = searchQuery.isEmpty
            ? products
            : products.where((product) {
                final query = searchQuery.toLowerCase();
                return product.name.toLowerCase().contains(query) ||
                    (product.activePrinciple ?? '')
                        .toLowerCase()
                        .contains(query) ||
                    (product.company ?? '').toLowerCase().contains(query);
              }).toList();

        if (filteredProducts.isEmpty) {
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
          onRefresh: () => ref.refresh(priceUpdatesProvider.future),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.6,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return ViewTrackingProductCard(
                product: product,
                searchQuery: searchQuery,
                productType: 'price_action',
                showPriceChange: true,
                trackViewOnVisible: true,
                onTap: () {
                  // This is a bit of a workaround to access the dialog function
                  // A better approach would be to extract the dialog to its own widget/function
                  // that can be called from anywhere.
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
