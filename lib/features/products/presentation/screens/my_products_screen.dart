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
// ignore: unused_import
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

// The animated banner widget - محسن مع لون أوضح
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
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Schedule dismissal
    Future.delayed(const Duration(seconds: 4), () {
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

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _animation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              // لون أوضح وأكثر تباينًا للسناك بار
              color: isDarkMode
                  ? const Color.fromARGB(
                      255, 55, 55, 60) // لون أفتح في الوضع المظلم
                  : const Color.fromARGB(
                      255, 240, 248, 255), // لون أزرق فاتح في الوضع العادي
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.touch_app_rounded,
                        color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.9)
                            : const Color.fromARGB(255, 30, 60, 100),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () {
                        if (mounted) {
                          _controller.reverse().then((_) {
                            widget.onDismiss();
                          });
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        minimumSize: const Size(55, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'حسناً',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
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
  const MyProductsScreen({super.key});

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
    final myProductsAsync = ref.watch(myProductsProvider);
    final userRole = ref.watch(userDataProvider).asData?.value?.role ?? '';
    final searchFocusNode = useFocusNode();
    final isSelectionMode = useState(false);
    final selectedProducts = useState<Set<String>>({});
    final hasShownHint = useState(false);

    useEffect(() {
      if (!hasShownHint.value &&
          !isSelectionMode.value &&
          myProductsAsync is AsyncData<List<ProductModel>> &&
          myProductsAsync.value.isNotEmpty) {
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

    final searchQuery = useState<String>('');

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
                    // زر الحذف المحسن
                    FloatingActionButton(
                      heroTag: "btnDeleteAll",
                      onPressed: () async {
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
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.delete_rounded),
                    ),
                    const SizedBox(width: 12),
                    // زر تحديد الكل المحسن
                    FloatingActionButton(
                      heroTag: "btnSelectAll",
                      onPressed: () async {
                        final myProductsAsync = ref.read(myProductsProvider);
                        if (myProductsAsync is AsyncData<List<ProductModel>>) {
                          final allProductIds = myProductsAsync.value
                              .map((product) =>
                                  '${product.id}_${product.selectedPackage ?? ''}')
                              .toSet();

                          if (selectedProducts.value.length ==
                                  allProductIds.length &&
                              selectedProducts.value
                                  .containsAll(allProductIds)) {
                            selectedProducts.value = {};
                          } else {
                            selectedProducts.value = allProductIds;
                          }
                        }
                      },
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: selectedProducts.value.length > 0 &&
                              selectedProducts.value.length ==
                                  (ref.read(myProductsProvider)
                                          is AsyncData<List<ProductModel>>
                                      ? (ref.read(myProductsProvider)
                                              as AsyncData<List<ProductModel>>)
                                          .value
                                          .length
                                      : 0)
                          ? const Icon(Icons.deselect)
                          : const Icon(Icons.select_all_rounded),
                    ),
                  ],
                ),
              )
            : FloatingActionButton.extended(
                onPressed: () {
                  _showAddProductOptions(context, ref);
                },
                label: Text('addProduct'.tr()),
                icon: const Icon(Icons.add_rounded),
                elevation: 2,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
        appBar: AppBar(
          title: isSelectionMode.value
              ? Text('${selectedProducts.value.length} محدد')
              : Text('myMedicines'.tr()),
          leading: isSelectionMode.value
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    isSelectionMode.value = false;
                    selectedProducts.value = {};
                  },
                )
              : null,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          // تحسين تصميم شريط البحث والعداد
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 40.0),
            child: Column(
              children: [
                // شريط البحث المحسن
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: UnifiedSearchBar(
                    focusNode: searchFocusNode,
                    onChanged: (value) {
                      searchQuery.value = value;
                    },
                    onClear: () {
                      searchQuery.value = '';
                    },
                    hintText: 'ابحث عن منتج...',
                  ),
                ),
                // العداد المحسن
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
                        Icons.inventory_2_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      myProductsAsync.when(
                        data: (products) {
                          if (isSelectionMode.value) {
                            return Text(
                              '${selectedProducts.value.length} من ${products.length} محدد',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            );
                          } else {
                            final totalCount = products.length;
                            final filteredCount = searchQuery.value.isEmpty
                                ? totalCount
                                : products.where((product) {
                                    final query =
                                        searchQuery.value.toLowerCase();
                                    final productName =
                                        product.name.toLowerCase();
                                    final productCompany =
                                        product.company?.toLowerCase() ?? '';
                                    final productActivePrinciple = product
                                            .activePrinciple
                                            ?.toLowerCase() ??
                                        '';
                                    return productName.contains(query) ||
                                        productCompany.contains(query) ||
                                        productActivePrinciple.contains(query);
                                  }).length;

                            return Text(
                              searchQuery.value.isEmpty
                                  ? 'إجمالي المنتجات: $totalCount'
                                  : 'عرض $filteredCount من $totalCount منتج',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
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
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
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
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myProductsProvider);
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: myProductsAsync.when(
            data: (products) {
              List<ProductModel> filteredProducts;
              if (searchQuery.value.isEmpty) {
                filteredProducts = products;
              } else {
                filteredProducts = products.where((product) {
                  final query = searchQuery.value.toLowerCase();
                  final productName = product.name.toLowerCase();
                  final productCompany = product.company?.toLowerCase() ?? '';
                  final productActivePrinciple =
                      product.activePrinciple?.toLowerCase() ?? '';

                  return productName.contains(query) ||
                      productCompany.contains(query) ||
                      productActivePrinciple.contains(query);
                }).toList();
              }

              if (filteredProducts.isEmpty) {
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
                        ),
                      ),
                    );
                  });
                } else {
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
                                Icons.medication_liquid_rounded,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.6),
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
                              FilledButton.icon(
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

              // القائمة المحسنة مع التعديلات المطلوبة
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80.0, top: 8.0),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final isSelected = selectedProducts.value.contains(
                      '${product.id}_${product.selectedPackage ?? ''}');

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
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
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.08)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: isSelectionMode.value
                            ? () {
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
                                if (selectedProducts.value.isEmpty) {
                                  isSelectionMode.value = false;
                                }
                              }
                            : null,
                        onLongPress: isSelectionMode.value
                            ? null
                            : () {
                                isSelectionMode.value = true;
                                selectedProducts.value = {
                                  '${product.id}_${product.selectedPackage ?? ''}'
                                };
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // صورة المنتج (نفس التصميم)
                              GestureDetector(
                                onTap: () {
                                  _showProductDetailDialog(context, product);
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: product.imageUrl,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceVariant,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child:
                                              ImageLoadingIndicator(size: 24),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceVariant,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.medication_rounded,
                                          size: 28,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // معلومات المنتج مع اسم أصغر
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // اسم المنتج بحجم أصغر
                                    Text(
                                      product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize:
                                                15, // حجم أصغر من titleMedium
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if (product.selectedPackage != null &&
                                        product.selectedPackage!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    // السعر
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${product.price?.toStringAsFixed(2) ?? '0.00'} جنيه',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // الأزرار أو Checkbox
                              if (isSelectionMode.value)
                                Checkbox(
                                  value: selectedProducts.value.contains(
                                      '${product.id}_${product.selectedPackage ?? ''}'),
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
                                      if (selectedProducts.value.isEmpty) {
                                        isSelectionMode.value = false;
                                      }
                                    }
                                  },
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // زر التعديل بأيقونة أصغر
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_rounded,
                                            size: 16), // أيقونة أصغر
                                        color: Colors.blue[600],
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
                                                    .read(
                                                        productRepositoryProvider)
                                                    .updateProductPriceInDistributorCatalog(
                                                      distributorId: userId,
                                                      productId: product.id,
                                                      package: product
                                                              .selectedPackage ??
                                                          '',
                                                      newPrice: newPrice,
                                                    );

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    elevation: 0,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    content:
                                                        AwesomeSnackbarContent(
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
                                                  content:
                                                      AwesomeSnackbarContent(
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
                                        constraints: const BoxConstraints(
                                          minWidth: 32, // حجم أصغر
                                          minHeight: 32, // حجم أصغر
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // زر الحذف بأيقونة أصغر
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_rounded,
                                            size: 16), // أيقونة أصغر
                                        color: Colors.red[600],
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
                                                    .read(
                                                        productRepositoryProvider)
                                                    .removeProductFromDistributorCatalog(
                                                      distributorId: userId,
                                                      productId: product.id,
                                                      package: product
                                                              .selectedPackage ??
                                                          '',
                                                    );

                                                ref
                                                    .read(
                                                        cachingServiceProvider)
                                                    .invalidateWithPrefix(
                                                        'my_products_');
                                                ref.invalidate(
                                                    myProductsProvider);

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    elevation: 0,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    content:
                                                        AwesomeSnackbarContent(
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
                                                  content:
                                                      AwesomeSnackbarContent(
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
                                        constraints: const BoxConstraints(
                                          minWidth: 32, // حجم أصغر
                                          minHeight: 32, // حجم أصغر
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
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
