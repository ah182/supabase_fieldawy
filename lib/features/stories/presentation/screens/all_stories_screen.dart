import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';

import 'package:fieldawy_store/core/utils/location_proximity.dart';
import 'package:fieldawy_store/features/stories/application/seen_stories_provider.dart';
import 'package:fieldawy_store/features/stories/application/story_filters_provider.dart';
import 'package:fieldawy_store/features/stories/presentation/screens/story_view_screen.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/quick_filters_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

class AllStoriesScreen extends ConsumerStatefulWidget {
  final List<dynamic> groups;

  const AllStoriesScreen({super.key, required this.groups});

  @override
  ConsumerState<AllStoriesScreen> createState() => _AllStoriesScreenState();
}

class _AllStoriesScreenState extends ConsumerState<AllStoriesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // دالة لعرض ديالوج الفلتر الموحد
  void _showFiltersDialog(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      alignment: const Alignment(0, -0.5),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      isAr ? 'الفلاتر السريعة' : 'Quick Filters',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.indigoAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const QuickFiltersBar(showCheapest: false, useStoryFilters: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = context.locale.languageCode == 'ar';
    
    final filters = ref.watch(storyFiltersProvider);
    final currentUser = ref.watch(userDataProvider).asData?.value;
    final Set<String> seenIds = ref.watch(seenStoriesProvider);

    var filteredGroups = widget.groups.where((group) {
      final distributor = group.distributor;
      final String distName = (distributor.displayName ?? '').toLowerCase();
      final List<String> distGovs = List<String>.from(distributor.governorates ?? []).map((e) => e.toLowerCase()).toList();
      final String query = _searchQuery.toLowerCase().trim();

      bool matchesSearch = true;
      if (query.isNotEmpty) {
        bool nameMatch = distName.contains(query);
        bool govMatch = distGovs.any((gov) => gov.contains(query));
        matchesSearch = nameMatch || govMatch;
      }

      bool matchesFilterGov = true;
      if (filters.selectedGovernorate != null) {
        matchesFilterGov = distGovs.contains(filters.selectedGovernorate!.toLowerCase());
      }
      
      return matchesSearch && matchesFilterGov;
    }).toList();

    if (currentUser != null) {
      filteredGroups.sort((a, b) {
        final proximityA = LocationProximity.calculateProximityScore(
          userGovernorates: currentUser.governorates, userCenters: currentUser.centers,
          distributorGovernorates: a.distributor.governorates, distributorCenters: a.distributor.centers,
        );
        final proximityB = LocationProximity.calculateProximityScore(
          userGovernorates: currentUser.governorates, userCenters: currentUser.centers,
          distributorGovernorates: b.distributor.governorates, distributorCenters: b.distributor.centers,
        );
        return proximityB.compareTo(proximityA);
      });
    }

    final isFilterActive = filters.isNearest || filters.selectedGovernorate != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'استوري الموزعين' : 'Distributor Stories'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(color: theme.colorScheme.onSurface), // الخط متجاوب مع الثيم
                      decoration: InputDecoration(
                        hintText: isAr ? 'ابحث بالاسم أو المحافظة...' : 'Search by name or gov...',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.primary),
                        suffixIcon: _searchQuery.isNotEmpty 
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showFiltersDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFilterActive ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 22,
                      color: isFilterActive ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredGroups.isEmpty
                ? _buildEmptyState(isAr)
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 16, mainAxisSpacing: 20,
                    ),
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      final distributor = group.distributor;
                      // فحص ما إذا كانت كل القصص في هذه المجموعة قد شوهدت
                      final bool allSeen = group.stories.every((s) => seenIds.contains(s.id));

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, PageRouteBuilder(opaque: false, pageBuilder: (_, __, ___) => StoryViewScreen(initialGroupIndex: index, groups: List.from(filteredGroups))));
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, 
                                gradient: allSeen 
                                  ? null 
                                  : LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                                color: allSeen ? Colors.grey.withOpacity(0.3) : null,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                                child: CircleAvatar(
                                  radius: 35,
                                  backgroundColor: theme.colorScheme.surfaceVariant,
                                  backgroundImage: distributor.photoURL != null && distributor.photoURL!.isNotEmpty ? CachedNetworkImageProvider(distributor.photoURL!) : null,
                                  child: distributor.photoURL == null || distributor.photoURL!.isEmpty 
                                    ? Icon(Icons.person, size: 30, color: allSeen ? Colors.grey : theme.colorScheme.primary) 
                                    : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              distributor.displayName ?? '', 
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: allSeen ? FontWeight.normal : FontWeight.bold,
                                color: allSeen ? theme.colorScheme.onSurface.withOpacity(0.5) : theme.colorScheme.onSurface,
                              ), 
                              textAlign: TextAlign.center, 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${group.stories.length} ${isAr ? "استوري" : "stories"}', 
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey.withOpacity(0.6)),
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

  Widget _buildEmptyState(bool isAr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(isAr ? 'لا توجد نتائج بحث' : 'No results found', style: const TextStyle(color: Colors.grey)),
          if (_searchQuery.isNotEmpty)
            TextButton(onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }, child: Text(isAr ? 'مسح البحث' : 'Clear Search')),
        ],
      ),
    );
  }
}
