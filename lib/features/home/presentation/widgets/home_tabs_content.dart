import 'package:fieldawy_store/features/products/application/expire_drugs_provider.dart';
import 'package:fieldawy_store/features/products/application/surgical_tools_home_provider.dart';
import 'package:fieldawy_store/features/products/application/offers_home_provider.dart';
import 'package:fieldawy_store/widgets/product_card.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'product_dialogs.dart';

// ===================================================================
// Expire Soon Tab - المنتجات منتهية الصلاحية
// ===================================================================
class ExpireSoonTab extends ConsumerWidget {
  const ExpireSoonTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expireDrugsAsync = ref.watch(expireDrugsProvider);

    return expireDrugsAsync.when(
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
      data: (items) {
        // تطبيق البحث
        final filteredItems = searchQuery.isEmpty
            ? items
            : items.where((item) {
                final query = searchQuery.toLowerCase();
                final product = item.product;
                return product.name.toLowerCase().contains(query) ||
                    (product.activePrinciple ?? '')
                        .toLowerCase()
                        .contains(query) ||
                    (product.company ?? '').toLowerCase().contains(query);
              }).toList();

        if (filteredItems.isEmpty) {
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
                      ? 'لا توجد منتجات منتهية الصلاحية'
                      : 'لا توجد نتائج للبحث عن "$searchQuery"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(expireDrugsProvider.future),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return ProductCard(
                product: item.product,
                searchQuery: searchQuery,
                onTap: () {
                  showProductDialog(
                    context,
                    item.product,
                    expirationDate: item.expirationDate,
                  );
                },
                overlayBadge: item.expirationDate != null
                    ? _buildExpirationBadge(
                        context,
                        item.expirationDate!,
                      )
                    : null,
              );
            },
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }

  Widget _buildExpirationBadge(BuildContext context, DateTime expirationDate) {
    final now = DateTime.now();
    final isExpired = expirationDate.isBefore(DateTime(now.year, now.month + 1));

    return Positioned(
      bottom: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isExpired ? Colors.red.shade700 : Colors.orange.shade700,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpired ? Icons.warning_rounded : Icons.schedule_rounded,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('MM/yyyy').format(expirationDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// Surgical & Diagnostic Tab - الأدوات الجراحية
// ===================================================================
class SurgicalDiagnosticTab extends ConsumerWidget {
  const SurgicalDiagnosticTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(surgicalToolsHomeProvider);

    return toolsAsync.when(
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
      data: (tools) {
        // تطبيق البحث
        final filteredTools = searchQuery.isEmpty
            ? tools
            : tools.where((tool) {
                final query = searchQuery.toLowerCase();
                return tool.name.toLowerCase().contains(query) ||
                    (tool.company ?? '').toLowerCase().contains(query) ||
                    (tool.description ?? '').toLowerCase().contains(query);
              }).toList();

        if (filteredTools.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty
                      ? Icons.medical_services_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? 'لا توجد أدوات جراحية'
                      : 'لا توجد نتائج للبحث عن "$searchQuery"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(surgicalToolsHomeProvider.future),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.65, // زيادة الارتفاع لاستيعاب badge الحالة
            ),
            itemCount: filteredTools.length,
            itemBuilder: (context, index) {
              final tool = filteredTools[index];
              return ProductCard(
                product: tool,
                searchQuery: searchQuery,
                onTap: () {
                  showSurgicalToolDialog(context, tool);
                },
                statusBadge: tool.activePrinciple != null &&
                        tool.activePrinciple!.isNotEmpty
                    ? _buildStatusBadge(
                        context,
                        tool.activePrinciple!,
                      )
                    : null,
              );
            },
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color getBadgeColor() {
      switch (status) {
        case 'جديد':
          return Colors.green;
        case 'مستعمل':
          return Colors.orange;
        case 'كسر زيرو':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    IconData getBadgeIcon() {
      switch (status) {
        case 'جديد':
          return Icons.new_releases_rounded;
        case 'مستعمل':
          return Icons.history_rounded;
        case 'كسر زيرو':
          return Icons.star_rounded;
        default:
          return Icons.info_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getBadgeColor(),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getBadgeIcon(),
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Offers Tab - العروض
// ===================================================================
class OffersTab extends ConsumerWidget {
  const OffersTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersHomeProvider);

    return offersAsync.when(
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
      data: (offerItems) {
        // تطبيق البحث
        final filteredOfferItems = searchQuery.isEmpty
            ? offerItems
            : offerItems.where((item) {
                final query = searchQuery.toLowerCase();
                final offer = item.product;
                return offer.name.toLowerCase().contains(query) ||
                    (offer.activePrinciple ?? '')
                        .toLowerCase()
                        .contains(query) ||
                    (offer.company ?? '').toLowerCase().contains(query);
              }).toList();

        if (filteredOfferItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchQuery.isEmpty
                      ? Icons.local_offer_outlined
                      : Icons.search_off_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? 'لا توجد عروض متاحة'
                      : 'لا توجد نتائج للبحث عن "$searchQuery"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(offersHomeProvider.future),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75,
            ),
            itemCount: filteredOfferItems.length,
            itemBuilder: (context, index) {
              final item = filteredOfferItems[index];
              return ProductCard(
                product: item.product,
                searchQuery: searchQuery,
                onTap: () {
                  showOfferProductDialog(
                    context,
                    item.product,
                    expirationDate: item.expirationDate,
                  );
                },
                overlayBadge: Positioned(
                  top: 6,
                  left: -40,
                  child: Transform.rotate(
                    angle: -0.785398, // -45 درجة
                    child: Container(
                      width: 120,
                      height: 25,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE53935), // أحمر غامق
                            Color(0xFFEF5350), // أحمر فاتح
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Offer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
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
