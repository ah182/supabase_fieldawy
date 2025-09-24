import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/orders/domain/order_item_model.dart';
import 'package:fieldawy_store/features/orders/presentation/screens/distributor_order_details_screen.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:fieldawy_store/features/orders/application/orders_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider);
    final theme = Theme.of(context);
    final distributorsAsync = ref.watch(distributorsProvider);

    return MainScaffold(
      selectedIndex: 2, // Index for Orders screen
      appBar: AppBar(
        title: Text(
          'سلة الطلبات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (order.isNotEmpty)
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
                  ref.read(orderProvider.notifier).clearOrder();
                },
              ),
            ),
        ],
      ),
      body: distributorsAsync.when(
        data: (distributorsData) {
          final groupedByDistributor = <String, List<OrderItemModel>>{};
          for (final item in order) {
            final distributorName = item.product.distributorId ?? 'غير محدد';
            if (groupedByDistributor.containsKey(distributorName)) {
              groupedByDistributor[distributorName]!.add(item);
            } else {
              groupedByDistributor[distributorName] = [item];
            }
          }

          final distributors = groupedByDistributor.keys.toList();

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
                                color:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.7),
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
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: distributors.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final distributorName = distributors[index];
                          final products =
                              groupedByDistributor[distributorName]!;
                          final totalQuantity = products.fold<int>(
                              0, (sum, item) => sum + item.quantity);

                          final distributor = distributorsData.firstWhere(
                            (d) => d.displayName == distributorName,
                            orElse: () => distributorsData.first,
                          );
                          final role = distributor.distributorType;

                          return Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow
                                      .withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color:
                                    theme.colorScheme.outline.withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DistributorOrderDetailsScreen(
                                        distributorName: distributorName,
                                        products: products,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: distributor.photoURL != null &&
                                                  distributor
                                                      .photoURL!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl:
                                                      distributor.photoURL!,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                    color: theme.colorScheme
                                                        .primaryContainer,
                                                    child: Icon(
                                                      Icons.person,
                                                      color: theme.colorScheme
                                                          .onPrimaryContainer,
                                                      size: 28,
                                                    ),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Container(
                                                    color: theme.colorScheme
                                                        .primaryContainer,
                                                    child: Icon(
                                                      Icons.person,
                                                      color: theme.colorScheme
                                                          .onPrimaryContainer,
                                                      size: 28,
                                                    ),
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.person,
                                                  color: theme.colorScheme
                                                      .onPrimaryContainer,
                                                  size: 28,
                                                ),
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // Info section
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Distributor name
                                            Text(
                                              distributorName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),

                                            const SizedBox(height: 8),

                                            // Products count
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme
                                                        .secondaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 14,
                                                        color: theme.colorScheme
                                                            .onSecondaryContainer,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$totalQuantity Products',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
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

                                            // Distributor type
                                            if (role != null)
                                              Row(
                                                children: [
                                                  Icon(
                                                    role == 'company'
                                                        ? Icons.business
                                                        : Icons.person_outline,
                                                    size: 15,
                                                    color: theme
                                                        .colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    role == 'company'
                                                        ? 'Distribution compny '
                                                        : 'Individual distributor ',
                                                    style: TextStyle(
                                                      color: theme
                                                          .colorScheme.primary,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Arrow
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
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

              // Bottom action button
              if (order.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('تم إرسال الطلب بنجاح!'),
                              backgroundColor: theme.colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                          ref.read(orderProvider.notifier).clearOrder();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'إتمام وإرسال الطلب',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    );
  }
}
