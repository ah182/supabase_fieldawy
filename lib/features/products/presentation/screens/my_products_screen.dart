import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/application/catalog_selection_controller.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:flutter/material.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:flutter_hooks/flutter_hooks.dart';


import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';

import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/widgets/custom_product_dialog.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

// Widget to watch tab index changes and update the count accordingly
class TabIndexWatcher extends HookConsumerWidget {
  final TabController tabController;
  final AsyncValue<List<ProductModel>> myProductsAsync;
  final ValueNotifier<String> searchQuery;
  final ValueNotifier<bool> isSelectionMode;
  final ValueNotifier<Set<String>> selectedProducts;

  const TabIndexWatcher({
    Key? key,
    required this.tabController,
    required this.myProductsAsync,
    required this.searchQuery,
    required this.isSelectionMode,
    required this.selectedProducts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the tab index as a dependency to rebuild when tab changes
    final tabIndex = useState(tabController.index);
    
    // Listen to tab changes
    useEffect(() {
      void listener() {
        tabIndex.value = tabController.index;
      }
      
      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    // For Main tab (index 0)
    if (tabIndex.value == 0) {
      return myProductsAsync.when(
        data: (products) {
          if (isSelectionMode.value) {
            return Text(
              'products.selected_count'.tr(namedArgs: {'count': selectedProducts.value.length.toString()}),
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
                    // ... (filtering logic remains same)
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
                  ? 'products.total_count'.tr(namedArgs: {'count': totalCount.toString()})
                  : 'products.showing_count'.tr(namedArgs: {'shown': filteredCount.toString(), 'total': totalCount.toString()}),
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
          'distributors_feature.counting'.tr(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
        ),
        error: (_, __) => Text(
          'distributors_feature.count_error'.tr(),
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
        ),
      );
    } 
    // For OCR tab (index 1)
    else {
      final myOcrProductsAsync = ref.watch(myOcrProductsProvider);
      return myOcrProductsAsync.when(
        data: (products) {
          if (isSelectionMode.value) {
            return Text(
              'products.selected_count'.tr(namedArgs: {'count': selectedProducts.value.length.toString()}),
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
                    // ... (filtering logic remains same)
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
                  ? 'products.total_ocr'.tr(namedArgs: {'count': totalCount.toString()})
                  : 'products.showing_ocr'.tr(namedArgs: {'shown': filteredCount.toString(), 'total': totalCount.toString()}),
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
          'settings_feature.loading'.tr(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
        ),
        error: (_, __) => Text(
          'notifications_feature.error'.tr(namedArgs: {'error': ''}),
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
        ),
      );
    }
  }
}

// Helper function to show the animated banner
void _showAnimatedBanner(BuildContext context) {
  OverlayEntry? overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => _AnimatedTopBanner(
      message: 'products.selection_hint'.tr(),
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
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

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
              color: isDarkMode
                  ? const Color.fromARGB(255, 55, 55, 60)
                  : const Color.fromARGB(255, 240, 248, 255),
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
                        'distributors_feature.ok'.tr(),
                        style: const TextStyle(
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
      title: 'products.confirm_delete'.tr(),
      desc: 'products.delete_msg'.tr(namedArgs: {'name': productName}),
      btnCancelText: 'products.cancel'.tr(),
      btnOkText: 'products.delete'.tr(),
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
      title: 'products.update_price'.tr(),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'products.new_price'.tr(),
              suffixText: 'products.currency'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      btnCancelText: 'products.cancel'.tr(),
      btnOkText: 'products.update'.tr(),
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
                title: 'notifications_feature.error'.tr(namedArgs: {'error': ''}),
                message: 'products.invalid_price'.tr(),
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
                title: Text('products.add_from_catalog'.tr()),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const AddFromCatalogScreen(catalogContext: CatalogContext.myProducts)),
                  );
                  ref.invalidate(myProductsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('products.scan_camera'.tr()),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const AddProductOcrScreen(
                            showExpirationDate: false)),
                  );
                  ref.invalidate(myProductsProvider);
                  ref.invalidate(myOcrProductsProvider);
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

    // إضافة TabController
    final tabController = useTabController(initialLength: 2);

    // Selection states for each tab
    final mainTabSelection = useState<Set<String>>({});
    final ocrTabSelection = useState<Set<String>>({});
    final mainTabSelectionMode = useState(false);
    final ocrTabSelectionMode = useState(false);

    final searchQuery = useState<String>('');
    final ghostText = useState<String>('');
    final fullSuggestion = useState<String>('');
    final searchController = useTextEditingController();

    // دالة مساعدة لإخفاء الكيبورد
    void hideKeyboard() {
      if (searchFocusNode.hasFocus) {
        searchFocusNode.unfocus();
        // إعادة تعيين النص الشبحي إذا كان مربع البحث فارغاً
        if (searchController.text.isEmpty) {
          ghostText.value = '';
          fullSuggestion.value = '';
        }
      }
    }

    // إضافة مراقب للتابات مع تحسينات UX
    final currentTabIndex = useState(tabController.index);
    useEffect(() {
      void tabListener() {
        final newIndex = tabController.index;
        if (currentTabIndex.value != newIndex) {
          currentTabIndex.value = newIndex;
          // إخفاء الكيبورد عند تغيير التاب
          hideKeyboard();
        }
      }
      tabController.addListener(tabListener);
      return () => tabController.removeListener(tabListener);
    }, [tabController]);

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

    if (userRole != 'distributor' && userRole != 'company' && userRole != 'admin') {
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

    ref.listen(myProductsProvider, (previous, next) {});

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        hideKeyboard();
      },
      child: MainScaffold(
        selectedIndex: 0,
        floatingActionButton: Builder(
          builder: (context) {
            // Determine which tab is currently active
            final currentTab = tabController.index;
            
            // Check if the currently active tab is in selection mode
            final isCurrentTabInSelectionMode = (currentTab == 0) 
                ? mainTabSelectionMode.value 
                : ocrTabSelectionMode.value;
            
            // Get OCR products if needed for OCR tab
            final myOcrProductsAsync = ref.watch(myOcrProductsProvider);
            
            // Show selection FAB only if the currently active tab is in selection mode
            if (isCurrentTabInSelectionMode) {
              // If currently on OCR tab and it's in selection mode
              if (currentTab == 1) {
                if (myOcrProductsAsync is AsyncData<List<ProductModel>>) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FloatingActionButton(
                          heroTag: "btnDeleteAllOcr",
                          onPressed: () async {
                            if (ocrTabSelection.value.isNotEmpty) {
                              final confirmDelete = await _showDeleteConfirmationDialog(
                                  context,
                                  '${ocrTabSelection.value.length} selected products');
                              if (confirmDelete == true) {
                                try {
                                  final userId =
                                      ref.read(authServiceProvider).currentUser?.id;
                                  if (userId != null) {
                                    // Extract OCR product IDs from the selection format
                                    final ocrProductIds = ocrTabSelection.value
                                        .map((idWithPackage) {
                                          // For OCR products, the format is likely just 'id' or 'id_package'
                                          // Split by '_' and take the first part which should be the OCR product ID
                                          final parts = idWithPackage.split('_');
                                          return parts.first;
                                        })
                                        .toList();
                                    
                                    await ref
                                        .read(productRepositoryProvider)
                                        .removeMultipleOcrProductsFromDistributorCatalog(
                                          distributorId: userId,
                                          ocrProductIds: ocrProductIds,
                                        );

                                    ref
                                        .read(cachingServiceProvider)
                                        .invalidateWithPrefix('my_products_');
                                    ref.invalidate(myOcrProductsProvider);

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
                                    // Reset OCR tab selection
                                    ocrTabSelection.value = {};
                                    ocrTabSelectionMode.value = false;
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
                        FloatingActionButton(
                          heroTag: "btnSelectAllOcr",
                          onPressed: () {
                            final myOcrProductsAsync = ref.read(myOcrProductsProvider);
                            if (myOcrProductsAsync is AsyncData<List<ProductModel>>) {
                              final allProductIds = myOcrProductsAsync.value
                                  .map((product) =>
                                      '${product.id}_${product.selectedPackage ?? ''}')
                                  .toSet();

                              if (ocrTabSelection.value.length ==
                                      allProductIds.length &&
                                  ocrTabSelection.value
                                      .containsAll(allProductIds)) {
                                ocrTabSelection.value = {};
                              } else {
                                ocrTabSelection.value = allProductIds;
                              }
                            }
                          },
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: ocrTabSelection.value.length > 0 &&
                                  ocrTabSelection.value.length ==
                                      (ref.read(myOcrProductsProvider)
                                              is AsyncData<List<ProductModel>>
                                          ? (ref.read(myOcrProductsProvider)
                                                  as AsyncData<List<ProductModel>>)
                                              .value
                                              .length
                                          : 0)
                              ? const Icon(Icons.deselect)
                              : const Icon(Icons.select_all_rounded),
                        ),
                      ],
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              } 
              // For Main tab (current functionality)
              else {
                // ignore: unused_local_variable
                final myProductsAsync = ref.read(myProductsProvider);
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        heroTag: "btnDeleteAllMain",
                        onPressed: () async {
                          if (mainTabSelection.value.isNotEmpty) {
                            final confirmDelete = await _showDeleteConfirmationDialog(
                                context,
                                '${mainTabSelection.value.length} selected products');
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
                                            mainTabSelection.value.toList(),
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
                                  mainTabSelection.value = {};
                                  mainTabSelectionMode.value = false;
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
                      FloatingActionButton(
                        heroTag: "btnSelectAllMain",
                        onPressed: () async {
                          final myProductsAsync = ref.read(myProductsProvider);
                          if (myProductsAsync is AsyncData<List<ProductModel>>) {
                            final allProductIds = myProductsAsync.value
                                .map((product) =>
                                    '${product.id}_${product.selectedPackage ?? ''}')
                                .toSet();

                            if (mainTabSelection.value.length ==
                                    allProductIds.length &&
                                mainTabSelection.value
                                    .containsAll(allProductIds)) {
                              mainTabSelection.value = {};
                            } else {
                              mainTabSelection.value = allProductIds;
                            }
                          }
                        },
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        child: mainTabSelection.value.length > 0 &&
                                mainTabSelection.value.length ==
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
                );
              }
            } else {
              return FloatingActionButton.extended(
                onPressed: () {
                  _showAddProductOptions(context, ref);
                },
                label: Text('products.add_product'.tr()),
                icon: const Icon(Icons.add_rounded),
                elevation: 2,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              );
            }
          },
        ),
        appBar: AppBar(
          title: (tabController.index == 0 ? mainTabSelectionMode.value : ocrTabSelectionMode.value)
              ? Text('products.selected_count'.tr(namedArgs: {'count': (tabController.index == 0 ? mainTabSelection.value : ocrTabSelection.value).length.toString()}))
              : Text('myMedicines'.tr()),
          leading: (tabController.index == 0 ? mainTabSelectionMode.value : ocrTabSelectionMode.value)
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    // Reset the current tab's selection
                    if (tabController.index == 0) {
                      mainTabSelectionMode.value = false;
                      mainTabSelection.value = {};
                    } else {
                      ocrTabSelectionMode.value = false;
                      ocrTabSelection.value = {};
                    }
                  },
                )
              : null,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 100.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Stack(
                    children: [
                      TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: (value) {
                          searchQuery.value = value;
                          
                          // Update ghost text immediately based on active tab
                          if (value.isNotEmpty) {
                            final isMainTab = tabController.index == 0;
                            final productsAsync = isMainTab ? myProductsAsync : ref.read(myOcrProductsProvider);
                            
                            if (productsAsync is AsyncData<List<ProductModel>>) {
                              final products = productsAsync.value;
                              final matches = products.where((product) {
                                return product.name.toLowerCase().startsWith(value.toLowerCase());
                              }).toList();
                              
                              if (matches.isNotEmpty) {
                                ghostText.value = matches.first.name;
                                fullSuggestion.value = matches.first.name;
                              } else {
                                ghostText.value = '';
                                fullSuggestion.value = '';
                              }
                            }
                          } else {
                            ghostText.value = '';
                            fullSuggestion.value = '';
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'products.search_hint'.tr(),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    searchQuery.value = '';
                                    ghostText.value = '';
                                    fullSuggestion.value = '';
                                    searchFocusNode.unfocus();
                                  },
                                )
                              : null,
                        ),
                      ),
                      if (ghostText.value.isNotEmpty)
                        Positioned(
                          top: 11,
                          right: 55,
                          child: GestureDetector(
                            onTap: () {
                              if (fullSuggestion.value.isNotEmpty) {
                                searchController.text = fullSuggestion.value;
                                searchQuery.value = fullSuggestion.value;
                                ghostText.value = '';
                                fullSuggestion.value = '';
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ghostText.value,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
                      // Count widget that rebuilds when tab changes
                      TabIndexWatcher(
                        tabController: tabController,
                        myProductsAsync: myProductsAsync,
                        searchQuery: searchQuery,
                        isSelectionMode: isSelectionMode,
                        selectedProducts: selectedProducts,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // TabBar المحسن
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: tabController,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(2),
                    labelColor: Colors.white,
                    unselectedLabelColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.grid_view_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text('products.main'.tr()),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text('products.ocr'.tr()),
                            ],
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
        body: TabBarView(
          controller: tabController,
          children: [
            // Main Tab - المحتوى الأصلي
            _buildMainTabContent(
              context,
              ref,
              myProductsAsync,
              searchQuery,
              mainTabSelectionMode,
              mainTabSelection,
              searchFocusNode,
            ),
            // OCR Tab - منتجات OCR الخاصة بالموزع
            _buildOCRTabContent(context, ref, searchQuery, ocrTabSelection, ocrTabSelectionMode),
          ],
        ),
      ),
    );
  }

  // محتوى التاب الرئيسي (Main)
  Widget _buildMainTabContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ProductModel>> myProductsAsync,
    ValueNotifier<String> searchQuery,
    ValueNotifier<bool> mainTabSelectionMode,
    ValueNotifier<Set<String>> mainTabSelection,
    FocusNode searchFocusNode,
  ) {
    return RefreshIndicator(
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
                            'products.no_medicines'.tr(),
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
                                        const AddFromCatalogScreen(catalogContext: CatalogContext.myProducts)),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: Text('products.add_product'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              });
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0, top: 8.0),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              final isSelected = mainTabSelection.value
                  .contains('${product.id}_${product.selectedPackage ?? ''}');

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: mainTabSelectionMode.value
                        ? () {
                            final productIdWithPackage =
                                '${product.id}_${product.selectedPackage ?? ''}';
                            if (mainTabSelection.value
                                .contains(productIdWithPackage)) {
                              mainTabSelection.value = Set.from(
                                  mainTabSelection.value
                                    ..remove(productIdWithPackage));
                            } else {
                              mainTabSelection.value = Set.from(
                                  mainTabSelection.value
                                    ..add(productIdWithPackage));
                            }
                            if (mainTabSelection.value.isEmpty) {
                              mainTabSelectionMode.value = false;
                            }
                          }
                        : null,
                    onLongPress: mainTabSelectionMode.value
                        ? null
                        : () {
                            mainTabSelectionMode.value = true;
                            mainTabSelection.value = {
                              '${product.id}_${product.selectedPackage ?? ''}'
                            };
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
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
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: ImageLoadingIndicator(size: 24),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
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
                                      borderRadius: BorderRadius.circular(8),
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
                                    '${NumberFormatter.formatCompact(product.price ?? 0)} جنيه',
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
                          if (mainTabSelectionMode.value)
                            Checkbox(
                              value: mainTabSelection.value.contains(
                                  '${product.id}_${product.selectedPackage ?? ''}'),
                              onChanged: (bool? value) {
                                final productIdWithPackage =
                                    '${product.id}_${product.selectedPackage ?? ''}';
                                if (value == true) {
                                  mainTabSelection.value = Set.from(
                                      mainTabSelection.value
                                        ..add(productIdWithPackage));
                                } else {
                                  mainTabSelection.value = Set.from(
                                      mainTabSelection.value
                                        ..remove(productIdWithPackage));
                                  if (mainTabSelection.value.isEmpty) {
                                    mainTabSelectionMode.value = false;
                                  }
                                }
                              },
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 16),
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                elevation: 0,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                backgroundColor:
                                                    Colors.transparent,
                                                content: AwesomeSnackbarContent(
                                                  title: 'orders.success'.tr(),
                                                  message:
                                                      'products.price_success'.tr(),
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
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_rounded,
                                        size: 16),
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                elevation: 0,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                backgroundColor:
                                                    Colors.transparent,
                                                content: AwesomeSnackbarContent(
                                                  title: 'orders.success'.tr(),
                                                  message:
                                                      'products.delete_success'.tr(),
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
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
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
        error: (error, stack) => LayoutBuilder(builder: (context, constraints) {
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
                      'products.error_occurred'.tr(namedArgs: {'error': error.toString()}),
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
    );
  }

  // محتوى تاب OCR - يعرض منتجات OCR الخاصة بالموزع
  Widget _buildOCRTabContent(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<String> searchQuery,
    ValueNotifier<Set<String>> ocrTabSelection,
    ValueNotifier<bool> ocrTabSelectionMode,
  ) {
    final myOcrProductsAsync = ref.watch(myOcrProductsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myOcrProductsProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: myOcrProductsAsync.when(
        data: (products) {
          // Filter products based on search query
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
                            Icons.camera_alt_rounded,
                            size: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.6),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'products.no_ocr_products'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'products.no_ocr_desc'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AddProductOcrScreen(
                                            showExpirationDate: false)),
                              );
                              ref.invalidate(myOcrProductsProvider);
                            },
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: Text('products.scan_product'.tr()),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              });
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0, top: 8.0),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              final isSelected = ocrTabSelection.value
                  .contains('${product.id}_${product.selectedPackage ?? ''}');

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: ocrTabSelectionMode.value
                        ? () {
                            final productIdWithPackage =
                                '${product.id}_${product.selectedPackage ?? ''}';
                            if (ocrTabSelection.value
                                .contains(productIdWithPackage)) {
                              ocrTabSelection.value = Set.from(
                                  ocrTabSelection.value
                                    ..remove(productIdWithPackage));
                            } else {
                              ocrTabSelection.value = Set.from(
                                  ocrTabSelection.value
                                    ..add(productIdWithPackage));
                            }
                            if (ocrTabSelection.value.isEmpty) {
                              ocrTabSelectionMode.value = false;
                            }
                          }
                        : () {
                            _showProductDetailDialog(context, product);
                          },
                    onLongPress: ocrTabSelectionMode.value
                        ? null
                        : () {
                            ocrTabSelectionMode.value = true;
                            ocrTabSelection.value = {
                              '${product.id}_${product.selectedPackage ?? ''}'
                            };
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Product Image
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: product.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
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
                                          Icons.camera_alt_rounded,
                                          size: 28,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.camera_alt_rounded,
                                      size: 28,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Product Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                               
                                Row(
                                  
                                  children: [
                                   
                                    
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                     Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      
                                      child: Row(
                                        
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          
                                          Icon(
                                            Icons.camera_alt_rounded,
                                            size: 10,
                                            color: Colors.orange[700],
                                          ),
                                          const SizedBox(width: 2),
                                          
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                ),
                                
                                
                               
                                const SizedBox(height: 8),
                                if (product.selectedPackage != null &&
                                    product.selectedPackage!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
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
                                const SizedBox(height: 8),
                                if (product.price != null)
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
                                      '${NumberFormatter.formatCompact(product.price ?? 0)} جنيه',
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
                          if (ocrTabSelectionMode.value)
                            Checkbox(
                              value: ocrTabSelection.value.contains(
                                  '${product.id}_${product.selectedPackage ?? ''}'),
                              onChanged: (bool? value) {
                                final productIdWithPackage =
                                    '${product.id}_${product.selectedPackage ?? ''}';
                                if (value == true) {
                                  ocrTabSelection.value = Set.from(
                                      ocrTabSelection.value
                                        ..add(productIdWithPackage));
                                } else {
                                  ocrTabSelection.value = Set.from(
                                      ocrTabSelection.value
                                        ..remove(productIdWithPackage));
                                  if (ocrTabSelection.value.isEmpty) {
                                    ocrTabSelectionMode.value = false;
                                  }
                                }
                              },
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 16),
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
                                                .read(productRepositoryProvider)
                                                .updateOcrProductPrice(
                                                  distributorId: userId,
                                                  ocrProductId: product.id,
                                                  newPrice: newPrice,
                                                );

                                            ref
                                                .read(cachingServiceProvider)
                                                .invalidateWithPrefix(
                                                    'my_products_');
                                            ref.invalidate(myOcrProductsProvider);

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
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_rounded,
                                        size: 16),
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
                                                .read(productRepositoryProvider)
                                                .removeOcrProductFromDistributorCatalog(
                                                  distributorId: userId,
                                                  ocrProductId: product.id,
                                                );

                                            ref
                                                .read(cachingServiceProvider)
                                                .invalidateWithPrefix(
                                                    'my_products_');
                                            ref.invalidate(myOcrProductsProvider);

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
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
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
        error: (error, stack) => LayoutBuilder(builder: (context, constraints) {
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
                      'An error occurred: $error',
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
    );
  }
}
