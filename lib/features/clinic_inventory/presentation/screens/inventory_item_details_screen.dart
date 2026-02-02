import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/clinic_inventory_item.dart';
import '../../data/models/inventory_transaction.dart';
import '../../data/services/clinic_inventory_service.dart';
import 'add_to_inventory_screen.dart';

/// شاشة تفاصيل عنصر الجرد
class InventoryItemDetailsScreen extends ConsumerStatefulWidget {
  final ClinicInventoryItem item;

  const InventoryItemDetailsScreen({super.key, required this.item});

  @override
  ConsumerState<InventoryItemDetailsScreen> createState() =>
      _InventoryItemDetailsScreenState();
}

class _InventoryItemDetailsScreenState
    extends ConsumerState<InventoryItemDetailsScreen> {
  late ClinicInventoryItem _item;
  List<InventoryTransaction> _transactions = [];
  bool _loadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final service = ref.read(clinicInventoryServiceProvider);
      final transactions =
          await service.getRecentTransactions(inventoryId: _item.id, limit: 10);
      if (mounted)
        setState(() {
          _transactions = transactions;
          _loadingTransactions = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loadingTransactions = false);
    }
  }

  void _showSellDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SellItemSheet(
          item: _item,
          onSold: (u) {
            setState(() => _item = u);
            _loadTransactions();
          }),
    );
  }

  void _showAddQuantityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddQuantitySheet(
          item: _item,
          onAdded: (u) {
            setState(() => _item = u);
            _loadTransactions();
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(theme, cs),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuantitySection(theme, cs),
                  const SizedBox(height: 20),
                  _buildPriceSection(theme, cs),
                  const SizedBox(height: 20),
                  _buildActionsSection(cs),
                  const SizedBox(height: 24),
                  _buildTransactionsSection(theme, cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, ColorScheme cs) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: cs.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary,
                cs.primary.withOpacity(0.8),
                cs.secondary.withOpacity(0.6)
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_item.productName,
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 2),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(_item.package,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white))),
                    if (_item.company != null) ...[
                      const SizedBox(width: 8),
                      Text(_item.company!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70))
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(12)),
          child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context))),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(12)),
          child: IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: () => _onEdit(),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
          child: IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
            onPressed: () => _onDelete(),
          ),
        ),
      ],
    );
  }

  void _onEdit() async {
    // الانتقال لشاشة التعديل
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddToInventoryScreen(itemToEdit: _item),
      ),
    );

    // إذا تم التعديل بنجاح (result == true)، نعيد تحميل البيانات أو نغلق الشاشة
    if (result == true) {
      if (!mounted) return;
      // نغلق الشاشة ليعود المستخدم للقائمة الرئيسية بالتحديث الجديد
      // أو يمكننا إعادة تحميل عنصر الجرد فقط إذا كانت الخدمة تدعم ذلك
      Navigator.pop(context);
    }
  }

  void _onDelete() async {
    final curContext = context;
    final isArabic = context.locale.languageCode == 'ar';
    // تأكيد الحذف
    final confirm = await showDialog<bool>(
      context: curContext,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف المنتج' : 'Delete Product'),
        content: Text(isArabic
            ? 'هل أنت متأكد من حذف "${_item.productName}" من الجرد؟\nلا يمكن التراجع عن هذا الإجراء.'
            : 'Are you sure you want to delete "${_item.productName}"?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final service = ref.read(clinicInventoryServiceProvider);
        await service.deleteInventoryItem(_item.id);

        if (mounted) {
          ScaffoldMessenger.of(curContext).showSnackBar(
            const SnackBar(
                content: Text('تم الحذف بنجاح / Deleted successfully'),
                backgroundColor: Colors.red),
          );
          Navigator.pop(curContext); // العودة للقائمة
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(curContext).showSnackBar(
            SnackBar(content: Text('خطأ في الحذف: $e / Error deleting')),
          );
        }
      }
    }
  }

  Widget _buildQuantitySection(ThemeData theme, ColorScheme cs) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.1))),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.inventory_outlined, color: cs.primary),
            const SizedBox(width: 8),
            Text(isArabic ? 'المخزون الحالي' : 'Current Stock',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            _buildStatusBadge(theme),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _infoCard(
                    theme,
                    _item.translatedPackageType,
                    '${_item.quantity}',
                    CachedNetworkImage(
                      imageUrl:
                          'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Boxes-Stacked-icon.png',
                      width: 20,
                      height: 20,
                      color: Colors.blue,
                      placeholder: (context, url) => const Icon(
                          Icons.inbox_outlined,
                          color: Colors.blue,
                          size: 20),
                      errorWidget: (context, url, error) => const Icon(
                          Icons.inbox_outlined,
                          color: Colors.blue,
                          size: 20),
                    ),
                    Colors.blue)),
            const SizedBox(width: 12),
            Expanded(
                child: _infoCard(
                    theme,
                    isArabic ? 'كمية جزئية' : 'Partial',
                    _item.partialQuantity > 0
                        ? '${_item.partialQuantity.toStringAsFixed(0)} ${_item.translatedUnitType}'
                        : '-',
                    CachedNetworkImage(
                      imageUrl:
                          'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Chart-Pie-icon.png',
                      width: 20,
                      height: 20,
                      color: Colors.orange,
                      placeholder: (context, url) => const Icon(
                          Icons.pie_chart_outline,
                          color: Colors.orange,
                          size: 20),
                      errorWidget: (context, url, error) => const Icon(
                          Icons.pie_chart_outline,
                          color: Colors.orange,
                          size: 20),
                    ),
                    Colors.orange)),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final isArabic = context.locale.languageCode == 'ar';
    final color = _item.stockStatus == StockStatus.adequate
        ? Colors.green
        : _item.stockStatus == StockStatus.low
            ? Colors.orange
            : Colors.red;
    final text = _item.stockStatus == StockStatus.adequate
        ? (isArabic ? 'كافي' : 'Good')
        : _item.stockStatus == StockStatus.low
            ? (isArabic ? 'منخفض' : 'Low')
            : _item.stockStatus == StockStatus.critical
                ? (isArabic ? 'حرج' : 'Critical')
                : (isArabic ? 'نفذ' : 'Out');
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold)));
  }

  Widget _infoCard(
      ThemeData theme, String label, String value, Widget icon, Color color) {
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          icon,
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6))),
        ]));
  }

  Widget _buildPriceSection(ThemeData theme, ColorScheme cs) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CachedNetworkImage(
            imageUrl:
                'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Tag-icon.png',
            width: 24,
            height: 24,
            color: cs.primary,
            placeholder: (context, url) =>
                Icon(Icons.attach_money, color: cs.primary),
            errorWidget: (context, url, error) =>
                Icon(Icons.attach_money, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Text(isArabic ? 'الأسعار' : 'Prices',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold))
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(isArabic ? 'سعر العلبة' : 'Box Price',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withOpacity(0.6))),
                Text('${_item.purchasePrice.toStringAsFixed(0)} ج',
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: cs.primary)),
              ])),
          if (_item.unitSize > 1)
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(isArabic ? 'سعر الوحدة' : 'Unit Price',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurface.withOpacity(0.6))),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                            text: '${_item.pricePerUnit.toStringAsFixed(2)} ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(
                            text: 'ج',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(
                            text: ' / ', style: TextStyle(color: Colors.grey)),
                        TextSpan(
                            text: _item.translatedUnitType,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    style: theme.textTheme.titleMedium,
                    textDirection:
                        ui.TextDirection.rtl, // Force RTL for the container
                  ),
                ])),
        ]),
      ]),
    );
  }

  Widget _buildActionsSection(ColorScheme cs) {
    final isArabic = context.locale.languageCode == 'ar';
    return Row(children: [
      Expanded(
          child: ElevatedButton.icon(
              onPressed:
                  _item.totalQuantityInUnits > 0 ? _showSellDialog : null,
              icon: CachedNetworkImage(
                imageUrl:
                    'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Cash-Register-icon.png',
                width: 20,
                height: 20,
                color: Colors.white,
                placeholder: (context, url) => const Icon(Icons.point_of_sale,
                    color: Colors.white, size: 20),
                errorWidget: (context, url, error) => const Icon(
                    Icons.point_of_sale,
                    color: Colors.white,
                    size: 20),
              ),
              label: Text(isArabic ? 'بيع' : 'Sell'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))))),
      const SizedBox(width: 12),
      Expanded(
          child: OutlinedButton.icon(
              onPressed: _showAddQuantityDialog,
              icon: CachedNetworkImage(
                imageUrl:
                    'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Plus-icon.png',
                width: 20,
                height: 20,
                color: cs.primary,
                placeholder: (context, url) =>
                    Icon(Icons.add_box_outlined, color: cs.primary, size: 20),
                errorWidget: (context, url, error) =>
                    Icon(Icons.add_box_outlined, color: cs.primary, size: 20),
              ),
              label: Text(isArabic ? 'إضافة' : 'Add'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))))),
    ]);
  }

  Widget _buildTransactionsSection(ThemeData theme, ColorScheme cs) {
    final isArabic = context.locale.languageCode == 'ar';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CachedNetworkImage(
          imageUrl:
              'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Clock-Rotate-Left-icon.png',
          width: 24,
          height: 24,
          color: cs.primary,
          placeholder: (context, url) => Icon(Icons.history, color: cs.primary),
          errorWidget: (context, url, error) =>
              Icon(Icons.history, color: cs.primary),
        ),
        const SizedBox(width: 8),
        Text(isArabic ? 'آخر العمليات' : 'Recent Transactions',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold))
      ]),
      const SizedBox(height: 12),
      if (_loadingTransactions)
        const Center(child: CircularProgressIndicator())
      else if (_transactions.isEmpty)
        Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(isArabic ? 'لا توجد عمليات' : 'No transactions',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurface.withOpacity(0.5)))))
      else
        ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _txCard(theme, cs, _transactions[i])),
    ]);
  }

  Widget _txCard(ThemeData theme, ColorScheme cs, InventoryTransaction tx) {
    final isArabic = context.locale.languageCode == 'ar';
    final isAdd = tx.transactionType == TransactionType.add;
    final color = isAdd ? Colors.blue : Colors.green;

    // تحديد اتجاه النص بناءً على الوحدة
    // إذا كانت الوحدة تحتوي على حروف إنجليزية (مثل ml, gm) نستخدم LTR للأرقام
    String unit = tx.unitSold ?? '';

    // إذا كانت الوحدة generic "piece" أو "box"، نستخدم نوع الوحدة المترجم من العنصر نفسه
    if (unit == 'piece') {
      unit = _item.translatedUnitType;
    } else if (unit == 'box') {
      unit = isArabic ? 'علبة' : 'Box';
    }

    // Build the quantity text first
    final quantityText = isAdd
        ? '${tx.boxesAdded} ${_item.translatedPackageType}'
        : '${tx.quantitySold.toStringAsFixed(0)} $unit';

    // Check if the final string contains Latin characters
    final isLatin = quantityText.contains(RegExp(r'[a-zA-Z]'));

    final sub = isAdd
        ? '${isArabic ? "تكلفة" : "Cost"}: ${tx.totalPurchaseCost?.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}'
        : '${isArabic ? "ربح" : "Profit"}: ${tx.profit?.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}';

    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: CachedNetworkImage(
                imageUrl: isAdd
                    ? 'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Box-Open-icon.png'
                    : 'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Cash-Register-icon.png',
                width: 18,
                height: 18,
                color: color,
                placeholder: (context, url) => Icon(
                    isAdd ? Icons.add_box : Icons.point_of_sale,
                    color: color,
                    size: 18),
                errorWidget: (context, url, error) => Icon(
                    isAdd ? Icons.add_box : Icons.point_of_sale,
                    color: color,
                    size: 18),
              )),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // العنوان مع ضبط الاتجاه
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAdd
                          ? (isArabic ? 'إضافة ' : 'Add ')
                          : (isArabic ? 'بيع ' : 'Sell '),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Directionality(
                      textDirection:
                          isLatin ? ui.TextDirection.ltr : ui.TextDirection.rtl,
                      child: Text(
                        quantityText,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(sub,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withOpacity(0.6))),
              ])),
          Text('${tx.transactionDate.day}/${tx.transactionDate.month}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
        ]));
  }
}

