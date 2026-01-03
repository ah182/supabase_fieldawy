import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/stories/domain/story_model.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // إضافة NetworkGuard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider لجلب جميع الستوريهات النشطة وتجميعها حسب الموزع (مع الكاش)
final storiesProvider = FutureProvider<List<DistributorStoriesGroup>>((ref) async {
  final cache = ref.watch(cachingServiceProvider);
  
  // استخدام Stale-While-Revalidate لظهور لحظي وتحديث في الخلفية
  return await cache.staleWhileRevalidate<List<DistributorStoriesGroup>>(
    key: 'active_distributor_stories_v2',
    duration: const Duration(minutes: 10), // بقاء البيانات في الكاش
    staleTime: const Duration(minutes: 5), // تحديث البيانات بعد 5 دقائق
    fetchFromNetwork: () => _fetchStoriesFromServer(ref),
    fromCache: (data) => (data as List).map((e) => e as DistributorStoriesGroup).toList(),
  );
});

Future<List<DistributorStoriesGroup>> _fetchStoriesFromServer(Ref ref) async {
  return await NetworkGuard.execute(() async { // استخدام NetworkGuard
    final supabase = Supabase.instance.client;
    
    final response = await supabase
        .from('distributor_stories')
        .select()
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);

    if ((response as List).isEmpty) {
      return [];
    }

    final storiesData = List<Map<String, dynamic>>.from(response);
    // نستخدم ref.read بدلاً من ref.watch داخل دالة الـ fetch لتجنب إعادة البناء المتكرر غير الضروري
    // لكن بما أننا داخل دالة عادية، سنستخدم الـ future الممرر
    final distributors = await ref.read(distributorsProvider.future);
    final distributorsMap = {for (var d in distributors) d.id: d};

    final Map<String, List<StoryModel>> groupedMap = {};
    
    for (var data in storiesData) {
      final distId = data['distributor_id'];
      if (!distributorsMap.containsKey(distId)) continue;

      final story = StoryModel.fromMap(data, distributor: distributorsMap[distId]);
      
      if (groupedMap.containsKey(distId)) {
        groupedMap[distId]!.add(story);
      } else {
        groupedMap[distId] = [story];
      }
    }

    return groupedMap.entries.map((entry) {
      return DistributorStoriesGroup(
        distributor: distributorsMap[entry.key]!,
        stories: entry.value,
      );
    }).toList();
  });
}
