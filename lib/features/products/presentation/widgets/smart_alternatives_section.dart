// ignore_for_file: unused_local_variable

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/products/application/product_alternatives_provider.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/products/presentation/screens/smart_alternatives_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;

class SmartAlternativesSection extends StatefulWidget {
  const SmartAlternativesSection({
    super.key,
    required this.product,
    required this.onProductTap,
  });

  final ProductModel product;
  final Function(ProductModel) onProductTap;

  @override
  State<SmartAlternativesSection> createState() => _SmartAlternativesSectionState();
}

class _SmartAlternativesSectionState extends State<SmartAlternativesSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Use Consumer here to listen to the provider
    return Consumer(
      builder: (context, ref, child) {
        final alternativesAsync = ref.watch(productAlternativesProvider(widget.product));
        final isAr = Localizations.localeOf(context).languageCode == 'ar';

        // Manual Translations
        final String titleText = isAr ? 'البدائل  المتاحة' : 'Smart Alternatives';
        final String optionsText = isAr ? 'خيارات' : 'options';
        final String saveText = isAr ? 'وفر' : 'Save';
        final String currencyText = isAr ? 'ج.م' : 'LE';
        final String seeMoreText = isAr ? 'عرض الكل' : 'See All';
        final String moreCountText = isAr ? 'بديل آخر' : 'more';

        return alternativesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (alternatives) {
            if (alternatives.isEmpty) return const SizedBox.shrink();

            // Limit display to first 2 items, 3rd will be "See More" if total >= 3
            final int displayLimit = 2;
            final bool hasMore = alternatives.length >= 3;
            final int displayedCount = hasMore ? displayLimit : alternatives.length;
            final int itemCount = hasMore ? displayedCount + 1 : displayedCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // === Title Badge (Clickable) ===
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Shrink to fit content
                      children: [
                        Icon(
                          Icons.auto_awesome, 
                          color: Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          titleText,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? const Color.fromARGB(255, 240, 240, 241)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          if (Theme.of(context).brightness == Brightness.light)
                            BoxShadow(
                              color: const Color.fromARGB(255, 251, 250, 250).withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Text(
                        '${alternatives.length}', 
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.light
                              ? Theme.of(context).colorScheme.primary
                              : const Color.fromARGB(255, 249, 248, 248),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // === Expandable List Section ===
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity), // Collapsed state (empty)
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      height: 155,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: itemCount,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          // === "See More" Card ===
                          if (hasMore && index == displayedCount) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => SmartAlternativesScreen(
                                      originalProduct: widget.product,
                                      alternatives: alternatives,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 110,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isAr ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      seeMoreText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+${alternatives.length - displayLimit} $moreCountText',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                                                // === Product Card ===
                                                final alt = alternatives[index];
                                                final double originalPrice = widget.product.price ?? 0.0;
                                                final double altPrice = alt.price ?? 0.0;
                                                
                                                Color borderColor = Theme.of(context).dividerColor;
                                                double borderWidth = 1.0;
                                                final savings = originalPrice > altPrice ? originalPrice - altPrice : 0.0;
                          
                                                if (altPrice < originalPrice && originalPrice > 0) {
                                                  borderColor = Colors.green.withOpacity(0.5);
                                                  borderWidth = 1.5;
                                                } else if (altPrice > originalPrice && originalPrice > 0) {
                                                  borderColor = Colors.red.withOpacity(0.3);
                                                  borderWidth = 1.0;
                                                }
                          
                                                return GestureDetector(
                                                  onTap: () => widget.onProductTap(alt),
                                                  child: Container(
                                                    width: 110,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).cardColor,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: borderColor,
                                                        width: borderWidth,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.05),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Stack(
                                                            children: [
                                                              ClipRRect(
                                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                                                child: Container(
                                                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                                                  width: double.infinity,
                                                                  padding: const EdgeInsets.all(4),
                                                                  child: CachedNetworkImage(
                                                                    imageUrl: alt.imageUrl,
                                                                    fit: BoxFit.contain,
                                                                    placeholder: (context, url) => const Center(
                                                                      child: SizedBox(
                                                                        width: 15, height: 15, 
                                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                                      ),
                                                                    ),
                                                                    errorWidget: (context, url, error) => Icon(
                                                                      Icons.broken_image_outlined,
                                                                      size: 20,
                                                                      color: Colors.grey[400],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              if (savings > 0)
                                                                Positioned(
                                                                  top: 4,
                                                                  right: 4,
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.green,
                                                                      borderRadius: BorderRadius.circular(4),
                                                                    ),
                                                                    child: Text(
                                                                      '${isAr ? 'وفر' : 'Save'} ${NumberFormatter.formatCompact(savings)} $currencyText',
                                                                      style: const TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 9,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(8.0),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                              children: [
                                                                Text(
                                                                  alt.name,
                                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                    fontWeight: FontWeight.bold,
                                                                    height: 1.1,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                if (alt.selectedPackage != null && alt.selectedPackage!.isNotEmpty)
                                                                  Directionality(
                                                                    textDirection: ui.TextDirection.ltr,
                                                                    child: Text(
                                                                      alt.selectedPackage!,
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                Text(
                                                                  '${NumberFormatter.formatCompact(alt.price ?? 0)} $currencyText',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    color: savings > 0 
                                                                        ? Colors.green.shade700 
                                                                        : (altPrice > originalPrice ? Colors.red.shade700 : Theme.of(context).colorScheme.primary),
                                                                    fontWeight: FontWeight.w800,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );                        },
                      ),
                    ),
                  ),
                  crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
                
                const SizedBox(height: 10),
              ],
            );
          },
        );
      },
    );
  }
}