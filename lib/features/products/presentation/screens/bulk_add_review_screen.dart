import 'package:cached_network_image/cached_network_image.dart';

import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';

// A simple model to hold the extracted data
class ExtractedItem {
  String name;
  String package;
  double price;
  bool isSelected;
  String? matchedProductId;
  String? imageUrl;
  bool isOcrMatch;
  ProductModel? matchedProduct; // Store the whole matched product

  ExtractedItem({
    required this.name,
    required this.package,
    required this.price,
    this.isSelected = true,
    this.matchedProductId,
    this.imageUrl,
    this.isOcrMatch = false,
    this.matchedProduct,
  });
}

class BulkAddReviewScreen extends ConsumerStatefulWidget {
  final List<ExtractedItem> extractedItems;

  const BulkAddReviewScreen({super.key, required this.extractedItems});

  @override
  ConsumerState<BulkAddReviewScreen> createState() =>
      _BulkAddReviewScreenState();
}

class _BulkAddReviewScreenState extends ConsumerState<BulkAddReviewScreen> {
  late List<ExtractedItem> _items;
  bool _isSaving = false;
  bool _isMatching = true; // New state for initial matching process

  @override
  void initState() {
    super.initState();
    _items = widget.extractedItems;
    // Perform all matching logic at once when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _performAllMatching());
  }

  Future<void> _performAllMatching() async {
    final mainCatalog = await ref.read(productsProvider.future);
    final ocrCatalog = await ref.read(ocrProductsProvider.future);

    for (final item in _items) {
      final query = item.name.toLowerCase();
      ProductModel? bestMatch;
      double bestScore = 0.0;
      bool isOcr = false;

      // Search Main Catalog
      for (final product in mainCatalog) {
        final score = _calculateScore(query, product.name);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = product;
          isOcr = false;
        }
      }

      // Search OCR Catalog
      for (final product in ocrCatalog) {
        final score = _calculateScore(query, product.name);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = product;
          isOcr = true;
        }
      }

