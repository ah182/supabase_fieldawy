import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
// ignore: unused_import
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
  List<ProductModel> suggestions; // List of similar products

  ExtractedItem({
    required this.name,
    required this.package,
    required this.price,
    this.isSelected = true,
    this.matchedProductId,
    this.imageUrl,
    this.isOcrMatch = false,
    this.matchedProduct,
    this.suggestions = const [],
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
      
      // قائمة لتخزين كل النتائج المحتملة مع درجاتها
      final List<Map<String, dynamic>> potentialMatches = [];

      // 1. البحث في الكتالوج الرئيسي
      for (final product in mainCatalog) {
        final score = _calculateSimilarity(query, product.name.toLowerCase());
        if (score > 0.3) { // تخزين أي تطابق فوق 30%
          potentialMatches.add({
            'product': product,
            'score': score,
            'isOcr': false,
          });
        }
      }

      // 2. البحث في كتالوج OCR
      for (final product in ocrCatalog) {
        final score = _calculateSimilarity(query, product.name.toLowerCase());
        if (score > 0.3) {
          potentialMatches.add({
            'product': product,
            'score': score,
            'isOcr': true,
          });
        }
      }

      // ترتيب النتائج حسب التشابه
      potentialMatches.sort((a, b) => b['score'].compareTo(a['score']));

      if (potentialMatches.isNotEmpty) {
        final bestMatch = potentialMatches.first;
        // إذا كان التطابق قوياً جداً، نختاره تلقائياً
        if (bestMatch['score'] > 0.6) { // عتبة القبول التلقائي
          item.matchedProduct = bestMatch['product'];
          item.matchedProductId = bestMatch['product'].id;
          item.imageUrl = bestMatch['product'].imageUrl;
          item.name = bestMatch['product'].name; // <--- تحديث الاسم تلقائياً للاسم الرسمي
          item.isOcrMatch = bestMatch['isOcr'];
          item.isSelected = true;
        } else {
          // إذا كان التطابق ضعيفاً، نضعه في الاقتراحات ولا نختار تلقائياً
          item.isSelected = false;
        }

        // تعبئة قائمة الاقتراحات (أفضل 5 نتائج)
        item.suggestions = potentialMatches
            .take(5)
            .map((m) => m['product'] as ProductModel)
            .toList();
      } else {
        item.isSelected = false;
      }
    }

    // Update the UI once all matching is complete
    if (mounted) {
      setState(() {
        _isMatching = false;
      });
      _showVerificationWarning();
    }
  }

  // دالة بسيطة لحساب التشابه (Levenshtein-based approximate)
  // تعيد قيمة بين 0.0 (مختلف تماماً) و 1.0 (متطابق تماماً)
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // تحسين: إذا كان أحدهما يحتوي على الآخر
    if (s1.contains(s2) || s2.contains(s1)) {
      // نعطي وزن أكبر للطول النسبي
      double ratio = s1.length < s2.length 
          ? s1.length / s2.length 
          : s2.length / s1.length;
      return 0.5 + (0.5 * ratio); // نتيجة بين 0.5 و 1.0
    }

    int matches = 0;
    int length = s1.length > s2.length ? s1.length : s2.length;
    int minLength = s1.length < s2.length ? s1.length : s2.length;

    for (int i = 0; i < minLength; i++) {
      if (s1[i] == s2[i]) matches++;
    }

    return matches / length;
  }

  void _showVerificationWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'مراجعة البيانات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'يرجى التأكد من صحة البيانات المستخرجة قبل اعتمادها، خاصة:',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildWarningItem(Icons.medication_outlined, 'اسم المنتج ومطابقته', Colors.blue),
            const SizedBox(height: 12),
            _buildWarningItem(Icons.attach_money, 'سعر المنتج', Colors.green),
            const SizedBox(height: 12),
            _buildWarningItem(FontAwesomeIcons.boxOpen, 'حجم ونوع العبوة', Colors.purple),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('فهمت، سأقوم بالمراجعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
                  // 🔑 مفتاح يعتمد على الاسم والمعرف لضمان إعادة البناء عند التغيير
                  key: ValueKey('${item.name}_${item.matchedProductId ?? "none"}'), 
                  item: item,
                  onSelectionChanged: (isSelected) {
                    setState(() {
                      item.isSelected = isSelected;
                    });
                  },
                  onManualMatch: (ProductModel selectedProduct) {
                    setState(() {
                      item.matchedProduct = selectedProduct;
                      item.matchedProductId = selectedProduct.id;
                      item.imageUrl = selectedProduct.imageUrl;
                      item.name = selectedProduct.name; // تحديث الاسم
                      item.isSelected = true;
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

class _ReviewItemCard extends StatefulWidget {
  final ExtractedItem item;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<ProductModel> onManualMatch;

  const _ReviewItemCard({
    super.key,
    required this.item,
    required this.onSelectionChanged,
    required this.onManualMatch,
  });

  @override
  State<_ReviewItemCard> createState() => _ReviewItemCardState();
}

class _ReviewItemCardState extends State<_ReviewItemCard> {
  late TextEditingController _nameController;
  late TextEditingController _packageDescController;
  late TextEditingController _priceController;
  
  String? _selectedPackageType;

  final List<String> _packageTypes = [
    'bottle',
    'vial',
    'tab',
    'amp',
    'sachet',
    'strip',
    'cream',
    'gel',
    'spray',
    'drops',
    'syringe',
    'powder',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _priceController = TextEditingController(text: widget.item.price.toString());
    
    // Try to parse package string into type and description
    _parsePackage(widget.item.package);
  }

  void _parsePackage(String packageStr) {
    String lower = packageStr.toLowerCase();
    String? foundType;
    
    // Find matching type
    for (var type in _packageTypes) {
      if (lower.contains(type)) {
        foundType = type;
        break;
      }
    }
    
    // Default to first type if not found, or keep null if strict
    _selectedPackageType = foundType ?? _packageTypes.first;
    
    // Remove type from description to avoid duplication in UI
    String desc = packageStr;
    if (foundType != null) {
      desc = desc.replaceAll(RegExp(foundType, caseSensitive: false), '').trim();
    }
    _packageDescController = TextEditingController(text: desc);
  }

  void _updateItemPackage() {
    if (_selectedPackageType != null) {
      widget.item.package = '${_packageDescController.text} $_selectedPackageType'.trim();
    } else {
      widget.item.package = _packageDescController.text;
    }
  }

  @override
  void didUpdateWidget(covariant _ReviewItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.name != _nameController.text) {
      _nameController.text = widget.item.name;
    }
    
    // If package changed externally (e.g. manual match), re-parse
    if (widget.item.package != '${_packageDescController.text} $_selectedPackageType'.trim()) {
       if (widget.item.package != oldWidget.item.package) {
          _parsePackage(widget.item.package);
       }
    }

    if (widget.item.price.toString() != _priceController.text) {
       if (double.tryParse(_priceController.text) != widget.item.price) {
          _priceController.text = widget.item.price.toString();
       }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageDescController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canBeSelected = widget.item.matchedProductId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: canBeSelected
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.item.isSelected && canBeSelected
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: widget.item.isSelected && canBeSelected ? 2 : 1,
        ),
        boxShadow: [
          if (widget.item.isSelected && canBeSelected)
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
              color: widget.item.isSelected && canBeSelected
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
                    value: widget.item.isSelected,
                    onChanged: canBeSelected
                        ? (value) {
                            widget.onSelectionChanged(value ?? false);
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
                        widget.item.name,
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
                  controller: _nameController,
                  label: 'Product Name',
                  icon: Icons.medication,
                  onChanged: (value) => widget.item.name = value,
                ),
                const SizedBox(height: 12),
                // Package Row (Type + Description)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 40,
                      child: DropdownButtonFormField<String>(
                        value: _selectedPackageType,
                        isExpanded: true, // Important to prevent overflow inside dropdown
                        decoration: InputDecoration(
                          labelText: 'Type',
                          prefixIcon: Icon(FontAwesomeIcons.boxOpen, size: 16, color: Colors.grey[600]),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        ),
                        items: _packageTypes.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedPackageType = val;
                            _updateItemPackage();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 50,
                      child: _buildTextField(
                        context,
                        controller: _packageDescController,
                        label: 'package', 
                        icon: Icons.description,
                        onChanged: (value) => _updateItemPackage(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  context,
                  controller: _priceController,
                  label: 'Price (EGP)',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      widget.item.price = double.tryParse(value) ?? 0.0,
                ),
              ],
            ),
          ),
          // Match result
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildMatchResult(context, widget.item),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
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

  void _openManualSearchDialog(BuildContext context, WidgetRef ref) async {
    final mainCatalog = await ref.read(productsProvider.future);
    final ocrCatalog = await ref.read(ocrProductsProvider.future);
    
    // دمج الكتالوجين للبحث
    final allProducts = [...mainCatalog, ...ocrCatalog];

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // فلترة المنتجات
            final filtered = query.isEmpty 
                ? [] 
                : allProducts.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).take(50).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن اسم المنتج الصحيح...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          query = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty && query.isNotEmpty
                          ? const Center(child: Text('لا توجد نتائج'))
                          : filtered.isEmpty && query.isEmpty 
                              ? const Center(child: Text('ابدأ الكتابة للبحث'))
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, index) {
                                    final product = filtered[index];
                                    return ListTile(
                                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(product.company ?? ''),
                                      leading: product.imageUrl.isNotEmpty
                                          ? CircleAvatar(backgroundImage: NetworkImage(product.imageUrl))
                                          : const CircleAvatar(child: Icon(Icons.medication)),
                                      onTap: () {
                                        widget.onManualMatch(product);
                                        Navigator.pop(context);
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMatchResult(BuildContext context, ExtractedItem item) {
    // نحتاج للـ ref هنا لاستدعاء البحث
    return Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);

        if (item.matchedProduct == null) {
          // حالة عدم التطابق
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50]!.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... الكود السابق للقائمة المنسدلة إذا وجدت اقتراحات ...
                if (item.suggestions.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text('اقتراحات:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductModel>(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.orange.shade200)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    hint: const Text('اختر منتج مشابه...'),
                    items: item.suggestions.map((suggestion) {
                      return DropdownMenuItem<ProductModel>(
                        value: suggestion,
                        child: Text(suggestion.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (ProductModel? newValue) {
                      if (newValue != null) widget.onManualMatch(newValue);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Center(child: Text("- أو -", style: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 8),
                ] else ...[
                   Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('لم يتم العثور على منتج مطابق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // زر البحث اليدوي (الحل الجذري)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openManualSearchDialog(context, ref),
                    icon: const Icon(Icons.search),
                    label: const Text('بحث يدوي في الكتالوج'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      side: BorderSide(color: Colors.orange[800]!),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // حالة التطابق (Match Found)
        final bool isOcr = item.isOcrMatch;
        final Color chipColor = isOcr ? theme.colorScheme.secondaryContainer : theme.colorScheme.primaryContainer;
        final Color chipTextColor = isOcr ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onPrimaryContainer;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green[100]!.withOpacity(0.5), Colors.green[50]!.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('تم التطابق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(isOcr ? 'OCR' : 'Main', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chipTextColor)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // زر لتغيير المنتج حتى لو كان مطابقاً
              InkWell(
                onTap: () => _openManualSearchDialog(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl ?? '',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) => const Icon(Icons.medication),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.matchedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('اضغط للتغيير', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