/// شيت البيع
class _SellItemSheet extends ConsumerStatefulWidget {
  final ClinicInventoryItem item;
  final ValueChanged<ClinicInventoryItem> onSold;
  const _SellItemSheet({required this.item, required this.onSold});
  @override
  ConsumerState<_SellItemSheet> createState() => _SellItemSheetState();
}

class _SellItemSheetState extends ConsumerState<_SellItemSheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  String _unit = 'box';
  bool _saving = false;

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;
  double get _sellPrice => double.tryParse(_priceCtrl.text) ?? 0;
  double get _cost => _unit == 'box'
      ? _qty * widget.item.purchasePrice
      : _qty * widget.item.pricePerUnit;
  double get _profit => _sellPrice - _cost;

  @override
  void initState() {
    super.initState();
    _unit = widget.item.unitSize > 1 ? widget.item.unitType : 'box';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _sell() async {
    if (_qty <= 0 || _sellPrice <= 0) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(clinicInventoryServiceProvider);
      final u = await svc.sellQuantity(
          inventoryId: widget.item.id,
          quantitySold: _qty,
          unitSold: _unit,
          sellingPrice: _sellPrice);
      if (mounted) {
        widget.onSold(u);
        Navigator.pop(context);
        final isArabic = context.locale.languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isArabic
                ? 'تم البيع • ربح: ${_profit.toStringAsFixed(0)} ج'
                : 'Sold • Profit: ${_profit.toStringAsFixed(0)} EGP'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: cs.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Cash-Register-icon.png',
                    width: 24,
                    height: 24,
                    color: Colors.green,
                    placeholder: (context, url) =>
                        const Icon(Icons.point_of_sale, color: Colors.green),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.point_of_sale, color: Colors.green),
                  )),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        isArabic
                            ? 'بيع ${widget.item.productName}'
                            : 'Sell ${widget.item.productName}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        isArabic
                            ? 'المتاح: ${widget.item.quantity} علبة'
                            : 'Available: ${widget.item.quantity} boxes',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurface.withOpacity(0.6))),
                  ]))
            ]),
            const SizedBox(height: 20),
            if (widget.item.unitSize > 1)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(children: [
                    Expanded(
                        child:
                            _unitBtn(widget.item.translatedPackageType, 'box')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _unitBtn('1 ${widget.item.translatedUnitType}',
                            widget.item.unitType)),
                  ])),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: isArabic ? 'الكمية' : 'Quantity',
                          suffixText: _unit == 'box'
                              ? (isArabic ? 'علبة' : 'Box')
                              : widget.item.translatedUnitType))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: isArabic ? 'سعر البيع' : 'Selling Price',
                          suffixText: isArabic ? 'ج' : 'EGP')))
            ]),
            const SizedBox(height: 16),
            if (_qty > 0 && _sellPrice > 0)
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _profit >= 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isArabic ? 'الربح:' : 'Profit:',
                            style: theme.textTheme.bodyMedium),
                        Text(
                            '${_profit.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    _profit >= 0 ? Colors.green : Colors.red))
                      ])),
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                    onPressed:
                        _qty > 0 && _sellPrice > 0 && !_saving ? _sell : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : CachedNetworkImage(
                            imageUrl:
                                'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Check-icon.png',
                            width: 24,
                            height: 24,
                            color: Colors.white,
                            placeholder: (context, url) =>
                                const Icon(Icons.check, color: Colors.white),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.check, color: Colors.white),
                          ),
                    label: Text(_saving
                        ? (isArabic ? 'جاري...' : 'Saving...')
                        : (isArabic ? 'تأكيد البيع' : 'Confirm Sale')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))))),
          ])),
    );
  }

  Widget _unitBtn(String label, String value) {
    final sel = _unit == value;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
        onTap: () => setState(() => _unit = value),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: sel ? cs.primary.withOpacity(0.15) : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? cs.primary : cs.outline.withOpacity(0.3),
                    width: sel ? 2 : 1)),
            child: Center(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.bold : null,
                        color: sel ? cs.primary : null)))));
  }
}

