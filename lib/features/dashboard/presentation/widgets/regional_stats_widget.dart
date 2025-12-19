import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/dashboard/application/dashboard_provider.dart';

class RegionalStatsWidget extends ConsumerWidget {
  const RegionalStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionalStatsAsync = ref.watch(regionalStatsProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التوزيع الجغرافي للمشاهدات',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مشاهدات منتجاتك حسب المحافظة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            regionalStatsAsync.when(
              data: (regions) {
                if (regions.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد بيانات جغرافية',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: regions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return _buildRegionalItem(context, region);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'خطأ في تحميل البيانات',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionalItem(BuildContext context, Map<String, dynamic> region) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final views = region['views'] ?? 0;
    final regionName = region['region'] ?? 'منطقة غير معروفة';
    final percentage = (region['percentage'] as double?) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isDark ? colorScheme.surfaceVariant.withOpacity(0.3) : Colors.grey[50],
        border: isDark ? Border.all(color: colorScheme.outline.withOpacity(0.2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  regionName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility, size: 14, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      '$views',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: isDark ? colorScheme.outline.withOpacity(0.1) : Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'مشاهدات المنتجات',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}