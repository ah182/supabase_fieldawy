import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/home/presentation/mixins/search_tracking_mixin.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// ignore: unnecessary_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:fieldawy_store/services/distributor_subscription_service.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/core/caching/image_cache_manager.dart';
import 'dart:async';
import 'package:fieldawy_store/services/subscription_cache_service.dart';

final subscribedDistributorsIdsProvider = FutureProvider<Set<String>>((ref) async {
  // Ensure cache is ready
  await SubscriptionCacheService.init();
  // Note: We don't sync here to avoid race conditions and network overhead on every refresh.
  // Syncing happens once on screen load via useEffect.
  final list = await DistributorSubscriptionService.getSubscribedDistributorIds();
  return list.toSet();
});

final distributorsProvider =
    FutureProvider<List<DistributorModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  const cacheKey = 'distributors_edge';

  // Stale-While-Revalidate Logic
  // 1. Start the network fetch immediately, but don't wait for it.
  final networkFuture = supabase.functions.invoke('get-distributors').then((response) {
    if (response.data == null) {
      print('Failed to fetch fresh distributors');
      return <DistributorModel>[]; 
    }
    final List<dynamic> data = response.data;
    // Update the cache for the next visit
    cache.set(cacheKey, data, duration: const Duration(minutes: 30));
    // Parse and return the fresh data
    final result = data.map((d) => DistributorModel.fromMap(Map<String, dynamic>.from(d))).toList();
    return result;
  }).catchError((error) {
    // معالجة أخطاء الشبكة
    print('خطأ في جلب الموزعين: $error');
    return <DistributorModel>[];
  });

  // 2. Check the local cache for stale data.
  final cached = cache.get<List<dynamic>>(cacheKey);
  if (cached != null) {
    // If we have stale data, return it immediately.
    // The networkFuture will continue in the background and update the cache for the next visit.
    return cached.map((data) => DistributorModel.fromMap(Map<String, dynamic>.from(data))).toList();
  }

  // 3. If there's no cached data, we have to wait for the network to complete.
  try {
    return await networkFuture;
  } catch (e) {
    print('خطأ في تحميل الموزعين: $e');
    // إعادة قائمة فارغة بدلاً من رمي استثناء
    return <DistributorModel>[];
  }
});

class DistributorsScreen extends HookConsumerWidget with SearchTrackingMixin {
  const DistributorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final distributorsAsync = ref.watch(distributorsProvider);
    final currentUserAsync = ref.watch(userDataProvider);
    final searchQuery = useState<String>('');
    final debouncedSearchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final ghostText = useState<String>('');
    final fullSuggestion = useState<String>('');
    final currentSearchId = useState<String?>(null);
    
    // دالة تتبع البحث في الموزعين
    Future<void> trackDistributorsSearch(String searchTerm, List filteredResults) async {
      if (searchTerm.trim().length < 3) { // تتبع البحث فقط إذا كان النص 3 حروف أو أكثر
        currentSearchId.value = null;
        return;
      }

      try {
        // التحقق من أن الـ widget لا يزال موجوداً
        if (!context.mounted) return;
        
        print('🔍 Searching distributors: "$searchTerm" (Results: ${filteredResults.length})');
        
        // التحقق مرة أخرى بعد العملية غير المتزامنة
        if (!context.mounted) return;
        // تم إزالة تتبع البحث في الموزعين
      } catch (e) {
        print('❌ Error in distributor search: $e');
      }
    }
    
    useEffect(() {
      Timer? debounce;
      void listener() {
        if (debounce?.isActive ?? false) debounce!.cancel();
        debounce = Timer(const Duration(milliseconds: 1000), () { // تأخير ثانية واحدة
          debouncedSearchQuery.value = searchController.text;
        });
      }
      
      searchController.addListener(listener);
      return () {
        debounce?.cancel();
        searchController.removeListener(listener);
      };
    }, [searchController]);

