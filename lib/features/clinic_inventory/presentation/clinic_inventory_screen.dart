import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/services/clinic_inventory_service.dart';
import '../data/models/clinic_inventory_item.dart';
import 'widgets/inventory_stats_card.dart';
import 'widgets/inventory_item_card.dart';
import 'screens/inventory_reports_screen.dart';
import 'screens/inventory_item_details_screen.dart';
import 'screens/add_to_inventory_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/application/catalog_selection_controller.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import '../data/services/clinic_assistant_auth_service.dart';
import 'package:flutter/services.dart';

class ClinicInventoryScreen extends ConsumerStatefulWidget {
  const ClinicInventoryScreen({super.key});

  @override
  ConsumerState<ClinicInventoryScreen> createState() =>
      _ClinicInventoryScreenState();
}

class _ClinicInventoryScreenState extends ConsumerState<ClinicInventoryScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'low_stock', 'expiring', 'out_of_stock'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClinicInventoryItem> _filterItems(List<ClinicInventoryItem> items) {
    var filtered = items;

    // تصفية بالبحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.productName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (item.company
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    // تصفية بالنوع
    switch (_filterType) {
      case 'low_stock':
        filtered = filtered
            .where((item) =>
                item.stockStatus == StockStatus.low ||
                item.stockStatus == StockStatus.critical)
            .toList();
        break;
      case 'expiring':
        filtered = filtered
            .where((item) =>
                item.expiryStatus == ExpiryStatus.warning ||
                item.expiryStatus == ExpiryStatus.critical)
            .toList();
        break;
      case 'out_of_stock':
        filtered = filtered
            .where((item) => item.stockStatus == StockStatus.outOfStock)
            .toList();
        break;
    }

