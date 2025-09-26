import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/orders/domain/order_item_model.dart';
import 'package:fieldawy_store/features/orders/presentation/screens/distributor_order_details_screen.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/widgets/unified_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:fieldawy_store/features/orders/application/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedDistributors = {};
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String distributorName) {
    setState(() {
      if (_selectedDistributors.contains(distributorName)) {
        _selectedDistributors.remove(distributorName);
      } else {
        _selectedDistributors.add(distributorName);
      }
      if (_selectedDistributors.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _startSelectionMode(String distributorName) {
    setState(() {
      _isSelectionMode = true;
      _selectedDistributors.add(distributorName);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedDistributors.clear();
    });
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref, bool hasOrders) {
    final theme = Theme.of(context);
    if (_isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        ),
        title: Text('${_selectedDistributors.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('تأكيد الحذف'),
                    content: Text(
                        'هل أنت متأكد من حذف ${_selectedDistributors.length} طلب؟'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('إلغاء'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                      TextButton(
                        child: Text('حذف',
                            style: TextStyle(color: theme.colorScheme.error)),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          ref
                              .read(orderProvider.notifier)
                              .removeProductsByDistributors(
                                  _selectedDistributors);
                          final snackBar = SnackBar(
                            elevation: 0,
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.transparent,
                            content: AwesomeSnackbarContent(
                              title: 'نجاح'.tr(),
                              message: 'تم حذف الطلبات المحددة بنجاح.',
                              contentType: ContentType.success,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          _exitSelectionMode();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      );
    }

    return AppBar(
      title: Text(
        'Orders list ',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      actions: [
        if (hasOrders)
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(
                Icons.delete_sweep_outlined,
                color: theme.colorScheme.error,
                size: 22,
              ),
              tooltip: 'مسح كل الطلبات',
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('تأكيد الحذف'),
                        content: const Text(
                            'هل أنت متأكد من رغبتك في مسح كل الطلبات؟'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('إلغاء'),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                          TextButton(
                            child: Text('مسح',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error)),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              ref.read(orderProvider.notifier).clearOrder();
                              final snackBar = SnackBar(
                                elevation: 0,
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.transparent,
                                content: AwesomeSnackbarContent(
                                  title: 'نجاح'.tr(),
                                  message: 'تم مسح كل الطلبات بنجاح.',
                                  contentType: ContentType.success,
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            },
                          ),
                        ],
                      );
                    });
              },
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: UnifiedSearchBar(
            controller: _searchController,
            hintText: 'ابحث عن طلبات موزع...',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider);
    final theme = Theme.of(context);
    final distributorsAsync = ref.watch(distributorsProvider);

    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: MainScaffold(
          selectedIndex: 2, // Index for Orders screen
          appBar: _buildAppBar(context, ref, order.isNotEmpty),
          body: distributorsAsync.when(
            data: (distributorsData) {
              final groupedByDistributor = <String, List<OrderItemModel>>{};
              for (final item in order) {
                final distributorName =
                    item.product.distributorId ?? 'غير محدد';
                if (groupedByDistributor.containsKey(distributorName)) {
                  groupedByDistributor[distributorName]!.add(item);
                } else {
                  groupedByDistributor[distributorName] = [item];
                }
              }

              final distributors = groupedByDistributor.keys.toList();

              final filteredDistributors = _searchQuery.isEmpty
                  ? distributors
                  : distributors
                      .where((d) =>
                          d.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();

              if (order.isEmpty && _isSelectionMode) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _exitSelectionMode());
              }

              return Column(
                children: [
                  Expanded(
                    child: order.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 64,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'سلة الطلبات فارغة',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'أضف المنتجات من شاشة الموزعين',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : filteredDistributors.isEmpty
                            ? Center(
                                child: Text(
                                    'لا توجد نتائج للبحث عن "$_searchQuery"'),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: filteredDistributors.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final distributorName =
                                      filteredDistributors[index];
                                  final products =
                                      groupedByDistributor[distributorName]!;
                                  final totalQuantity = products.fold<int>(
                                      0, (sum, item) => sum + item.quantity);

                                  final distributor =
                                      distributorsData.firstWhere(
                                    (d) => d.displayName == distributorName,
                                    orElse: () => distributorsData.first,
                                  );
                                  final role = distributor.distributorType;
                                  final isSelected = _selectedDistributors
                                      .contains(distributorName);

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                              .withOpacity(0.2)
                                          : theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outline
                                                .withOpacity(0.12),
                                        width: 1,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onLongPress: () {
                                          if (!_isSelectionMode) {
                                            _startSelectionMode(
                                                distributorName);
                                          }
                                        },
                                        onTap: () {
                                          if (_isSelectionMode) {
                                            _toggleSelection(distributorName);
                                          } else {
                                            showModalBottomSheet(
                                              context: context,
                                              builder: (ctx) => Wrap(
                                                children: <Widget>[
                                                  ListTile(
                                                    leading: const Icon(Icons
                                                        .receipt_long_outlined),
                                                    title: const Text(
                                                        'عرض تفاصيل الطلب الحالي'),
                                                    onTap: () {
                                                      Navigator.of(ctx).pop();
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              DistributorOrderDetailsScreen(
                                                            distributorName:
                                                                distributorName,
                                                            products: products,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(
                                                        Icons.store_outlined),
                                                    title: const Text(
                                                        'الانتقال إلى صفحة الموزع'),
                                                    onTap: () {
                                                      Navigator.of(ctx).pop();
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              DistributorProductsScreen(
                                                            distributor:
                                                                distributor,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: Icon(
                                                        Icons
                                                            .delete_forever_outlined,
                                                        color: theme
                                                            .colorScheme.error),
                                                    title: Text(
                                                        'بدء طلب جديد (حذف الحالي)',
                                                        style: TextStyle(
                                                            color: theme
                                                                .colorScheme
                                                                .error)),
                                                    onTap: () {
                                                      Navigator.of(ctx).pop();
                                                      ref
                                                          .read(orderProvider
                                                              .notifier)
                                                          .removeProductsByDistributor(
                                                              distributorName);
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              DistributorProductsScreen(
                                                            distributor:
                                                                distributor,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme
                                                          .primaryContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: distributor
                                                                      .photoURL !=
                                                                  null &&
                                                              distributor
                                                                  .photoURL!
                                                                  .isNotEmpty
                                                          ? CachedNetworkImage(
                                                              imageUrl:
                                                                  distributor
                                                                      .photoURL!,
                                                              fit: BoxFit.cover,
                                                              placeholder:
                                                                  (context,
                                                                          url) =>
                                                                      Container(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primaryContainer,
                                                              ),
                                                              errorWidget:
                                                                  (context, url,
                                                                          error) =>
                                                                      Icon(
                                                                Icons.person,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onPrimaryContainer,
                                                                size: 28,
                                                              ),
                                                            )
                                                          : Icon(
                                                              Icons.person,
                                                              color: theme
                                                                  .colorScheme
                                                                  .onPrimaryContainer,
                                                              size: 28,
                                                            ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Container(
                                                      width: 56,
                                                      height: 56,
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme.primary
                                                            .withOpacity(0.5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Icon(Icons.check,
                                                          color: Colors.white),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      distributorName,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: theme.colorScheme
                                                            .onSurface,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: theme
                                                                .colorScheme
                                                                .secondaryContainer,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .inventory_2_outlined,
                                                                size: 14,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSecondaryContainer,
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                '$totalQuantity Products',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSecondaryContainer,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    if (role != null)
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            role == 'company'
                                                                ? Icons.business
                                                                : Icons
                                                                    .person_outline,
                                                            size: 15,
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            role == 'company'
                                                                ? 'Distribution compny '
                                                                : 'Individual distributor ',
                                                            style: TextStyle(
                                                              color: theme
                                                                  .colorScheme
                                                                  .primary,
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                ),
                ],
              );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'حدث خطأ في تحميل البيانات',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$err',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
        ));
  }
}
