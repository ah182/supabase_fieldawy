import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/stories/application/seen_stories_provider.dart';
import 'package:fieldawy_store/features/stories/application/story_filters_provider.dart'; // Import story filters
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';
import 'package:fieldawy_store/features/stories/application/stories_provider.dart';
import 'package:fieldawy_store/features/stories/presentation/screens/all_stories_screen.dart';
import 'package:fieldawy_store/features/stories/presentation/screens/story_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoriesBar extends ConsumerWidget {
  final bool limitItems; // خاصية للتحكم في عدد العناصر (3 للديالوج)

  const StoriesBar({
    super.key,
    this.limitItems = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);
    final filters = ref.watch(storyFiltersProvider); // استخدام فلتر الستوري المنفصل
    final currentUser = ref.watch(userDataProvider).asData?.value;
    final distributorsAsync = ref.watch(distributorsProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    return storiesAsync.when(
      loading: () => const _StoriesLoadingSkeleton(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                isAr ? 'لا توجد قصص نشطة حالياً' : 'No active stories right now',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          );
        }

        final Set<String> seenIds = ref.watch(seenStoriesProvider); // تحديد النوع صراحةً

        // 1. تطبيق الفلترة الجغرافية
        var filteredGroups = groups.where((group) {
          final distributor = group.distributor;
          
          // فلترة المحافظة
          if (filters.selectedGovernorate != null) {
            final List<String> govList = List<String>.from(distributor.governorates ?? []);
            if (!govList.contains(filters.selectedGovernorate)) return false;
          }
          
          return true;
        }).toList();

        // 2. تطبيق الترتيب (الأقرب أولاً)
        if (currentUser != null) {
          filteredGroups.sort((a, b) {
            final proximityA = LocationProximity.calculateProximityScore(
              userGovernorates: currentUser.governorates,
              userCenters: currentUser.centers,
              distributorGovernorates: a.distributor.governorates,
              distributorCenters: a.distributor.centers,
            );
            final proximityB = LocationProximity.calculateProximityScore(
              userGovernorates: currentUser.governorates,
              userCenters: currentUser.centers,
              distributorGovernorates: b.distributor.governorates,
              distributorCenters: b.distributor.centers,
            );
            return proximityB.compareTo(proximityA);
          });

          // 2.5 أولوية استوري الموزع الحالي (Logged-in Distributor Priority)
          // إذا كان المستخدم الحالي موزعاً ولديه استوري، نضعها في المقدمة
          if (currentUser.role == 'distributor' || currentUser.role == 'company' || currentUser.role == 'admin') {
            final myStoryIndex = filteredGroups.indexWhere((g) => g.distributor.id == currentUser.id);
            if (myStoryIndex != -1) {
              final myGroup = filteredGroups.removeAt(myStoryIndex);
              filteredGroups.insert(0, myGroup);
            }
          }
        }

        if (filteredGroups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(isAr ? 'لا توجد عروض في هذا النطاق' : 'No offers in this range', 
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          );
        }

        // 3. تحديد العدد المعروض (3 + زر المزيد)
        final int displayLimit = 3; // عرض 3 موزعين
        // إظهار زر المزيد دائمًا إذا كانت القائمة محدودة (للوصول لصفحة البحث والفلترة)
        final bool showMore = limitItems && filteredGroups.isNotEmpty; 
        
        // إذا كان عدد العناصر أقل من الحد، نعرضهم كلهم + زر المزيد
        // إذا كان أكثر، نعرض الحد + زر المزيد
        final int storiesToShow = filteredGroups.length > displayLimit ? displayLimit : filteredGroups.length;
        final int itemCount = showMore ? storiesToShow + 1 : filteredGroups.length;

        return Container(
          height: 85,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              // زر "رؤية المزيد" يكون دائمًا العنصر الأخير إذا كان showMore مفعل
              if (showMore && index == storiesToShow) {
                return _BuildSeeAllButton(groups: groups); // Pass original unfiltered groups or filtered? Usually all.
              }

              final group = filteredGroups[index];
              // فحص ما إذا كانت كل القصص في هذه المجموعة قد شوهدت
              final bool allSeen = group.stories.every((s) => seenIds.contains(s.id));

              return _StoryCircle(
                group: group, 
                index: index, 
                allGroups: filteredGroups,
                isAllSeen: allSeen,
              );
            },
          ),
        );
      },
    );
  }
}

class _BuildSeeAllButton extends StatelessWidget {
  final List<dynamic> groups;
  const _BuildSeeAllButton({required this.groups});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AllStoriesScreen(groups: groups)),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 32, // More compact size
                        height: 32,
                        margin: const EdgeInsets.only(top: 10), // Adjust to center vertically with larger story circles
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.9),
                              theme.colorScheme.secondary.withOpacity(0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded, 
                          color: Colors.white, 
                          size: 14
                        ), 
                      ),
                    ],
                  ),
                );  }
}

class _StoryCircle extends StatelessWidget {
  final dynamic group;
  final int index;
  final List<dynamic> allGroups;
  final bool isAllSeen; // خاصية جديدة

  const _StoryCircle({
    required this.group, 
    required this.index,
    required this.allGroups,
    this.isAllSeen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distributor = group.distributor;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => StoryViewScreen(
              initialGroupIndex: index, 
              groups: List.from(allGroups),
            ),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // تغيير اللون بناءً على حالة المشاهدة
              gradient: isAllSeen 
                ? null 
                : LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                      Colors.purpleAccent.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
              color: isAllSeen ? Colors.grey.withOpacity(0.3) : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage: distributor.photoURL != null && distributor.photoURL!.isNotEmpty
                    ? CachedNetworkImageProvider(distributor.photoURL!)
                    : null,
                child: distributor.photoURL == null || distributor.photoURL!.isEmpty
                    ? Icon(Icons.person, color: isAllSeen ? Colors.grey : theme.colorScheme.primary, size: 20)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 55,
            child: Text(
              distributor.displayName ?? 'موزع',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isAllSeen ? FontWeight.normal : FontWeight.w600,
                fontSize: 9,
                color: isAllSeen ? theme.colorScheme.onSurface.withOpacity(0.4) : theme.colorScheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoriesLoadingSkeleton extends StatelessWidget {
  const _StoriesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.withOpacity(0.1),
              ),
              const SizedBox(height: 6),
              Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
