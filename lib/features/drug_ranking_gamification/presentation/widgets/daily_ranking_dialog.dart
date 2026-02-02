import 'package:fieldawy_store/core/theme/app_colors.dart';
import 'package:fieldawy_store/features/drug_ranking_gamification/data/drug_ranking_service.dart';
import 'package:fieldawy_store/features/drug_ranking_gamification/domain/daily_challenge_model.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DailyRankingDialog extends ConsumerStatefulWidget {
  final DailyChallengeModel challenge;
  final DrugRankingService rankingService;

  const DailyRankingDialog({
    Key? key,
    required this.challenge,
    required this.rankingService,
  }) : super(key: key);

  @override
  ConsumerState<DailyRankingDialog> createState() => _DailyRankingDialogState();
}

class _DailyRankingDialogState extends ConsumerState<DailyRankingDialog> {
  late List<ProductModel> _orderedProducts;

  @override
  void initState() {
    super.initState();
    _orderedProducts = List.from(widget.challenge.products);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.scaffoldBackgroundColor,
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Gamification elements
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded,
                      color: AppColors.primaryColor, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "تحدي الخبرة اليومي",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "رتب حسب الكفاءة: ${widget.challenge.activePrinciple}",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(isDark ? 0.2 : 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "اسحب لترتيب المنتجات: رقم 1 هو الأكثر كفاءة.",
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Draggable List
            SizedBox(
              height: 450, // Increased height for better visibility
              child: ReorderableListView.builder(
                itemCount: _orderedProducts.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _orderedProducts.removeAt(oldIndex);
                    _orderedProducts.insert(newIndex, item);
                  });
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      return Material(
                        color: Colors.transparent, // Background transparent
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: AppColors.primaryColor,
                                width: 2) // Colored border
                            ),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final product = _orderedProducts[index];
                  return Container(
                    key: ValueKey(product.id),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                          color:
                              isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      // Rank Number
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryColor,
                        radius: 14,
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      title: Row(
                        children: [
                          // Product Image
                          Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsetsDirectional.only(end: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!),
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[50],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.contain, // Changed to contain
                                placeholder: (context, url) => Center(
                                    child: Icon(Icons.medication,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey)),
                                errorWidget: (context, url, error) => Center(
                                    child: Icon(Icons.error_outline,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey)),
                              ),
                            ),
                          ),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.company ?? "Unknown Co.",
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8, // Increased spacing
                                  runSpacing: 4,
                                  children: [
                                    if (product.package != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: Text(product.package!,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue)),
                                      ),
                                    if (product.activePrinciple != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color:
                                                Colors.green.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: Text(product.activePrinciple!,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.green)),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      // subtitle: Text(
                      //   product.company ?? "Unknown Company",
                      //   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      // ),
                      trailing: Icon(Icons.drag_handle,
                          color: theme.iconTheme.color?.withOpacity(0.5)),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      widget.rankingService.dismissForLater(widget.challenge);
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("لاحقاً"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.rankingService
                          .submitRanking(widget.challenge, _orderedProducts);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text("شكراً لمشاركتك! تم تسجيل الترتيب."),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "تأكيد الترتيب",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
