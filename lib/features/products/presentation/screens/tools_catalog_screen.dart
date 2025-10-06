import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_tool_to_inventory_screen.dart';

class ToolsCatalogScreen extends ConsumerStatefulWidget {
  const ToolsCatalogScreen({super.key});

  @override
  ConsumerState<ToolsCatalogScreen> createState() => _ToolsCatalogScreenState();
}

class _ToolsCatalogScreenState extends ConsumerState<ToolsCatalogScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshTools() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('كتالوج الأدوات'),
          ],
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن أداة جراحية...',
                  prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),
          
          // Tools List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(productRepositoryProvider).getSurgicalToolsCatalog(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري تحميل الكتالوج...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: _refreshTools,
            );
          }

          var tools = snapshot.data ?? [];

          // Filter tools based on search query
          if (_searchQuery.isNotEmpty) {
            tools = tools.where((tool) {
              final toolName = (tool['tool_name'] ?? '').toLowerCase();
              final company = (tool['company'] ?? '').toLowerCase();
              
              return toolName.contains(_searchQuery) ||
                     company.contains(_searchQuery);
            }).toList();
          }

          if (tools.isEmpty) {
            return _EmptyState(
              isSearching: _searchQuery.isNotEmpty,
              onClearSearch: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshTools,
            color: theme.colorScheme.primary,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _StatsCard(
                      totalCount: snapshot.data?.length ?? 0,
                      filteredCount: tools.length,
                      isFiltered: _searchQuery.isNotEmpty,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = tools[index];
                        
                        final toolName = tool['tool_name'] ?? 'Unknown';
                        final company = tool['company'];
                        final imageUrl = tool['image_url'];
                        final toolId = tool['id']?.toString() ?? '';

                        return _ModernToolCard(
                          toolName: toolName,
                          company: company,
                          imageUrl: imageUrl,
                          index: index,
                          toolId: toolId,
                        );
                      },
                      childCount: tools.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// _StatsCard - بطاقة الإحصائيات
// ===================================================================
class _StatsCard extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final bool isFiltered;

  const _StatsCard({
    required this.totalCount,
    required this.filteredCount,
    required this.isFiltered,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.medical_services_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            isFiltered ? 'نتائج البحث:' : 'الأدوات المتاحة:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isFiltered ? '$filteredCount من $totalCount' : '$totalCount',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// _ModernToolCard - بطاقة الأداة المحسنة
// ===================================================================
class _ModernToolCard extends StatelessWidget {
  final String toolName;
  final String? company;
  final String? imageUrl;
  final int index;
  final String toolId;

  const _ModernToolCard({
    required this.toolName,
    required this.company,
    required this.imageUrl,
    required this.index,
    required this.toolId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.cardColor,
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.15),
          ),
          boxShadow: theme.brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // صورة الأداة
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.medical_services_outlined,
                              color: colorScheme.onSurfaceVariant,
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.medical_services_outlined,
                            color: colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
                        
              // تفاصيل الأداة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم الأداة
                    Text(
                      toolName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // Company
                    if (company != null && company!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.business_rounded,
                              size: 12,
                              color: colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              company!,
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
                ],
              ),
            ),
            // زر الإضافة في الزاوية العلوية اليمنى
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddToolToInventoryScreen(
                          toolId: toolId,
                          toolName: toolName,
                          company: company ?? '',
                          imageUrl: imageUrl ?? '',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
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
    );
  }
}

// ===================================================================
// _EmptyState - حالة فارغة محسنة
// ===================================================================
class _EmptyState extends StatelessWidget {
  final bool isSearching;
  final VoidCallback onClearSearch;

  const _EmptyState({
    required this.isSearching,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.primaryContainer.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.medical_services_outlined,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isSearching ? 'لا توجد نتائج للبحث' : 'لا توجد أدوات متاحة',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? 'حاول البحث بكلمات مختلفة'
                  : 'لا توجد أدوات جراحية في الكتالوج حالياً',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            if (isSearching) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear_rounded),
                label: const Text(
                  'مسح البحث',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// _ErrorState - حالة الخطأ المحسنة
// ===================================================================
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: theme.colorScheme.error.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ في تحميل الكتالوج',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                side: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
