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

class _AddFromCatalogScreenState extends ConsumerState<AddFromCatalogScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  late List<Map<String, dynamic>> _shuffledDisplayItems;
  String? _lastShuffledQuery; // علشان نعرف نعيد الشفل لو البحث اتغير

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _shuffledDisplayItems = [];
    _lastShuffledQuery = null; // مش اتعمل شفل لحد دلوقتي
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _buildShuffledDisplayItems(
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
        _shuffledDisplayItems = items;
        _lastShuffledQuery =
            currentSearchQuery; // نخزن نص البحث اللي اتشالّك وقت الشفل
      });
    }
    // لو `_lastShuffledQuery == currentSearchQuery`، يفضل نستخدم نفس `_shuffledDisplayItems`
  }

      @override
  Widget build(BuildContext context) {
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
                  kToolbarHeight + 50.0), // زيادة الارتفاع لاستيعاب العداد
              child: Column(
                children: [
                  // === شريط البحث ===
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
                  // === عداد المنتجات الأنيق ===
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
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
                                    product.activePrinciple?.toLowerCase() ?? '';

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
                                        Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            );
                          },
                          loading: () => Text(
                            'جارٍ العد...',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          error: (_, __) => Text(
                            'خطأ في العد',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
                    for (var item in _shuffledDisplayItems) {
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
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.light
                          ? const Color.fromARGB(255, 44, 214,
                              223) // لون أزرق أكتر صفاءً للوضع النهاري (kBlue)
                          : Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(255, 31, 115, 151)
                              : Theme.of(context).colorScheme.primary,
                  icon: const Icon(Icons.check),
                  // استخدام أنماط FAB الافتراضية
                )
              : null,
          body: allProductsAsync.when(
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
                  final productCompany = product.company?.toLowerCase() ?? '';
                  final productActivePrinciple =
                      product.activePrinciple?.toLowerCase() ?? '';

                  // بنشوف لو النص موجود في أي واحد من الثلاثة
                  return productName.contains(query) ||
                      productCompany.contains(query) ||
                      productActivePrinciple.contains(query);
                }).toList();
              }

              // === بني القائمة العشوائية إذا لسه ما اتعملتش أو البحث اتغير ===
              _buildShuffledDisplayItems(filteredProducts, _searchQuery);

              if (_shuffledDisplayItems.isEmpty) {
                // عرض رسالة مناسبة لو مفيش منتجات بعد الفلترة والشفل
                if (_searchQuery.isNotEmpty) {
                  // لو في بحث ونتائج فاضية
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد نتائج للبحث.',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد منتجات في الكتالوج الرئيسي.',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  );
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount:
                    _shuffledDisplayItems.length, // استخدم القائمة العشوائية
                itemBuilder: (context, index) {
                  final item = _shuffledDisplayItems[
                      index]; // استخدم العنصر من القائمة العشوائية
                  final ProductModel product = item['product'];
                  final String package = item['package'];
                  return _ProductCatalogItem(product: product, package: package);
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
    // final currentPrice = selection.prices[uniqueKey] ?? 0.0; // <= مش محتاجه كمان

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
        // debounceTimer.value?.cancel(); // <= شيلته كمان
      };
    }, const []);

    // === استخدام Card من Material ===
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null, // استخدام لون البطاقة الافتراضي إن مش محدد
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 50,
                  height: 50,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.contain, // علشان الصورة تبان كلها
                    placeholder: (context, url) =>
                        const Center(child: ImageLoadingIndicator(size: 30)),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error_outline, size: 30),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === تحسين اسم المنتج ===
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
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
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          package,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: priceController,
                      focusNode: focusNode,
                      enabled: true,
                      onChanged: (value) {
                        final controller = ref
                            .read(catalogSelectionControllerProvider.notifier);

                        if (value.trim().isEmpty) {
                          // لو الحقل اتفضى → اشيل السعر من الاختيارات
                          controller.removePrice(product.id, package);
                        } else {
                          // لو في قيمة → ابعتها
                          controller.setPrice(product.id, package, value);
                        }
                      },
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'price'.tr(),
                        prefixText: ' EGP ',
                        prefixStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.7)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.5),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        hintText: isSelected ? null : '  حدد المنتج ',
                        hintStyle: TextStyle(
                          color: Theme.of(context).disabledColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // === تحسين الزر ===
            // الـ Switch هياخد لونه من الـ Theme اللي حددناه فوق، فمش محتاجين نحدد ألوانه يدويًا
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
    );
  }
}