/// شيت إضافة كمية
class _AddQuantitySheet extends ConsumerStatefulWidget {
  final ClinicInventoryItem item;
  final ValueChanged<ClinicInventoryItem> onAdded;
  const _AddQuantitySheet({required this.item, required this.onAdded});
  @override
  ConsumerState<_AddQuantitySheet> createState() => _AddQuantitySheetState();
}

class _AddQuantitySheetState extends ConsumerState<_AddQuantitySheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl.text = widget.item.purchasePrice.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (qty <= 0 || price <= 0) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(clinicInventoryServiceProvider);
      final u = await svc.addQuantity(
          inventoryId: widget.item.id,
          boxesToAdd: qty,
          purchasePricePerBox: price);
      if (mounted) {
        widget.onAdded(u);
        Navigator.pop(context);
        final isArabic = context.locale.languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isArabic ? 'تمت إضافة $qty علبة' : 'Added $qty boxes'),
            backgroundColor: Colors.blue));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: cs.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: CachedNetworkImage(
                imageUrl:
                    'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Box-Open-icon.png',
                width: 24,
                height: 24,
                color: Colors.blue,
                placeholder: (context, url) =>
                    const Icon(Icons.add_box, color: Colors.blue),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.add_box, color: Colors.blue),
              )),
          const SizedBox(width: 12),
          Text(isArabic ? 'إضافة كمية' : 'Add Quantity',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold))
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                      labelText: isArabic ? 'عدد العلب' : 'Number of Boxes'))),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: isArabic ? 'سعر الشراء' : 'Purchase Price',
                      suffixText: isArabic ? 'ج' : 'EGP')))
        ]),
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
                onPressed: !_saving ? _add : null,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Plus-icon.png',
                        width: 24,
                        height: 24,
                        color: Colors.white,
                        placeholder: (context, url) =>
                            const Icon(Icons.add, color: Colors.white),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.add, color: Colors.white),
                      ),
                label: Text(_saving
                    ? (isArabic ? 'جاري...' : 'Saving...')
                    : (isArabic ? 'إضافة' : 'Add')),
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))))),
      ]),
    );
  }
}
