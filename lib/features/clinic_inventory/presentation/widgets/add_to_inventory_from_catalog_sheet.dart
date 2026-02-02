import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../../../products/domain/product_model.dart';
import '../../data/services/clinic_inventory_service.dart';

/// Sheet لإضافة منتج من الكتالوج إلى الجرد
class AddToInventoryFromCatalogSheet extends ConsumerStatefulWidget {
  final ProductModel product;
  final String? selectedPackage;

  const AddToInventoryFromCatalogSheet({
    super.key,
    required this.product,
    this.selectedPackage,
  });

  static Future<bool?> show(BuildContext context, ProductModel product,
      [String? package]) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToInventoryFromCatalogSheet(
          product: product, selectedPackage: package),
    );
  }

  @override
  ConsumerState<AddToInventoryFromCatalogSheet> createState() =>
      _AddToInventoryFromCatalogSheetState();
}

class _AddToInventoryFromCatalogSheetState
    extends ConsumerState<AddToInventoryFromCatalogSheet> {
  final _quantityCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _unitSizeCtrl = TextEditingController(text: '1');
  final _minStockCtrl = TextEditingController(text: '5');

  String _unitType = 'ml';
  DateTime? _expiryDate;
  bool _isSaving = false;

  String get _package =>
      widget.selectedPackage ??
      widget.product.selectedPackage ??
      widget.product.package ??
      '';

  String _packageType = 'bottle';

  @override
  void initState() {
    super.initState();
    _parseUnitInfo();
    _extractPackageType();
  }

  void _extractPackageType() {
    final pkg = _package.toLowerCase();

    if (pkg.contains('bottle') || pkg.contains('zogaga')) {
      _packageType = 'bottle';
    } else if (pkg.contains('vial')) {
      _packageType = 'vial';
    } else if (pkg.contains('amp')) {
      _packageType = 'ampoule';
    } else if (pkg.contains('tab') || pkg.contains('strip')) {
      _packageType = 'box'; // Usually tablets come in boxes
    } else if (pkg.contains('tube')) {
      _packageType = 'tube';
    } else if (pkg.contains('sachet')) {
      _packageType = 'sachet';
    } else {
      _packageType = 'bottle';
    }
  }

  /// استخراج بيانات الوحدة تلقائياً
  void _parseUnitInfo() {
    final pkg = _package;
    if (pkg.isEmpty) return;

    // 1. استخراج الرقم
    final numRegex = RegExp(r'(\d+(?:\.\d+)?)');
    final numMatch = numRegex.firstMatch(pkg);
    if (numMatch != null) {
      _unitSizeCtrl.text = numMatch.group(1)!;
    }

    // 2. استخراج النوع
    String lower = pkg.toLowerCase();

    if (lower.contains('ml')) {
      _unitType = 'ml';
    } else if (lower.contains('gm') || lower.contains('g')) {
      _unitType = 'gram';
    } else if (lower.contains('l')) {
      _unitType = 'ml';
    } else if (lower.contains('tab') || lower.contains('cap')) {
      _unitType = 'tablet';
    } else if (lower.contains('amp')) {
      _unitType = 'ampoule';
    } else if (lower.contains('vial')) {
      _unitType = 'vial';
    }
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _unitSizeCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final date = await showMonthPicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date != null) setState(() => _expiryDate = date);
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_quantityCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final unitSize = int.tryParse(_unitSizeCtrl.text) ?? 1;
    final minStock = int.tryParse(_minStockCtrl.text) ?? 5;

    if (quantity <= 0 || price <= 0) {
      final isArabic = context.locale.languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isArabic
                ? 'الرجاء إدخال الكمية والسعر'
                : 'Enter quantity & price'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(clinicInventoryServiceProvider);
      await service.addInventoryItem(
        productName: widget.product.name,
        package: _package,
        packageType: _packageType,
        company: widget.product.company,
        imageUrl: widget.product.imageUrl,
        quantity: quantity,
        purchasePrice: price,
        unitType: _unitType,
        unitSize: unitSize.toDouble(),
        expiryDate: _expiryDate,
        minStock: minStock,
      );

      ref.invalidate(clinicInventoryListProvider);
      ref.invalidate(clinicInventoryStatsProvider);

      if (mounted) {
        final isArabic = context.locale.languageCode == 'ar';
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(isArabic
                      ? 'تمت إضافة ${widget.product.name} للجرد'
                      : 'Added ${widget.product.name} successfully')),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // المقبض
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // معلومات المنتج
            _buildProductHeader(theme, cs),
            const SizedBox(height: 20),

            // الكمية والسعر
            Text(isArabic ? 'معلومات الشراء' : 'Purchase Info',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: isArabic ? 'العدد' : 'Count',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Box-icon.png',
                        width: 20,
                        height: 20,
                        color: cs.onSurface.withOpacity(0.6),
                        placeholder: (context, url) =>
                            const Icon(Icons.inventory_2_outlined),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.inventory_2_outlined),
                      ),
                    )),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: isArabic ? 'سعر العلبة' : 'Unit Price',
                    suffixText: isArabic ? 'ج' : 'EGP',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Money-Bill-icon.png',
                        width: 20,
                        height: 20,
                        color: cs.onSurface.withOpacity(0.6),
                        placeholder: (context, url) =>
                            const Icon(Icons.attach_money),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.attach_money),
                      ),
                    )),
              )),
            ]),
            const SizedBox(height: 16),

            // إعدادات الوحدات (للبيع الجزئي)
            Text(isArabic ? 'إعدادات البيع الجزئي' : 'Partial Sale Settings',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            Text(
                isArabic
                    ? 'اختياري - لبيع كميات جزئية من العلبة'
                    : 'Optional - For partial sales',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurface.withOpacity(0.6))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _unitSizeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: isArabic ? 'حجم الوحدة' : 'Unit Size',
                    hintText: isArabic ? 'مثال: 100' : 'Ex: 100'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildUnitTypeDropdown(cs, isArabic)),
            ]),
            const SizedBox(height: 16),

            // تاريخ الصلاحية والحد الأدنى
            Row(children: [
              Expanded(child: _buildExpiryDateField(theme, cs, isArabic)),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                controller: _minStockCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: isArabic ? 'الحد الأدنى' : 'Min Stock',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Triangle-Exclamation-icon.png',
                        width: 20,
                        height: 20,
                        color: cs.onSurface.withOpacity(0.6),
                        placeholder: (context, url) =>
                            const Icon(Icons.warning_amber_outlined),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.warning_amber_outlined),
                      ),
                    )),
              )),
            ]),
            const SizedBox(height: 24),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: !_isSaving ? _save : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Plus-icon.png',
                        width: 24,
                        height: 24,
                        color: Colors.white,
                        placeholder: (context, url) =>
                            const Icon(Icons.add_rounded, color: Colors.white),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                label: Text(_isSaving
                    ? (isArabic ? 'جاري الإضافة...' : 'Adding...')
                    : (isArabic ? 'إضافة للجرد' : 'Add')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (widget.product.imageUrl.isNotEmpty) ...[
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                    imageUrl: widget.product.imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(Icons.medication)),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.product.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_package,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.bold)),
                ),
                if (widget.product.company != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.product.company!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurface.withOpacity(0.6))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitTypeDropdown(ColorScheme cs, bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _unitType,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'ml', child: Text(isArabic ? 'مل' : 'ml')),
            DropdownMenuItem(
                value: 'gram', child: Text(isArabic ? 'جرام' : 'g')),
            DropdownMenuItem(
                value: 'piece', child: Text(isArabic ? 'وحدة' : 'unit')),
          ],
          onChanged: (v) => setState(() => _unitType = v ?? 'piece'),
        ),
      ),
    );
  }

  Widget _buildExpiryDateField(ThemeData theme, ColorScheme cs, bool isArabic) {
    return InkWell(
      onTap: _selectExpiryDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CachedNetworkImage(
                imageUrl:
                    'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Calendar-Days-icon.png',
                width: 20,
                height: 20,
                color: cs.onSurface.withOpacity(0.6),
                placeholder: (context, url) => Icon(Icons.calendar_month,
                    color: cs.onSurface.withOpacity(0.6), size: 20),
                errorWidget: (context, url, error) => Icon(Icons.calendar_month,
                    color: cs.onSurface.withOpacity(0.6), size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _expiryDate != null
                    ? '${_expiryDate!.month}/${_expiryDate!.year}'
                    : (isArabic ? 'تاريخ الصلاحية' : 'Expiry'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _expiryDate != null
                      ? cs.onSurface
                      : cs.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
