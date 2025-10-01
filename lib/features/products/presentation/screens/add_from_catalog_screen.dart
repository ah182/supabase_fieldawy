import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/application/catalog_selection_controller.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/widgets/custom_product_dialog.dart';
import 'package:fieldawy_store/widgets/unified_search_bar.dart';
import 'dart:ui' as ui;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class AddFromCatalogScreen extends ConsumerStatefulWidget {
  const AddFromCatalogScreen({super.key});

  @override
  ConsumerState<AddFromCatalogScreen> createState() =>
      _AddFromCatalogScreenState();

  /// دالة علشان تفتح Dialog فيه تفاصيل المنتج كاملة
  /// معرفة كـ static علشان نقدر نستخدمها من الـ Item
  static void _showProductDetailDialog(
      BuildContext context, ProductModel product,
      [String? package]) {
    // إنشاء نسخة مؤقتة من المنتج مع العبوة المحددة
    final productWithPackage = ProductModel(
      id: product.id,
      name: product.name,
      description: product.description,
      activePrinciple: product.activePrinciple,
      company: product.company,
      action: product.action,
      package: package ?? product.selectedPackage,
      availablePackages: product.availablePackages,
      imageUrl: product.imageUrl,
      price: product.price,
      distributorId: product.distributorId,
      createdAt: product.createdAt,
      selectedPackage: package ?? product.selectedPackage,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: CustomProductDialog(product: productWithPackage),
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
}

class _AddFromCatalogScreenState extends ConsumerState<AddFromCatalogScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late TextEditingController _searchController;
  String _searchQuery = '';
  List<Map<String, dynamic>> _mainCatalogShuffledDisplayItems = [];
  List<Map<String, dynamic>> _ocrCatalogShuffledDisplayItems = [];
  String? _lastShuffledQuery; // علشان نعرف نعيد الشفل لو البحث اتغير
  String? _lastOcrShuffledQuery; // For OCR catalog search

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _lastShuffledQuery = null; // مش اتعمل شفل لحد دلوقتي
    _lastOcrShuffledQuery = null; // OCR catalog
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

    void _buildMainCatalogShuffledDisplayItems(
      List<ProductModel> filteredProducts, String currentSearchQuery) {
    // لو البحث اتغير أو مش اتعمل شفل لحد دلوقتي، نعمل شفل
    if (_lastShuffledQuery != currentSearchQuery) {
      final List<Map<String, dynamic>> items = [];
      for (var product in filteredProducts) {
        for (var package in product.availablePackages) {
          items.add({'product': product, 'package': package});
        }
      }
      items.shuffle(); // شفل بس مرة وحدة للقائمة الحالية
      setState(() {
        _mainCatalogShuffledDisplayItems = items;
        _lastShuffledQuery = currentSearchQuery; // نخزن نص البحث اللي اتشالّك وقت الشفل
      });
    }
    // لو `_lastShuffledQuery == currentSearchQuery`، يفضل نستخدم نفس `_shuffledDisplayItems`
  }

  void _buildOcrCatalogShuffledDisplayItems(
      List<ProductModel> filteredProducts, String currentSearchQuery) {
    // لو البحث اتغير أو مش اتعمل شفل لحد دلوقتي، نعمل شفل
    if (_lastOcrShuffledQuery != currentSearchQuery) {
      final List<Map<String, dynamic>> items = [];
      for (var product in filteredProducts) {
        for (var package in product.availablePackages) {
          items.add({'product': product, 'package': package});
        }
      }
      items.shuffle(); // شفل بس مرة وحدة للقائمة الحالية
      setState(() {
        _ocrCatalogShuffledDisplayItems = items;
        _lastOcrShuffledQuery = currentSearchQuery; // نخزن نص البحث اللي اتشالّك وقت الشفل
      });
    }
    // لو `_lastOcrShuffledQuery == currentSearchQuery`، يفضل نستخدم نفس `_ocrCatalogShuffledDisplayItems`
  }

  @override
  Widget build(BuildContext context) {
    _tabController ??= TabController(length: 2, vsync: this);
    final allProductsAsync = ref.watch(productsProvider);
    final selection = ref.watch(catalogSelectionControllerProvider);

    // فلترة المنتجات الجاهزة للحفظ (التي لها سعر أكبر من صفر)
    final validSelections = Map.from(selection.prices)
      ..removeWhere((key, price) => price <= 0);

    // === تحديد الألوان المطلوبة للعناصر المخصصة ===
    final Color customElementColor = const Color.fromARGB(255, 119, 186, 225);

    return Theme(
      // نعمل نسخة من الثيم الأساسي ونعدل عليه بس لو الوضع داكن
      data: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).copyWith(
              // === تغيير ألوان الـ Switch بس في الوضع الداكن ===
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return customElementColor; // لون الزرّاعة لما يكون مفعل
                  }
                  return null; // يسيب اللون الافتراضي
                }),
                trackColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return customElementColor
                        .withOpacity(0.5); // لون الخلفية لما يكون مفعل
                  }
                  return null; // يسيب اللون الافتراضي
                }),
              ),
            )
          : Theme.of(context), // لو مش داكن، نسيب الثيم زي ما هو
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          // === تعديل AppBar علشان يحتوي على SearchBar وعداد المنتجات ===
          appBar: AppBar(
            title: const Text('إضافة من الكتالوج'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            // إضافة SearchBar وعداد المنتجات في الـ AppBar
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(
                  kToolbarHeight + 40.0 + kTextTabBarHeight), // زيادة الارتفاع لاستيعاب العداد
              child: Column(
                children: [
                  // === شريط البحث المحسن ===
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: UnifiedSearchBar(
                      controller: _searchController,
                      onChanged: (value) {
                        // تحديث نص البحث في الـ state
                        setState(() {
                          _searchQuery = value;
                        });
                        // مش محتاجين نعمل حاجة تانية هنا، الـ build هتشتغل تاني وتشوف التغيير
                      },
                      onClear: () {
                        // مسح النص وتحديث الـ state
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      hintText: 'ابحث عن منتج...',
                    ),
                  ),
                  // === عداد المنتجات المحسن ===
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        allProductsAsync.when(
                          data: (products) {
                            // فلترة المنتجات حسب نص البحث
                            List<ProductModel> filteredProducts;
                            if (_searchQuery.isEmpty) {
                              filteredProducts = products;
                            } else {
                              filteredProducts = products.where((product) {
                                final query = _searchQuery.toLowerCase();
                                final productName = product.name.toLowerCase();
                                final productCompany =
                                    product.company?.toLowerCase() ?? '';
                                final productActivePrinciple =
                                    product.activePrinciple?.toLowerCase() ??
                                        '';

                                return productName.contains(query) ||
                                    productCompany.contains(query) ||
                                    productActivePrinciple.contains(query);
                              }).toList();
                            }

                            // حساب إجمالي العناصر (المنتجات × العبوات)
                            int totalItems = 0;
                            int filteredItems = 0;

                            for (var product in products) {
                              totalItems += product.availablePackages.length;
                            }

                            for (var product in filteredProducts) {
                              filteredItems += product.availablePackages.length;
                            }

                            return Text(
                              _searchQuery.isEmpty
                                  ? 'إجمالي العناصر: $totalItems'
                                  : 'عرض $filteredItems من $totalItems عنصر',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            );
                          },
                          loading: () => Text(
                            'جارٍ العد...',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          error: (_, __) => Text(
                            'خطأ في العد',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Main Cataloge'),
                      Tab(text: 'OCR Cataloge'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: validSelections.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    // === التحقق من إن كل المنتجات المختارة دلوقتي ليها سعر صحيح ومدخل فعلاً ===
                    // علشان نعرف ندور على اسم الصنف

                    // 1. نجيب قائمة بكل الـ Keys اللي المستخدم حددها دلوقتي
                    final List<String> currentlySelectedKeys = [];
                    // التكرار على القائمة المعروضة علشان ندور على العناصر اللي مختارينها دلوقتي
                    // We need to use the active tab's items - check which tab is currently active
                    final List<Map<String, dynamic>> currentDisplayItems = 
                        _tabController?.index == 0 ? _mainCatalogShuffledDisplayItems : _ocrCatalogShuffledDisplayItems;
                    
                    for (var item in currentDisplayItems) {
                      final ProductModel product = item['product'];
                      final String package = item['package'];
                      final String key = '${product.id}_$package';
                      // التحقق من إن الـ Switch بتاع العنصر ده مفعل دلوقتي في الـ UI
                      // ده هيعمله Riverpod لما يعيد الـ build
                      final isSelectedNow = ref
                          .read(catalogSelectionControllerProvider)
                          .prices
                          .containsKey(key);
                      if (isSelectedNow) {
                        currentlySelectedKeys.add(key);
                      }
                    }

                    {
                      // === لو كل الأسعار صحيحة، نبدأ عملية الحفظ ===
                      final success = await ref
                          .read(catalogSelectionControllerProvider.notifier)
                          .saveSelections();

                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            elevation: 0,
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.transparent,
                            content: AwesomeSnackbarContent(
                              title: 'نجاح',
                              message: 'تم حفظ المنتجات بنجاح',
                              contentType: ContentType.success,
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            elevation: 0,
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.transparent,
                            content: AwesomeSnackbarContent(
                              title: 'تنبيه',
                              message: 'حدث خطأ أثناء حفظ المنتجات',
                              contentType: ContentType.warning,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  label: Text(
                    'add_items'.tr(
                      namedArgs: {'count': validSelections.length.toString()},
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.check_rounded),
                  elevation: 2,
                )
              : null,
          body: TabBarView(
            controller: _tabController,
            children: [
              allProductsAsync.when(
                data: (products) {
                  // === فلترة المنتجات حسب نص البحث (في الاسم، الشركة، والمادة الفعالة) ===
                  List<ProductModel> filteredProducts;
                  if (_searchQuery.isEmpty) {
                    filteredProducts = products;
                  } else {
                    filteredProducts = products.where((product) {
                      // تحويل النص للحروف صغيرة علشان المقارنة تكون case-insensitive
                      final query = _searchQuery.toLowerCase();
                      final productName = product.name.toLowerCase();
                      // تأكد إن الخواص دي موجودة في ProductModel
                      final productCompany =
                          product.company?.toLowerCase() ?? '';
                      final productActivePrinciple =
                          product.activePrinciple?.toLowerCase() ?? '';

                      // بنشوف لو النص موجود في أي واحد من الثلاثة
                      return productName.contains(query) ||
                          productCompany.contains(query) ||
                          productActivePrinciple.contains(query);
                    }).toList();
                  }

                  // === بني القائمة العشوائية إذا لسه ما اتعملتش أو البحث اتغير ===
                  _buildMainCatalogShuffledDisplayItems(filteredProducts, _searchQuery);

                  if (_mainCatalogShuffledDisplayItems.isEmpty) {
                    // عرض رسالة مناسبة لو مفيش منتجات بعد الفلترة والشفل
                    if (_searchQuery.isNotEmpty) {
                      // لو في بحث ونتائج فاضية
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد نتائج للبحث.',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // لو مفيش منتجات أصلاً
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد منتجات في الكتالوج الرئيسي.',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                            ),
                          ],
                        ),
                      );
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90, top: 8),
                    itemCount:
                        _mainCatalogShuffledDisplayItems.length, // استخدم القائمة العشوائية
                    itemBuilder: (context, index) {
                      final item = _mainCatalogShuffledDisplayItems[
                          index]; // استخدم العنصر من القائمة العشوائية
                      final ProductModel product = item['product'];
                      final String package = item['package'];
                      return _ProductCatalogItem(
                          product: product, package: package);
                    },
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 6,
                  padding: const EdgeInsets.all(16.0),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ProductCardShimmer(),
                    );
                  },
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'حدث خطأ: $error',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              // Tab for OCR Catalog - fetch and display OCR products
              ref.watch(ocrProductsProvider).when(
                data: (ocrProducts) {
                  // Filter OCR products based on search query
                  List<ProductModel> filteredOcrProducts;
                  if (_searchQuery.isEmpty) {
                    filteredOcrProducts = ocrProducts;
                  } else {
                    filteredOcrProducts = ocrProducts.where((product) {
                      final query = _searchQuery.toLowerCase();
                      final productName = product.name.toLowerCase();
                      final productCompany = product.company?.toLowerCase() ?? '';
                      final productActivePrinciple = product.activePrinciple?.toLowerCase() ?? '';

                      return productName.contains(query) ||
                          productCompany.contains(query) ||
                          productActivePrinciple.contains(query);
                    }).toList();
                  }

                  // Build shuffled display items for OCR products
                  _buildOcrCatalogShuffledDisplayItems(filteredOcrProducts, _searchQuery);

                  if (_ocrCatalogShuffledDisplayItems.isEmpty) {
                    // Show appropriate message if no OCR products
                    if (_searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد نتائج للبحث في OCR.',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد منتجات في OCR الكتالوج.',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                            ),
                          ],
                        ),
                      );
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90, top: 8),
                    itemCount: _ocrCatalogShuffledDisplayItems.length,
                    itemBuilder: (context, index) {
                      final item = _ocrCatalogShuffledDisplayItems[index];
                      final ProductModel product = item['product'];
                      final String package = item['package'];
                      return _ProductCatalogItem(
                          product: product, package: package);
                    },
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 6,
                  padding: const EdgeInsets.all(16.0),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ProductCardShimmer(),
                    );
                  },
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'حدث خطأ في تحميل OCR: $error',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCatalogItem extends HookConsumerWidget {
  final ProductModel product;
  final String package;

  const _ProductCatalogItem({required this.product, required this.package});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(catalogSelectionControllerProvider);
    final uniqueKey = '${product.id}_$package';
    final isSelected = selection.prices.containsKey(uniqueKey);

    final priceController = useTextEditingController();
    final focusNode = useMemoized(() => FocusNode(), const []);

    // === تحديث الـ Controller لما يتغير isSelected بس ===
    useEffect(() {
      // بس نسيب المسح لما يتشال التحديد
      if (!isSelected) {
        priceController.clear();
      }
      return null;
    }, [isSelected]); // يشتغل بس لما يتغير isSelected

    // === تحرير الـ FocusNode لما الكومبوننت يتشال ===
    useEffect(() {
      return () {
        focusNode.dispose();
      };
    }, const []);

    // === استخدام Container بدلاً من Card مع التصميم المحسن ===
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === تحسين الصورة مع إمكانية المعاينة ===
              GestureDetector(
                onTap: () {
                  // استدعاء الدالة كـ static من الـ StatefulWidget
                  AddFromCatalogScreen._showProductDetailDialog(
                      context, product, package);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: ImageLoadingIndicator(size: 24),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          size: 28,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === تحسين اسم المنتج بحجم أصغر ===
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // === تحسين الباكدج ===
                    if (package.isNotEmpty)
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            package,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // === حقل السعر المحسن ===
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: priceController,
                        focusNode: focusNode,
                        enabled: true,
                        onChanged: (value) {
                          final controller = ref.read(
                              catalogSelectionControllerProvider.notifier);

                          if (value.trim().isEmpty) {
                            // لو الحقل اتفضى → اشيل السعر من الاختيارات
                            controller.removePrice(product.id, package);
                          } else {
                            // لو في قيمة → ابعتها
                            controller.setPrice(product.id, package, value);
                          }
                        },
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'price'.tr(),
                          prefixText: 'EGP ',
                          prefixStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.5)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.3),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          hintText: isSelected ? null : 'حدد المنتج',
                          hintStyle: TextStyle(
                            color: Theme.of(context).disabledColor,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // === تحسين الـ Switch ===
              Switch.adaptive(
                value: isSelected,
                onChanged: (value) {
                  ref
                      .read(catalogSelectionControllerProvider.notifier)
                      .toggleProduct(product.id, package, priceController.text);

                  // لو المنتج بقى محدد، نركز على حقل السعر
                  if (value) {
                    // استخدام Future.microtask علشان نتأكد إن الحقل اتشالّك قبل ما نركز عليه
                    Future.microtask(() {
                      focusNode.requestFocus();
                    });
                  } else {
                    // لو اتشال التحديد، نمسح النص ونخلّي الحقل يفقد التركيز
                    priceController.clear();
                    focusNode.unfocus();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
