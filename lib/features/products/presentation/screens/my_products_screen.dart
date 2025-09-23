import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:flutter/material.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
// ignore: unnecessary_import
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <= مهم علشان HookConsumerWidget
import 'dart:ui' as ui; // <= لتفادي أي تعارض مع TextDirection
import 'dart:async'; // <= مهم علشان Completer
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';

import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/widgets/custom_product_dialog.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/widgets/unified_search_bar.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

// Helper function to show the animated banner
void _showAnimatedBanner(BuildContext context) {
  OverlayEntry? overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => _AnimatedTopBanner(
      message: 'اضغط مطولاً على المنتج لاختيار عدة منتجات',
      onDismiss: () {
        overlayEntry?.remove();
      },
    ),
  );
  Overlay.of(context).insert(overlayEntry);
}

// The animated banner widget
class _AnimatedTopBanner extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedTopBanner({required this.message, required this.onDismiss});

  @override
  _AnimatedTopBannerState createState() => _AnimatedTopBannerState();
}

class _AnimatedTopBannerState extends State<_AnimatedTopBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // Schedule dismissal
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).viewPadding.top;

    // Define theme-aware styles
    final BoxDecoration decoration;
    final Color iconAndTextColor;
    final ButtonStyle buttonStyle;

    if (isDarkMode) {
      decoration = BoxDecoration(
        color:  const Color.fromARGB(255, 33, 33, 34), // Elevated surface color
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 18, 18, 18).withOpacity(0.6),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      );  
      iconAndTextColor = theme.colorScheme.onSurface;
      buttonStyle = TextButton.styleFrom(
        foregroundColor: iconAndTextColor,
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );
    } else {
      decoration = BoxDecoration(
        color: theme.colorScheme.secondary, // Use solid color
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      );
      iconAndTextColor = theme.colorScheme.onPrimary;
      buttonStyle = TextButton.styleFrom(
        foregroundColor: iconAndTextColor,
        backgroundColor: Colors.white.withOpacity(0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );
    }

    return Positioned(
      top: topPadding + 4,
      left: 8,
      right: 8,
      child: SlideTransition(
        position: _animation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: decoration, // Apply the theme-aware decoration
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined, color: iconAndTextColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: iconAndTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      if (mounted) {
                        _controller.reverse().then((_) {
                          widget.onDismiss();
                        });
                      }
                    },
                    style: buttonStyle,
                    child: Text(
                      'حسناً',
                      style: TextStyle(
                        color: iconAndTextColor,
                        fontWeight: FontWeight.bold,
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
}


class MyProductsScreen extends HookConsumerWidget {
  // <= غيرنا لـ HookConsumerWidget
  const MyProductsScreen({super.key});

  /// دالة لإظهار ديالوج تفاصيل المنتج مع تصميم احترافي
  static void _showProductDetailDialog(
      BuildContext context, ProductModel product) {
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
            child: CustomProductDialog(product: product),
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

  /// دالة تأكيد الحذف
  static Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, String productName) {
    final completer = Completer<bool?>();

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      title: 'تأكيد الحذف',
      desc: 'هل أنت متأكد من حذف المنتج \"$productName\"؟',
      btnCancelText: 'إلغاء',
      btnOkText: 'حذف',
      btnCancelIcon: Icons.cancel_outlined,
      btnOkIcon: Icons.delete,
      btnCancelColor: Colors.grey,
      btnOkColor: Colors.red,
      btnCancelOnPress: () {
        completer.complete(false);
      },
      btnOkOnPress: () {
        completer.complete(true);
      },
    ).show();

    return completer.future;
  }

  /// دالة تعديل السعر
  static Future<double?> _showEditPriceDialog(
      BuildContext context, ProductModel product) {
    final TextEditingController priceController = TextEditingController(
      text: product.price?.toString() ?? '',
    );
    final completer = Completer<double?>();

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      title: 'تعديل سعر المنتج',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // إضافة اسم المنتج وحجم العبوة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.selectedPackage != null &&
                    product.selectedPackage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      ' ${product.selectedPackage}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: priceController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'السعر الجديد',
              suffixText: 'جنيه',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      btnCancelText: 'إلغاء',
      btnOkText: 'تحديث',
      btnCancelIcon: Icons.cancel_outlined,
      btnOkIcon: Icons.check,
      btnCancelColor: Colors.grey,
      btnOkColor: Theme.of(context).colorScheme.primary,
      btnCancelOnPress: () {
        completer.complete(null);
      },
      btnOkOnPress: () {
        final newPrice = double.tryParse(priceController.text);
        if (newPrice != null && newPrice > 0) {
          completer.complete(newPrice);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              content: AwesomeSnackbarContent(
                title: 'تنبيه',
                message: 'الرجاء إدخال سعر صحيح',
                contentType: ContentType.warning,
              ),
            ),
          );
        }
      },
    ).show();

    return completer.future;
  }

  void _showAddProductOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.collections_bookmark),
                title: const Text('Add from Catalog'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const AddFromCatalogScreen()),
                  );
                  ref.invalidate(myProductsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Scan with Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const AddProductOcrScreen()),
                  );
                  ref.invalidate(myProductsProvider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // === استدعاء الـ Provider اللي بيجيب قائمة "أدويةي" ===
    // Using the cached provider for better performance
    final myProductsAsync = ref.watch(myProductsProvider);
    final userRole = ref.watch(userDataProvider).asData?.value?.role ?? '';
    final searchFocusNode = useFocusNode();
    final isSelectionMode = useState(false);
    final selectedProducts = useState<Set<String>>({});

    // State to track if hint has been shown
    final hasShownHint = useState(false);

    // Show hint snackbar only once when products are loaded
    useEffect(() {
      if (!hasShownHint.value &&
          !isSelectionMode.value &&
          myProductsAsync is AsyncData<List<ProductModel>> &&
          myProductsAsync.value.isNotEmpty) {
        // Show hint after a small delay to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            _showAnimatedBanner(context);
            hasShownHint.value = true;
          }
        });
      }
      return null;
    }, [myProductsAsync, isSelectionMode.value]);

    if (userRole != 'distributor' && userRole != 'company') {
      return Scaffold(
        appBar: AppBar(
          title: Text('myMedicines'.tr()),
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        body: Center(
          child: Text('This page is only for distributors.'.tr()),
        ),
      );
    }

    // === متغير علشان نسيط نص البحث ===
    final searchQuery = useState<String>(''); // <= متغير البحث

    // Preload data for smoother transitions
    ref.listen(myProductsProvider, (previous, next) {
      // This will trigger data loading when the screen is first built
    });

    return GestureDetector(
      onTap: () {
        searchFocusNode.unfocus();
      },
      child: MainScaffold(
        selectedIndex: 0,
        floatingActionButton: isSelectionMode.value
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: "btnDeleteAll",
                      onPressed: () async {
                        // Delete all selected products
                        if (selectedProducts.value.isNotEmpty) {
                          final confirmDelete = await _showDeleteConfirmationDialog(
                              context,
                              '${selectedProducts.value.length} selected products');
                          if (confirmDelete == true) {
                            try {
                              final userId =
                                  ref.read(authServiceProvider).currentUser?.id;
                              if (userId != null) {
                                await ref
                                    .read(productRepositoryProvider)
                                    .removeMultipleProductsFromDistributorCatalog(
                                      distributorId: userId,
                                      productIdsWithPackage:
                                          selectedProducts.value.toList(),
                                    );

                                ref
                                    .read(cachingServiceProvider)
                                    .invalidateWithPrefix('my_products_');
                                ref.invalidate(myProductsProvider);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    content: AwesomeSnackbarContent(
                                      title: 'Success',
                                      message:
                                          'Selected products deleted successfully',
                                      contentType: ContentType.success,
                                    ),
                                  ),
                                );
                                isSelectionMode.value = false;
                                selectedProducts.value = {};
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  elevation: 0,
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.transparent,
                                  content: AwesomeSnackbarContent(
                                    title: 'Error',
                                    message:
                                        'Failed to delete products. Please try again.',
                                    contentType: ContentType.failure,
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Icon(Icons.delete),
                      backgroundColor: Colors.red,
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: "btnSelectAll",
                      onPressed: () async {
                        final myProductsAsync = ref.read(myProductsProvider);
                        if (myProductsAsync is AsyncData<List<ProductModel>>) {
                          final allProductIds = myProductsAsync.value
                              .map((product) =>
                                  '${product.id}_${product.selectedPackage ?? ''}')
                              .toSet();

                          // Check if all products are already selected
                          if (selectedProducts.value.length ==
                                  allProductIds.length &&
                              selectedProducts.value
                                  .containsAll(allProductIds)) {
                            // Deselect all
                            selectedProducts.value = {};
                          } else {
                            // Select all
                            selectedProducts.value = allProductIds;
                          }
                        }
                      },
                      child: selectedProducts.value.length > 0 &&
                              selectedProducts.value.length ==
                                  (ref.read(myProductsProvider)
                                          is AsyncData<List<ProductModel>>?
                                      (ref.read(myProductsProvider)
                                              as AsyncData<List<ProductModel>>)
                                          .value
                                          .length
                                      : 0)
                          ? const Icon(Icons.deselect)
                          : const Icon(Icons.select_all),
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.light
                              ? const Color.fromARGB(255, 44, 214, 223)
                              : Theme.of(context).brightness == Brightness.dark
                                  ? const Color.fromARGB(255, 31, 115, 151)
                                  : Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              )
            : FloatingActionButton.extended(
                onPressed: () {
                  _showAddProductOptions(context, ref);
                },
                label: Text('addProduct'.tr()),
                icon: const Icon(Icons.add),
                elevation: 4,
                backgroundColor:
                    Theme.of(context).brightness == Brightness.light
                        ? const Color.fromARGB(255, 44, 214,
                            223) // لون أزرق أكتر صفاءً للوضع النهاري (kBlue)
                        : Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(255, 31, 115, 151)
                            : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
        // === تعديل AppBar علشان يحتوي على SearchBar وعداد المنتجات ===
        appBar: AppBar(
          title: isSelectionMode.value
              ? Text('${selectedProducts.value.length} selected')
              : Text('myMedicines'.tr()),
          leading: isSelectionMode.value
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    isSelectionMode.value = false;
                    selectedProducts.value = {};
                  },
                )
              : null,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          // إضافة SearchBar وعداد المنتجات في الـ AppBar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(
                kToolbarHeight + 50.0), // زيادة الارتفاع لاستيعاب العداد
            child: Column(
              children: [
                // === شريط البحث ===
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: UnifiedSearchBar(
                    focusNode: searchFocusNode,
                    onChanged: (value) {
                      // تحديث نص البحث في الـ state
                      searchQuery.value = value;
                    },
                    onClear: () {
                      // مسح النص وتحديث الـ state
                      searchQuery.value = '';
                    },
                    hintText: 'ابحث عن منتج...', // <= نص تلميحي
                  ),
                ),
                // === عداد المنتجات الأنيق ===
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          myProductsAsync.when(
                            data: (products) {
                              if (isSelectionMode.value) {
                                // Show selected count in selection mode
                                return Text(
                                  '${selectedProducts.value.length} of ${products.length} selected',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                );
                              } else {
                                // Show total count in normal mode
                                final totalCount = products.length;
                                final filteredCount = searchQuery.value.isEmpty
                                    ? totalCount
                                    : products.where((product) {
                                        final query =
                                            searchQuery.value.toLowerCase();
                                        final productName =
                                            product.name.toLowerCase();
                                        final productCompany =
                                            product.company?.toLowerCase() ??
                                                '';
                                        final productActivePrinciple = product
                                                .activePrinciple
                                                ?.toLowerCase() ??
                                            '';
                                        return productName.contains(query) ||
                                            productCompany.contains(query) ||
                                            productActivePrinciple
                                                .contains(query);
                                      }).length;

                                return Text(
                                  searchQuery.value.isEmpty
                                      ? 'إجمالي المنتجات: $totalCount'
                                      : 'عرض $filteredCount من $totalCount منتج',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                );
                              }
                            },
                            loading: () => Text(
                              'جارٍ العد...', 
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                      // Show hint only in normal mode when there are products
                     
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myProductsProvider);
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: myProductsAsync.when(
            data: (products) {
              // === فلترة المنتجات حسب نص البحث (في الاسم، الشركة، والمادة الفعالة) ===
              List<ProductModel> filteredProducts;
              if (searchQuery.value.isEmpty) {
                filteredProducts = products;
              } else {
                filteredProducts = products.where((product) {
                  // تحويل النص للحروف صغيرة علشان المقارنة تكون case-insensitive
                  final query = searchQuery.value.toLowerCase();
                  final productName = product.name.toLowerCase();
                  // تأكد إن الخواص دي موجودة في ProductModel
                  // افتراضيًا إن عندك company و activePrinciple
                  final productCompany = product.company?.toLowerCase() ?? '';
                  final productActivePrinciple =
                      product.activePrinciple?.toLowerCase() ?? '';

                  // بنشوف لو النص موجود في أي واحد من الثلاثة
                  return productName.contains(query) ||
                      productCompany.contains(query) ||
                      productActivePrinciple.contains(query);
                }).toList();
              }

              if (filteredProducts.isEmpty) {
                // === عرض رسالة مناسبة لو مفيش نتائج للبحث ===
                if (searchQuery.value.isNotEmpty) {
                  return LayoutBuilder(builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_outlined, // <= أيقونة مناسبة
                                size: 60,
                                color: Theme.of(context).colorScheme.primary,
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
                        ),
                      ),
                    );
                  });
                } else {
                  // === لو مفيش منتجات أصلاً ===
                  return LayoutBuilder(builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 60,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'You have not added any medicines yet.'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const AddFromCatalogScreen()),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: Text('addProduct'.tr()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                }
              }

              // === عرض قائمة المنتجات المفلترة ===
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80.0),
                itemCount: filteredProducts.length, // <= عدد العناصر المفلترة
                itemBuilder: (context, index) {
                  final product =
                      filteredProducts[index]; // <= استخدام المنتج المفلتر
                  final isSelected = selectedProducts.value.contains(
                      '${product.id}_${product.selectedPackage ?? ''}');
                      
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : BorderSide.none,
                    ),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GestureDetector(
                          onTap: () {
                            _showProductDetailDialog(context, product);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.surfaceVariant,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: ImageLoadingIndicator(size: 30),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.error_outline,
                                    size: 30,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (product.selectedPackage != null &&
                                product.selectedPackage!.isNotEmpty)
                              Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    product.selectedPackage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                        ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${product.price?.toStringAsFixed(2) ?? '0.00'} ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  TextSpan(
                                    text: 'EGP'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: isSelectionMode.value
                            ? () {
                                // Toggle selection
                                final productIdWithPackage =
                                    '${product.id}_${product.selectedPackage ?? ''}';
                                if (selectedProducts.value
                                    .contains(productIdWithPackage)) {
                                  selectedProducts.value = Set.from(
                                      selectedProducts.value
                                        ..remove(productIdWithPackage));
                                } else {
                                  selectedProducts.value = Set.from(
                                      selectedProducts.value
                                        ..add(productIdWithPackage));
                                }
                                // Exit selection mode if no items are selected
                                if (selectedProducts.value.isEmpty) {
                                  isSelectionMode.value = false;
                                }
                              }
                            : null,
                        onLongPress: isSelectionMode.value
                            ? null
                            : () {
                                // Enter selection mode and select this item
                                isSelectionMode.value = true;
                                selectedProducts.value = {
                                  '${product.id}_${product.selectedPackage ?? ''}'
                                };
                              },
                        trailing: isSelectionMode.value
                            ? Checkbox(
                                value: selectedProducts.value.contains(
                                        '${product.id}_${product.selectedPackage ?? ''}')
                                    ? true
                                    : false,
                                onChanged: (bool? value) {
                                  final productIdWithPackage =
                                      '${product.id}_${product.selectedPackage ?? ''}';
                                  if (value == true) {
                                    selectedProducts.value = Set.from(
                                        selectedProducts.value
                                          ..add(productIdWithPackage));
                                  } else {
                                    selectedProducts.value = Set.from(
                                        selectedProducts.value
                                          ..remove(productIdWithPackage));
                                    // Exit selection mode if no items are selected
                                    if (selectedProducts.value.isEmpty) {
                                      isSelectionMode.value = false;
                                    }
                                  }
                                },
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Colors.blue),
                                    onPressed: () async {
                                      final newPrice =
                                          await _showEditPriceDialog(
                                              context, product);
                                      if (newPrice != null) {
                                        try {
                                          final userId = ref
                                              .read(authServiceProvider)
                                              .currentUser
                                              ?.id;
                                          if (userId != null) {
                                            await ref
                                                .read(productRepositoryProvider)
                                                .updateProductPriceInDistributorCatalog(
                                                  distributorId: userId,
                                                  productId: product.id,
                                                  package:
                                                      product.selectedPackage ??
                                                          '',
                                                  newPrice: newPrice,
                                                );

                                            // The repository now handles cache invalidation,
                                            // and the provider re-fetches automatically
                                            // because it watches productDataLastModifiedProvider.

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                elevation: 0,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                backgroundColor:
                                                    Colors.transparent,
                                                content: AwesomeSnackbarContent(
                                                  title: 'Success',
                                                  message:
                                                      'Price updated successfully',
                                                  contentType:
                                                      ContentType.success,
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              elevation: 0,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor:
                                                  Colors.transparent,
                                              content: AwesomeSnackbarContent(
                                                title: 'Error',
                                                message:
                                                    'Failed to update price. Please try again.',
                                                contentType:
                                                    ContentType.failure,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    tooltip: 'edit'.tr(),
                                    splashRadius: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final confirmDelete =
                                          await _showDeleteConfirmationDialog(
                                              context, product.name);
                                      if (confirmDelete == true) {
                                        try {
                                          final userId = ref
                                              .read(authServiceProvider)
                                              .currentUser
                                              ?.id;
                                          if (userId != null) {
                                            await ref
                                                .read(productRepositoryProvider)
                                                .removeProductFromDistributorCatalog(
                                                  distributorId: userId,
                                                  productId: product.id,
                                                  package:
                                                      product.selectedPackage ??
                                                          '',
                                                );

                                            ref
                                                .read(cachingServiceProvider)
                                                .invalidateWithPrefix(
                                                    'my_products_');
                                            ref.invalidate(myProductsProvider);

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                elevation: 0,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                backgroundColor:
                                                    Colors.transparent,
                                                content: AwesomeSnackbarContent(
                                                  title: 'Success',
                                                  message:
                                                      'Product deleted successfully',
                                                  contentType:
                                                      ContentType.success,
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              elevation: 0,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor:
                                                  Colors.transparent,
                                              content: AwesomeSnackbarContent(
                                                title: 'Error',
                                                message:
                                                    'Failed to delete product. Please try again.',
                                                contentType:
                                                    ContentType.failure,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    tooltip: 'delete'.tr(),
                                    splashRadius: 20,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
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
            error: (error, stack) =>
                LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
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
                          '${'An error occurred:'.tr()} $error',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}