    final filteredDistributors = useMemoized(
      () {
        final distributors = distributorsAsync.asData?.value;
        final currentUser = currentUserAsync.asData?.value;
        
        if (distributors == null) {
          return <DistributorModel>[];
        }

        // تصفية حسب البحث
        List<DistributorModel> filtered;
        if (debouncedSearchQuery.value.isEmpty) {
          filtered = distributors;
        } else {
          filtered = distributors.where((distributor) {
            final query = debouncedSearchQuery.value.toLowerCase();
            return distributor.displayName.toLowerCase().contains(query) ||
                (distributor.companyName?.toLowerCase().contains(query) ??
                    false) ||
                (distributor.email?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        // ترتيب حسب القرب الجغرافي
        if (currentUser != null) {
          return LocationProximity.sortByProximity<DistributorModel>(
            items: filtered,
            getProximityScore: (distributor) {
              return LocationProximity.calculateProximityScore(
                userGovernorates: currentUser.governorates,
                userCenters: currentUser.centers,
                distributorGovernorates: distributor.governorates,
                distributorCenters: distributor.centers,
              );
            },
          );
        }

        return filtered;
      },
      [distributorsAsync, currentUserAsync, debouncedSearchQuery.value],
    );

    // تتبع البحث عند تغيير debouncedSearchQuery
    useEffect(() {
      if (debouncedSearchQuery.value.isNotEmpty) {
        trackDistributorsSearch(debouncedSearchQuery.value, filteredDistributors);
      } else {
        currentSearchId.value = null;
      }
      return null;
    }, [debouncedSearchQuery.value, filteredDistributors]);

    // Sync subscriptions from server on load
    useEffect(() {
      Future<void> sync() async {
        await SubscriptionCacheService.init();
        await DistributorSubscriptionService.syncSubscriptions();
        if (context.mounted) {
          ref.invalidate(subscribedDistributorsIdsProvider);
        }
      }
      sync();
      return null;
    }, []);

    // تم إزالة تحسين أسماء المنتجات في الخلفية

    
final sliverAppBar = SliverAppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0), // تنزيل العنوان للأسفل
        child: Text(
          'distributors_feature.title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              fontSize: 22),
        ),
      ),
      pinned: true,
      floating: false,
 
      bottom: PreferredSize(
        preferredSize:
            const Size.fromHeight(100), // زيادة الارتفاع للمسافات الأفضل
        child: Column(
          children: [
            // شريط البحث مع مسافات محسنة
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      16.0, 12.0, 16.0, 8.0), // مسافات أفضل
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onChanged: (value) {
                      searchQuery.value = value;
                      if (value.isNotEmpty) {
                        distributorsAsync.whenData((distributors) {
                          final filtered = distributors.where((distributor) {
                            final displayName = distributor.displayName.toLowerCase();
                            return displayName.startsWith(value.toLowerCase());
                          }).toList();
                          
                          if (filtered.isNotEmpty) {
                            final suggestion = filtered.first;
                            ghostText.value = suggestion.displayName;
                            fullSuggestion.value = suggestion.displayName;
                          } else {
                            ghostText.value = '';
                            fullSuggestion.value = '';
                          }
                        });
                      } else {
                        ghostText.value = '';
                        fullSuggestion.value = '';
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'distributors_feature.search_hint'.tr(),
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.primary,
                        size: 25,
                      ),
                      suffixIcon: searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                searchController.clear();
                                searchQuery.value = '';
                                debouncedSearchQuery.value = '';
                                ghostText.value = '';
                                fullSuggestion.value = '';
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                if (ghostText.value.isNotEmpty)
                  Positioned(
                    top: 23,
                    right: 71,
                    child: GestureDetector(
                      onTap: () {
                        if (fullSuggestion.value.isNotEmpty) {
                          searchController.text = fullSuggestion.value;
                          searchQuery.value = fullSuggestion.value;
                          debouncedSearchQuery.value = fullSuggestion.value;
                          ghostText.value = '';
                          fullSuggestion.value = '';
                          searchFocusNode.unfocus();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.secondary.withOpacity(0.1)
                              : theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ghostText.value,
                          style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // العداد المحسن
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  distributorsAsync.when(
                    data: (distributors) {
                      final totalCount = distributors.length;
                      final filteredCount = debouncedSearchQuery.value.isEmpty
                          ? totalCount
                          : filteredDistributors.length;

                      return Text(
                        debouncedSearchQuery.value.isEmpty
                            ? 'distributors_feature.total_count'.tr(namedArgs: {'count': totalCount.toString()})
                            : 'distributors_feature.showing_count'.tr(namedArgs: {
                                'shown': filteredCount.toString(),
                                'total': totalCount.toString()
                              }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                    loading: () => Text(
                      'distributors_feature.counting'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    error: (_, __) => Text(
                      'distributors_feature.count_error'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    // دالة مساعدة لإخفاء الكيبورد
    void hideKeyboard() {
      if (searchFocusNode.hasFocus) {
        searchFocusNode.unfocus();
        // إعادة تعيين النص الشبحي إذا كان مربع البحث فارغاً
        if (searchController.text.isEmpty) {
          ghostText.value = '';
          fullSuggestion.value = '';
        }
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        hideKeyboard();
      },
      child: MainScaffold(
        selectedIndex: 0,
        body: distributorsAsync.when(
          data: (distributors) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(distributorsProvider.future),
              child: CustomScrollView(
                slivers: [
                  sliverAppBar,
                  if (distributors.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context, theme),
                    )
                  else if (filteredDistributors.isEmpty &&
                      debouncedSearchQuery.value.isNotEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildNoSearchResults(
                          context, theme, debouncedSearchQuery.value),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final distributor = filteredDistributors[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 6.0),
                            child: _buildDistributorCard(
                                context, theme, distributor, ref, currentSearchId.value, debouncedSearchQuery.value),
                          );
                        },
                        childCount: filteredDistributors.length,
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => CustomScrollView(
            slivers: [
              sliverAppBar,
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 6.0),
                    child: DistributorCardShimmer(),
                  ),
                  childCount: 8,
                ),
              ),
            ],
          ),
          error: (error, stack) => CustomScrollView(
            slivers: [
              sliverAppBar,
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(context, theme, error.toString(), ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // كارت الموزع المحسن
  Widget _buildDistributorCard(
      BuildContext context, ThemeData theme, DistributorModel distributor, WidgetRef ref, String? searchId, String searchQuery) {
    final currentUser = ref.read(userDataProvider).asData?.value;
    return _DistributorCard(
      key: ValueKey(distributor.id),
      distributor: distributor,
      theme: theme,
      currentUser: currentUser,
      onShowDetails: () {
        // تتبع النقرة على الموزع إذا كان هناك بحث نشط
        // تم إزالة تتبع النقر على الموزعين
        print('👆 Distributor clicked: ${distributor.displayName}');
        _showDistributorDetails(context, theme, distributor);
      },
    );
  }

  // عرض تفاصيل الموزع - محسن
  void _showDistributorDetails(
      BuildContext context, ThemeData theme, DistributorModel distributor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _buildDistributorDetailsDialog(context, theme, distributor),
    );
  }

  Widget _buildDistributorDetailsDialog(
      BuildContext context, ThemeData theme, DistributorModel distributor) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle المحسن
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header محسن
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: distributor.photoURL != null &&
                            distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: distributor.photoURL!,
                            cacheManager: CustomImageCacheManager(),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                                child: ImageLoadingIndicator(size: 32)),
                            errorWidget: (context, url, error) => Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant),
                          )
                        : Icon(Icons.person_rounded,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  distributor.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (distributor.companyName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      distributor.companyName!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.2)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDetailListTile(
                  theme,
                  Icons.email_rounded,
                  'distributors_feature.email'.tr(),
                  distributor.email ?? 'distributors_feature.not_available'.tr(),
                ),
                _buildDetailListTile(
                  theme,
                  Icons.inventory_2_rounded,
                  'distributors_feature.products_count'.tr(),
                  'distributors_feature.product_count_value'
                      .tr(namedArgs: {'count': distributor.productCount.toString()}),
                ),
                _buildDetailListTile(
                  theme,
                  Icons.business_rounded,
                  'distributors_feature.type'.tr(),
                  distributor.distributorType == 'company'
                      ? 'distributors_feature.company'.tr()
                      : 'distributors_feature.individual'.tr(),
                ),
                if (distributor.distributionMethod != null)
                  _buildDetailListTile(
                    theme,
                    Icons.local_shipping_rounded,
                    'distributors_feature.distribution_method'.tr(),
                    distributor.distributionMethod == 'direct_distribution'
                        ? 'distributors_feature.direct'.tr()
                        : distributor.distributionMethod == 'order_delivery'
                            ? 'distributors_feature.delivery'.tr()
                            : 'distributors_feature.both'.tr(),
                  ),
                if (distributor.governorates != null && distributor.governorates!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.map_rounded, color: theme.colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'distributors_feature.coverage_areas'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0, left: 56.0), // Indent to align with text
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: distributor.governorates!.map((gov) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    gov,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )).toList(),
                              ),
                              if (distributor.centers != null && distributor.centers!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: distributor.centers!.map((center) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      center,
                                      style: TextStyle(
                                        color: theme.colorScheme.secondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (distributor.whatsappNumber != null &&
                    distributor.whatsappNumber!.isNotEmpty)
                  _buildDetailListTile(
                    theme,
                    FontAwesomeIcons.whatsapp,
                    'distributors_feature.whatsapp'.tr(),
                    distributor.whatsappNumber!,
                  ),
              ],
            ),
          ),
          // أزرار العمل المحسنة
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DistributorProductsScreen(
                            distributor: distributor,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: Text('distributors_feature.view_products'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _openWhatsApp(context, distributor);
                    },
                    icon: const FaIcon(FontAwesomeIcons.whatsapp,
                        color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailListTile(
      ThemeData theme, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // وظيفة فتح الواتساب
  Future<void> _openWhatsApp(
      BuildContext context, DistributorModel distributor) async {
    final phoneNumber = distributor.whatsappNumber;

    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('distributors_feature.phone_not_available'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // إزالة أي رموز غير ضرورية من رقم الهاتف
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // رسالة افتراضية
    final message = Uri.encodeComponent('distributors_feature.whatsapp_inquiry'.tr());

    // رابط الواتساب
    final whatsappUrl = 'https://wa.me/20$cleanPhone?text=$message';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('distributors_feature.whatsapp_error'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'distributors_feature.ok'.tr(),
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // حالة الخطأ
  Widget _buildErrorState(BuildContext context, ThemeData theme, String error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'distributors_feature.error_connection'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'distributors_feature.error_message'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // إعادة تحميل البيانات
                ref.invalidate(distributorsProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('distributors_feature.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  // حالة عدم وجود موزعين
  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_alt_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'distributors_feature.no_distributors'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // حالة عدم وجود نتائج بحث
  Widget _buildNoSearchResults(
      BuildContext context, ThemeData theme, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'distributors_feature.no_search_results'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'distributors_feature.no_results_for'.tr(namedArgs: {'query': query}),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DistributorCardShimmer extends StatelessWidget {
  const DistributorCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [                       
          ShimmerLoader(width: 60, height: 60, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoader(width: 150, height: 15, borderRadius: 8),
                const SizedBox(height: 8),
                ShimmerLoader(width: 100, height: 12, borderRadius: 8),
                const SizedBox(height: 8),
                ShimmerLoader(width: 80, height: 12, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget منفصل للكارت مع state management محلي
class _DistributorCard extends HookConsumerWidget {
  final DistributorModel distributor;
  final ThemeData theme;
  final UserModel? currentUser;
  final VoidCallback onShowDetails;

  const _DistributorCard({
    super.key,
    required this.distributor,
    required this.theme,
    required this.currentUser,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompany = distributor.distributorType == 'company';
    final isLoading = useState(false);
    final subscribersCountLocal = useState(distributor.subscribersCount);
    
    // Watch the subscription state provider
    final subscribedIdsAsync = ref.watch(subscribedDistributorsIdsProvider);
    final isSubscribed = subscribedIdsAsync.asData?.value.contains(distributor.id) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onShowDetails,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: distributor.photoURL != null &&
                            distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: distributor.photoURL!,
                            cacheManager: CustomImageCacheManager(),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: ImageLoadingIndicator(size: 24),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 28,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // معلومات الموزع
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distributor.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompany
                                  ? Icons.business_rounded
                                  : Icons.person_outline_rounded,
                              size: 12,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                distributor.companyName ??
                                    (isCompany
                                        ? 'distributors_feature.company'.tr()
                                        : 'distributors_feature.individual'.tr()),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // المؤشرات البصرية للقرب الجغرافي
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // شارة "قريب منك" للمركز
                          if (currentUser?.centers != null &&
                              LocationProximity.hasCommonCenter(
                                userCenters: currentUser!.centers!,
                                distributorCenters: distributor.centers,
                              ))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade400,
                                    Colors.green.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'distributors_feature.near_you'.tr(),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          // أيقونة للمحافظة فقط (بدون مركز مشترك)
                          else if (currentUser?.governorates != null &&
                                   LocationProximity.hasCommonGovernorate(
                                     userGovernorates: currentUser!.governorates!,
                                     distributorGovernorates: distributor.governorates,
                                   ))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_city,
                                    size: 10,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      'distributors_feature.same_governorate'.tr(),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // عداد المنتجات
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  size: 11,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'distributors_feature.product_count_value'.tr(
                                      namedArgs: {'count': distributor.productCount.toString()}),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // عداد المشتركين
                          if (subscribersCountLocal.value > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active_rounded,
                                    size: 11,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${subscribersCountLocal.value}',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // أيقونة الجرس للاشتراك
                // استخدام حالة الاشتراك من المزود
                Container(
                    width: 33,
                    height: 33,
                    decoration: BoxDecoration(
                      color: isSubscribed
                          ? theme.colorScheme.primary // لون صلب عند الاشتراك
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10), // تعديل الانحناء
                      border: isSubscribed
                          ? null
                          : Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                              width: 1,
                            ),
                    ),
                    child: IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero, // إزالة الحواشي ليتناسب مع الكونتينر الصغير
                      constraints: const BoxConstraints(), // إزالة القيود الافتراضية
                      icon: Icon(
                        isSubscribed
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded, // تغيير الأيقونة لتكون أجمل
                        color: isSubscribed
                            ? Colors.white // أيقونة بيضاء عند الاشتراك
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: isLoading.value
                          ? null
                          : () async {
                              isLoading.value = true;
                              // Toggle subscription
                              final success = await DistributorSubscriptionService
                                  .toggleSubscription(distributor.id);

                              if (success) {
                                // Refresh the provider to update UI
                                ref.invalidate(subscribedDistributorsIdsProvider);
                                
                                // تحديث العداد محلياً (Visual feedback)
                                if (!isSubscribed) {
                                  subscribersCountLocal.value++;
                                } else {
                                  if (subscribersCountLocal.value > 0) {
                                    subscribersCountLocal.value--;
                                  }
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        !isSubscribed
                                            ? 'distributors_feature.subscribed'.tr(namedArgs: {'name': distributor.displayName})
                                            : 'distributors_feature.unsubscribed'.tr(namedArgs: {'name': distributor.displayName}),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                              isLoading.value = false;
                            },
                      tooltip: isSubscribed
                          ? 'distributors_feature.unsubscribe_tooltip'.tr()
                          : 'distributors_feature.subscribe_tooltip'.tr(),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}