import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/home/application/search_filters_provider.dart';
import 'package:fieldawy_store/features/stories/application/story_filters_provider.dart';

class QuickFiltersBar extends ConsumerWidget {
  final bool showCheapest;
  final bool useStoryFilters; // خاصية جديدة لتحديد أي Provider نستخدم

  const QuickFiltersBar({
    super.key,
    this.showCheapest = true,
    this.useStoryFilters = false,
  });

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
   
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // 1. تحديد الـ State والـ Notifier بناءً على النوع
    final filters = useStoryFilters 
        ? _getStoryState(ref) 
        : _getSearchState(ref);
    
    final notifier = useStoryFilters 
        ? ref.read(storyFiltersProvider.notifier) 
        : ref.read(searchFiltersProvider.notifier);

    // 2. البناء (نفس المنطق السابق ولكن مع البيانات المختارة)
    if (!showCheapest) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSmallFilterChip(
            context,
            label: isAr ? 'الأقرب' : 'Nearest',
            isSelected: filters['isNearest'],
            icon: Icons.near_me_outlined,
            onTap: () => useStoryFilters 
                ? (notifier as StoryFiltersNotifier).toggleNearest()
                : (notifier as SearchFiltersNotifier).toggleNearest(),
          ),
          const SizedBox(width: 8),
          _buildSmallFilterChip(
            context,
            label: filters['selectedGovernorate'] ?? (isAr ? 'المحافظة' : 'Gov'),
            isSelected: filters['selectedGovernorate'] != null,
            icon: Icons.location_city_rounded,
            onTap: () => _showGovernoratePicker(context, ref),
            onClear: filters['selectedGovernorate'] != null 
                ? () => useStoryFilters
                    ? (notifier as StoryFiltersNotifier).setGovernorate(null)
                    : (notifier as SearchFiltersNotifier).setGovernorate(null)
                : null,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showCheapest) ...[
              _buildSmallFilterChip(
                context,
                label: isAr ? 'الأرخص' : 'Cheapest',
                isSelected: filters['isCheapest'] ?? false,
                icon: Icons.monetization_on_outlined,
                onTap: () => (notifier as SearchFiltersNotifier).toggleCheapest(),
              ),
              const SizedBox(width: 8),
            ],
            _buildSmallFilterChip(
              context,
              label: isAr ? 'الأقرب' : 'Nearest',
              isSelected: filters['isNearest'],
              icon: Icons.near_me_outlined,
              onTap: () => useStoryFilters 
                ? (notifier as StoryFiltersNotifier).toggleNearest()
                : (notifier as SearchFiltersNotifier).toggleNearest(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSmallFilterChip(
              context,
              label: filters['selectedGovernorate'] ?? (isAr ? 'المحافظة' : 'Governorate'),
              isSelected: filters['selectedGovernorate'] != null,
              icon: Icons.location_city_rounded,
              isWide: true,
              onTap: () => _showGovernoratePicker(context, ref),
              onClear: filters['selectedGovernorate'] != null 
                  ? () => useStoryFilters
                      ? (notifier as StoryFiltersNotifier).setGovernorate(null)
                      : (notifier as SearchFiltersNotifier).setGovernorate(null)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // دوال مساعدة لجلب الحالة بشكل منظم
  Map<String, dynamic> _getSearchState(WidgetRef ref) {
    final s = ref.watch(searchFiltersProvider);
    return {'isNearest': s.isNearest, 'isCheapest': s.isCheapest, 'selectedGovernorate': s.selectedGovernorate};
  }

  Map<String, dynamic> _getStoryState(WidgetRef ref) {
    final s = ref.watch(storyFiltersProvider);
    return {'isNearest': s.isNearest, 'selectedGovernorate': s.selectedGovernorate};
  }

  Widget _buildSmallFilterChip(context, {required String label, required bool isSelected, required IconData icon, required VoidCallback onTap, VoidCallback? onClear, bool isWide = false}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 12, color: Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }

  void _showGovernoratePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GovernoratePickerSheet(
        useStoryFilters: useStoryFilters, // تمرير العلم للـ Sheet
        onSelected: (gov) => useStoryFilters 
            ? ref.read(storyFiltersProvider.notifier).setGovernorate(gov)
            : ref.read(searchFiltersProvider.notifier).setGovernorate(gov),
        selectedGovernorate: useStoryFilters 
            ? ref.read(storyFiltersProvider).selectedGovernorate
            : ref.read(searchFiltersProvider).selectedGovernorate,
      ),
    );
  }
}

class _GovernoratePickerSheet extends StatefulWidget {
  final Function(String?) onSelected;
  final String? selectedGovernorate;
  final bool useStoryFilters;

  const _GovernoratePickerSheet({required this.onSelected, this.selectedGovernorate, required this.useStoryFilters});

  @override
  State<_GovernoratePickerSheet> createState() => _GovernoratePickerSheetState();
}

class _GovernoratePickerSheetState extends State<_GovernoratePickerSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final filteredGovernorates = QuickFiltersBar.governorates.where((gov) => gov.contains(_searchQuery)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(isAr ? 'اختيار المحافظة' : 'Select Governorate', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: isAr ? 'ابحث عن محافظة...' : 'Search governorate...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredGovernorates.length,
                  itemBuilder: (context, index) {
                    final gov = filteredGovernorates[index];
                    final isSelected = gov == widget.selectedGovernorate;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(gov, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                      onTap: () { widget.onSelected(gov); Navigator.pop(context); },
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