    return filtered;
  }

  Future<void> _refreshData() async {
    ref.invalidate(clinicInventoryListProvider);
    ref.invalidate(clinicInventoryStatsProvider);
    ref.read(inventoryRefreshProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    // مشاهدة التحديثات
    ref.watch(inventoryRefreshProvider);
    final inventoryAsync = ref.watch(clinicInventoryListProvider);
    final statsAsync = ref.watch(clinicInventoryStatsProvider);

    return Scaffold(
      body: Column(
        children: [
          // الهيدر المتدرج
          _buildHeader(theme, colorScheme),

          // المحتوى
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الإحصائيات
                    statsAsync.when(
                      data: (stats) => _buildStatsRow(stats, theme),
                      loading: () => _buildStatsLoadingRow(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 20),

                    // البحث والفلترة
                    _buildSearchAndFilter(theme, colorScheme),

                    const SizedBox(height: 16),

                    // قائمة المنتجات
                    inventoryAsync.when(
                      data: (items) {
                        final filtered = _filterItems(items);
                        if (filtered.isEmpty) {
                          return _buildEmptyState(theme, items.isEmpty);
                        }
                        return _buildItemsList(filtered, theme);
                      },
                      loading: () => _buildLoadingState(),
                      error: (error, _) => _buildErrorState(theme, error),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddScreen(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(isArabic ? 'إضافة' : 'Add',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _showAccessCodeDialog() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final service = ref.read(clinicInventoryServiceProvider);
    final code = await service.getOrGenerateAccessCode();

    // Hide loading
    Navigator.of(context).pop();

    if (code == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error generating code")));
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رمز دخول المساعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'استخدم هذا الرمز لتسجيل دخول المساعد إلى نظام الجرد فقط.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('نسخ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
            colorScheme.secondary.withOpacity(0.6),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              // زر الرجوع
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // العنوان
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'جرد العيادة' : 'Clinic Inventory',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic
                          ? 'إدارة مخزون الأدوية والمستلزمات'
                          : 'Inventory Management',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Assistant Actions (Key for Owner, Logout for Assistant)
              Consumer(builder: (context, ref, child) {
                final assistantId = ref.watch(clinicAssistantUserIdProvider);
                final isAssistant = assistantId != null;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isAssistant
                          ? () {
                              // Logout Assistant
                              ref
                                  .read(clinicAssistantAuthServiceProvider)
                                  .logout();
                              Navigator.of(context).pop(); // Back to login
                            }
                          : _showAccessCodeDialog, // Show Code
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          isAssistant
                              ? Icons.logout_rounded
                              : Icons.vpn_key_rounded,
                          color: isAssistant
                              ? Colors.redAccent.shade100
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // زر التقارير
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InventoryReportsScreen()),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats, ThemeData theme) {
    final isArabic = context.locale.languageCode == 'ar';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InventoryStatsCard(
            title: isArabic ? 'إجمالي الأصناف' : 'Total Items',
            value: '${stats['totalItems']}',
            icon: CachedNetworkImage(
              imageUrl:
                  'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Boxes-Stacked-icon.png',
              width: 22,
              height: 22,
              color: Colors.blue,
              placeholder: (context, url) => const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.blue,
                  size: 22),
              errorWidget: (context, url, error) => const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.blue,
                  size: 22),
            ),
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          InventoryStatsCard(
            title: isArabic ? 'نواقص' : 'Low Stock',
            value: '${stats['lowStock']}',
            icon: CachedNetworkImage(
              imageUrl:
                  'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Triangle-Exclamation-icon.png',
              width: 22,
              height: 22,
              color: Colors.orange,
              placeholder: (context, url) => const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 22),
              errorWidget: (context, url, error) => const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 22),
            ),
            color: Colors.orange,
            onTap: () => setState(() => _filterType = 'low_stock'),
          ),
          const SizedBox(width: 12),
          InventoryStatsCard(
            title: isArabic ? 'قرب الانتهاء' : 'Expiring',
            value: '${stats['expiringSoon']}',
            icon: CachedNetworkImage(
              imageUrl:
                  'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Clock-icon.png',
              width: 22,
              height: 22,
              color: Colors.red,
              placeholder: (context, url) => const Icon(Icons.schedule_rounded,
                  color: Colors.red, size: 22),
              errorWidget: (context, url, error) => const Icon(
                  Icons.schedule_rounded,
                  color: Colors.red,
                  size: 22),
            ),
            color: Colors.red,
            onTap: () => setState(() => _filterType = 'expiring'),
          ),
          const SizedBox(width: 12),
          InventoryStatsCard(
            title: isArabic ? 'مبيعات اليوم' : 'Today Sales',
            value: '${(stats['todaySales'] as num).toStringAsFixed(0)} ج',
            icon: CachedNetworkImage(
              imageUrl:
                  'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Arrow-Trend-Up-icon.png',
              width: 22,
              height: 22,
              color: Colors.green,
              placeholder: (context, url) => const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.green,
                  size: 22),
              errorWidget: (context, url, error) => const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.green,
                  size: 22),
            ),
            color: Colors.green,
            subtitle: isArabic
                ? 'ربح: ${(stats['todayProfit'] as num).toStringAsFixed(0)} ج'
                : 'Profit: ${(stats['todayProfit'] as num).toStringAsFixed(0)} EGP',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsLoadingRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(right: index < 3 ? 12 : 0),
            child: Container(
              width: 130,
              height: 90,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme, ColorScheme colorScheme) {
    final isArabic = context.locale.languageCode == 'ar';
    return Column(
      children: [
        // حقل البحث
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: isArabic ? 'ابحث عن دواء...' : 'Search...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
          ),
        ),

        const SizedBox(height: 12),

        // أزرار الفلترة
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                  isArabic ? 'الكل' : 'All', 'all', Icons.apps_rounded),
              const SizedBox(width: 8),
              _buildFilterChip(isArabic ? 'نواقص' : 'Low Stock', 'low_stock',
                  Icons.warning_amber_rounded),
              const SizedBox(width: 8),
              _buildFilterChip(isArabic ? 'قرب الانتهاء' : 'Expiring',
                  'expiring', Icons.schedule_rounded),
              const SizedBox(width: 8),
              _buildFilterChip(isArabic ? 'نفذ' : 'Out', 'out_of_stock',
                  Icons.remove_shopping_cart_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterType == value;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (_) => setState(() => _filterType = value),
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.outline.withOpacity(0.3),
      ),
    );
  }

  Widget _buildItemsList(List<ClinicInventoryItem> items, ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return InventoryItemCard(
          item: item,
          onTap: () => _navigateToDetails(context, item),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool noItemsAtAll) {
    final isArabic = context.locale.languageCode == 'ar';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CachedNetworkImage(
                imageUrl: noItemsAtAll
                    ? 'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Box-Open-icon.png'
                    : 'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Magnifying-Glass-icon.png',
                width: 64,
                height: 64,
                color: theme.colorScheme.primary,
                placeholder: (context, url) => Icon(
                  noItemsAtAll
                      ? Icons.inventory_2_outlined
                      : Icons.search_off_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                errorWidget: (context, url, error) => Icon(
                  noItemsAtAll
                      ? Icons.inventory_2_outlined
                      : Icons.search_off_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              noItemsAtAll
                  ? (isArabic ? 'لا توجد أصناف' : 'No Items')
                  : (isArabic ? 'لا توجد نتائج' : 'No Results'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noItemsAtAll
                  ? (isArabic
                      ? 'ابدأ بإضافة أول صنف للمخزون'
                      : 'Start adding items')
                  : (isArabic
                      ? 'جرب تغيير معايير البحث'
                      : 'Try changing filters'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (noItemsAtAll) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _navigateToAddScreen(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(isArabic ? 'إضافة صنف' : 'Add Item'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Object error) {
    final isArabic = context.locale.languageCode == 'ar';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'حدث خطأ أثناء تحميل البيانات' : 'Error loading data',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                    color: colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // العنوان
              Text(
                isArabic ? 'إضافة للجرد' : 'Add to Inventory',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic ? 'اختر طريقة إضافة المنتجات' : 'Choose method',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // الخيارات
              _buildAddOption(
                context: context,
                imageUrl:
                    'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Pen-to-Square-icon.png',
                fallbackIcon: Icons.edit_note_rounded,
                title: isArabic ? 'إضافة يدوية' : 'Manual Add',
                subtitle: isArabic
                    ? 'أدخل بيانات المنتج يدوياً'
                    : 'Enter details manually',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddToInventoryScreen(),
                    ),
                  ).then((_) => _refreshData());
                },
              ),
              const SizedBox(height: 12),

              _buildAddOption(
                context: context,
                imageUrl:
                    'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Table-Cells-icon.png',
                fallbackIcon: Icons.grid_view_rounded,
                title: isArabic ? 'من الكتالوج' : 'From Catalog',
                subtitle: isArabic
                    ? 'اختر من المنتجات المسجلة'
                    : 'From registered products',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddFromCatalogScreen(
                        catalogContext: CatalogContext.clinicInventory,
                      ),
                    ),
                  ).then((_) => _refreshData());
                },
              ),
              const SizedBox(height: 12),

              _buildAddOption(
                context: context,
                imageUrl:
                    'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Camera-icon.png',
                fallbackIcon: Icons.document_scanner_rounded,
                title: isArabic ? 'إضافة بالمسح الضوئي' : 'OCR Scan',
                subtitle: isArabic ? 'التقط صورة المنتج' : 'Scan product image',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  // نذهب لصفحة إضافة المنتج بالـ OCR
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddProductOcrScreen(
                        isFromClinicInventory: true,
                      ),
                    ),
                  ).then((_) => _refreshData());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required BuildContext context,
    required String imageUrl, // Changed from IconData to imageUrl
    required IconData fallbackIcon, // Added fallback
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 24,
                  height: 24,
                  color: color,
                  placeholder: (context, url) =>
                      Icon(fallbackIcon, color: color, size: 24),
                  errorWidget: (context, url, error) =>
                      Icon(fallbackIcon, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, ClinicInventoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryItemDetailsScreen(item: item),
      ),
    ).then((_) => _refreshData());
  }
}
