import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/home/application/search_history_provider.dart';

class SearchHistoryView extends ConsumerWidget {
  final Function(String) onTermSelected;
  final VoidCallback? onClose;
  final String tabId; // معرف التاب المطلوب

  const SearchHistoryView({
    super.key,
    required this.onTermSelected,
    this.onClose,
    required this.tabId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the whole map, but extract specific list
    final historyMap = ref.watch(searchHistoryProvider);
    final history = historyMap[tabId] ?? [];
    
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isAr ? 'عمليات البحث الأخيرة' : 'Recent Searches',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (history.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    ref.read(searchHistoryProvider.notifier).clearHistory(tabId);
                  },
                  child: Text(
                    isAr ? 'مسح الكل' : 'Clear All',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 16), // مسافة أكبر بين العنوان والكلمات
        
        // Grid-like Wrap for search terms (3 per row)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6, // المسافة الأفقية
            runSpacing: 10, // زيادة المسافة الرأسية قليلاً كما طلبت
            children: history.map((term) {
              return GestureDetector(
                onTap: () => onTermSelected(term),
                child: Container(
                  width: (MediaQuery.of(context).size.width - 80) / 3,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4), // مسافة صغيرة جداً كما طلبت
                      Expanded(
                        child: Text(
                          term,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 12),
      ],
    );
  }
}