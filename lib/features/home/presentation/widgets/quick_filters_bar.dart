import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/home/application/search_filters_provider.dart';

class QuickFiltersBar extends ConsumerWidget {
  const QuickFiltersBar({super.key});

  static const List<String> governorates = [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'الدقهلية', 'البحر الأحمر', 
    'البحيرة', 'الفيوم', 'الغربية', 'الإسماعيلية', 'المنوفية', 
    'المنيا', 'القليوبية', 'بني سويف', 'أسيوط', 'أسوان', 
    'سوهاج', 'قنا', 'الأقصر', 'دمياط', 'الشرقية', 
    'كفر الشيخ', 'بورسعيد', 'مطروح', 'السويس', 'شمال سيناء', 
    'جنوب سيناء', 'الوادي الجديد',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);
    
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // الصف الأول: الأرخص والأقرب
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSmallFilterChip(
              context,
              label: isAr ? 'الأرخص' : 'Cheapest',
              isSelected: filters.isCheapest,
              icon: Icons.monetization_on_outlined,
              onTap: () => ref.read(searchFiltersProvider.notifier).toggleCheapest(),
            ),
            const SizedBox(width: 8),
            _buildSmallFilterChip(
              context,
              label: isAr ? 'الأقرب' : 'Nearest',
              isSelected: filters.isNearest,
              icon: Icons.near_me_outlined,
              onTap: () => ref.read(searchFiltersProvider.notifier).toggleNearest(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // الصف الثاني: المحافظة
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSmallFilterChip(
              context,
              label: filters.selectedGovernorate ?? (isAr ? 'المحافظة' : 'Governorate'),
              isSelected: filters.selectedGovernorate != null,
              icon: Icons.location_city_rounded,
              isWide: true, // لجعله يأخذ مساحة أكبر قليلاً
              onTap: () => _showGovernoratePicker(context, ref),
              onClear: filters.selectedGovernorate != null 
                  ? () => ref.read(searchFiltersProvider.notifier).setGovernorate(null) 
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool isWide = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  onClear();
                },
                child: const Icon(Icons.close, size: 12, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showGovernoratePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Text(
                'اختر المحافظة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: governorates.length,
                  itemBuilder: (context, index) {
                    final gov = governorates[index];
                    return ListTile(
                      title: Text(gov),
                      onTap: () {
                        ref.read(searchFiltersProvider.notifier).setGovernorate(gov);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}