      if (bestScore > 0.4) { // Acceptance threshold
        item.matchedProduct = bestMatch;
        item.matchedProductId = bestMatch!.id;
        item.imageUrl = bestMatch.imageUrl;
        item.isOcrMatch = isOcr;
      } else {
        item.isSelected = false; // Deselect not-found items
      }
    }

    // Update the UI once all matching is complete
    if (mounted) {
      setState(() {
        _isMatching = false;
      });
    }
  }

  double _calculateScore(String query, String candidate) {
    final lowerCandidate = candidate.toLowerCase();
    if (lowerCandidate == query) return 1.0;
    if (lowerCandidate.contains(query)) return 0.8;
    if (query.contains(lowerCandidate)) return 0.5;
    return 0.0;
  }

  Future<void> _saveConfirmedItems() async {
    setState(() { _isSaving = true; });

    try {
      final user = await ref.read(userDataProvider.future);
      if (user == null || user.id.isEmpty) {
        throw Exception('User not authenticated');
      }

      final selectedItems = _items
          .where(
              (i) => i.isSelected && i.matchedProductId != null && i.price > 0)
          .toList();

      if (selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.white),
                SizedBox(width: 12),
                Text('No valid products selected to save.'),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      final mainCatalogItems = selectedItems.where((i) => !i.isOcrMatch).toList();
      final ocrCatalogItems = selectedItems.where((i) => i.isOcrMatch).toList();
      final repo = ref.read(productRepositoryProvider);

      if (mainCatalogItems.isNotEmpty) {
        final productsToAdd = {
          for (var item in mainCatalogItems)
            '${item.matchedProductId}_${item.package}': {'price': item.price}
        };
        await repo.addMultipleProductsToDistributorCatalog(
          distributorId: user.id,
          distributorName: user.displayName ?? '',
          productsToAdd: productsToAdd,
        );
      }

      if (ocrCatalogItems.isNotEmpty) {
        final ocrProductsToAdd = ocrCatalogItems
            .map((item) => {
                  'ocrProductId': item.matchedProductId!,
                  'price': item.price,
                  'expiration_date': null,
                })
            .toList();
        await repo.addMultipleDistributorOcrProducts(
          distributorId: user.id,
          distributorName: user.displayName ?? '',
          ocrProducts: ocrProductsToAdd,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Successfully added ${selectedItems.length} items.'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to save items: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _items.where((i) => i.isSelected && i.matchedProductId != null).length;
    final totalMatchable = _items.where((i) => i.matchedProductId != null).length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review & Confirm',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isMatching)
              Text(
                '$selectedCount of $totalMatchable selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton.outlined(
              icon: const Icon(Icons.select_all, size: 20),
              onPressed: () {
                setState(() {
                  for (var item in _items) {
                    if (item.matchedProductId != null) item.isSelected = true;
                  }
                });
              },
              tooltip: 'Select All Found',
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton.outlined(
              icon: const Icon(Icons.deselect, size: 20),
              onPressed: () {
                setState(() {
                  for (var item in _items) {
                    item.isSelected = false;
                  }
                });
              },
              tooltip: 'Deselect All',
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isMatching)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Matching products...'),
                ],
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 100,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _ReviewItemCard(
                  key: ValueKey(item), // Use stable object key
                  item: item,
                  onSelectionChanged: (isSelected) {
                    setState(() {
                      item.isSelected = isSelected;
                    });
                  },
                );
              },
            ),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Saving products...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isMatching
          ? null
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSaving
                        ? [Colors.grey[400]!, Colors.grey[600]!]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!_isSaving)
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSaving ? null : _saveConfirmedItems,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSaving)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          _isSaving ? 'Saving...' : 'Confirm & Add ($selectedCount)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  final ExtractedItem item;
  final ValueChanged<bool> onSelectionChanged;

  const _ReviewItemCard(
      {super.key, required this.item, required this.onSelectionChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canBeSelected = item.matchedProductId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: canBeSelected
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSelected && canBeSelected
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: item.isSelected && canBeSelected ? 2 : 1,
        ),
        boxShadow: [
          if (item.isSelected && canBeSelected)
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          // Header with checkbox
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.isSelected && canBeSelected
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                  : null,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: item.isSelected,
                    onChanged: canBeSelected
                        ? (value) {
                            onSelectionChanged(value ?? false);
                          }
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extracted Product',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Form fields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(
                  context,
                  label: 'Product Name',
                  icon: Icons.medication,
                  initialValue: item.name,
                  onChanged: (value) => item.name = value,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  context,
                  label: 'Package',
                  icon: Icons.inventory_2_outlined,
                  initialValue: item.package,
                  onChanged: (value) => item.package = value,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  context,
                  label: 'Price (EGP)',
                  icon: Icons.attach_money,
                  initialValue: item.price.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      item.price = double.tryParse(value) ?? 0.0,
                ),
              ],
            ),
          ),
          // Match result
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildMatchResult(context, item),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String initialValue,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }

  Widget _buildMatchResult(BuildContext context, ExtractedItem item) {
    final theme = Theme.of(context);

    if (item.matchedProduct == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange[100]!.withOpacity(0.5),
              Colors.orange[50]!.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Match Found',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This item will be ignored during save.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bool isOcr = item.isOcrMatch;
    final Color chipBackgroundColor = isOcr
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.primaryContainer;
    final Color chipForegroundColor = isOcr
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[100]!.withOpacity(0.5),
            Colors.green[50]!.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match Found',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Product matched in catalog',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: chipBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: chipForegroundColor.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  isOcr ? 'OCR' : 'Main',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: chipForegroundColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  AddFromCatalogScreen.showProductDetailDialog(context, item.matchedProduct!);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl ?? '',
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) => const Icon(
                        Icons.medication,
                        size: 32,
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
                      'Matched Product:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.matchedProduct!.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
