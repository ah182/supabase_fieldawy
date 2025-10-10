import 'package:fieldawy_store/core/caching/caching_service.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
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
import 'package:fieldawy_store/widgets/unified_search_bar.dart';
import 'package:fieldawy_store/services/distributor_subscription_service.dart';

final distributorsProvider =
    FutureProvider<List<DistributorModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  const cacheKey = 'distributors_edge';

  // Stale-While-Revalidate Logic
  // 1. Start the network fetch immediately, but don't wait for it.
  final networkFuture = supabase.functions.invoke('get-distributors').then((response) {
    if (response.data == null) {
      // If the network fails, we can choose to simply log it and rely on the old cache
      // or throw an error to be caught elsewhere.
      print('Failed to fetch fresh distributors');
      // Silently fail to avoid breaking the UI if stale data is already shown
      return <DistributorModel>[]; 
    }
    final List<dynamic> data = response.data;
    // Update the cache for the next visit
    cache.set(cacheKey, data, duration: const Duration(minutes: 30));
    // Parse and return the fresh data
    final result = data.map((d) => DistributorModel.fromMap(Map<String, dynamic>.from(d))).toList();
    return result;
  });

  // 2. Check the local cache for stale data.
  final cached = cache.get<List<dynamic>>(cacheKey);
  if (cached != null) {
    // If we have stale data, return it immediately.
    // The networkFuture will continue in the background and update the cache for the next visit.
    return cached.map((data) => DistributorModel.fromMap(Map<String, dynamic>.from(data))).toList();
  }

  // 3. If there's no cached data, we have to wait for the network to complete.
  return await networkFuture;
});

class DistributorsScreen extends HookConsumerWidget {
  const DistributorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final distributorsAsync = ref.watch(distributorsProvider);
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();

    final filteredDistributors = useMemoized(
      () {
        final distributors = distributorsAsync.asData?.value;
        if (distributors == null) {
          return <DistributorModel>[];
        }
        if (searchQuery.value.isEmpty) {
          return distributors;
        }
        return distributors.where((distributor) {
          final query = searchQuery.value.toLowerCase();
          return distributor.displayName.toLowerCase().contains(query) ||
              (distributor.companyName?.toLowerCase().contains(query) ??
                  false) ||
              (distributor.email?.toLowerCase().contains(query) ?? false);
        }).toList();
      },
      [distributorsAsync, searchQuery.value],
    );

    
final sliverAppBar = SliverAppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0), // تنزيل العنوان للأسفل
        child: Text(
          'distributors'.tr(),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16.0, 12.0, 16.0, 8.0), // مسافات أفضل
              child: UnifiedSearchBar(
                controller: searchController,
                focusNode: searchFocusNode,
                onChanged: (value) => searchQuery.value = value,
                onClear: () => searchQuery.value = '',
                hintText: 'searchDistributor'.tr(),
              ),
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
                      final filteredCount = searchQuery.value.isEmpty
                          ? totalCount
                          : filteredDistributors.length;

                      return Text(
                        searchQuery.value.isEmpty
                            ? 'إجمالي الموزعين: $totalCount'
                            : 'عرض $filteredCount من $totalCount موزع',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                    loading: () => Text(
                      'جارٍ العد...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    error: (_, __) => Text(
                      'خطأ في العد',
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

    return GestureDetector(
      onTap: () {
        searchFocusNode.unfocus();
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
                      searchQuery.value.isNotEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildNoSearchResults(
                          context, theme, searchQuery.value),
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
                                context, theme, distributor),
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
                  (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
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
                child: _buildErrorState(context, theme, error.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // كارت الموزع المحسن
  Widget _buildDistributorCard(
      BuildContext context, ThemeData theme, DistributorModel distributor) {
    return _DistributorCard(
      key: ValueKey(distributor.id),
      distributor: distributor,
      theme: theme,
      onShowDetails: () => _showDistributorDetails(context, theme, distributor),
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
                            fit: BoxFit.cover,
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
                  'email'.tr(),
                  distributor.email ?? 'notAvailable'.tr(),
                ),
                _buildDetailListTile(
                  theme,
                  Icons.inventory_2_rounded,
                  'numberOfProducts'.tr(),
                  'productCount'
                      .tr(args: [distributor.productCount.toString()]),
                ),
                _buildDetailListTile(
                  theme,
                  Icons.business_rounded,
                  'distributorType'.tr(),
                  distributor.distributorType == 'company'
                      ? 'distributionCompany'.tr()
                      : 'individualDistributor'.tr(),
                ),
                if (distributor.whatsappNumber != null &&
                    distributor.whatsappNumber!.isNotEmpty)
                  _buildDetailListTile(
                    theme,
                    FontAwesomeIcons.whatsapp,
                    'whatsapp'.tr(),
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
                    label: Text('viewProducts'.tr()),
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
          content: Text('phoneNumberNotAvailable'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // إزالة أي رموز غير ضرورية من رقم الهاتف
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // رسالة افتراضية
    final message = Uri.encodeComponent('whatsappInquiry'.tr());

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
          content: Text('couldNotOpenWhatsApp'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'ok'.tr(),
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // حالة الخطأ
  Widget _buildErrorState(BuildContext context, ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'errorLoadingDistributors'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // إعادة تحميل البيانات
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('retry'.tr()),
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
              'noDistributorsFound'.tr(),
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
              'noSearchResults'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'noResultsFor'.tr(args: [query]),
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
class _DistributorCard extends HookWidget {
  final DistributorModel distributor;
  final ThemeData theme;
  final VoidCallback onShowDetails;

  const _DistributorCard({
    super.key,
    required this.distributor,
    required this.theme,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isCompany = distributor.distributorType == 'company';
    final isSubscribed = useState<bool?>(null);
    final isLoading = useState(false);

    // Load initial subscription state
    useEffect(() {
      Future<void> loadSubscription() async {
        final subscribed = await DistributorSubscriptionService.isSubscribed(distributor.id);
        isSubscribed.value = subscribed;
      }
      loadSubscription();
      return null;
    }, []);

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
                            fit: BoxFit.cover,
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
                            Text(
                              distributor.companyName ??
                                  (isCompany
                                      ? 'distributionCompany'.tr()
                                      : 'individualDistributor'.tr()),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 12,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'productCount'.tr(
                                  args: [distributor.productCount.toString()]),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // أيقونة الجرس للاشتراك
                if (isSubscribed.value != null)
                  Container(
                    decoration: BoxDecoration(
                      color: isSubscribed.value!
                          ? theme.colorScheme.primary.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSubscribed.value!
                          ? null
                          : Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                              width: 1,
                            ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isSubscribed.value!
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_outlined,
                        size: 22,
                        color: isSubscribed.value!
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: isLoading.value
                          ? null
                          : () async {
                              isLoading.value = true;
                              final success = await DistributorSubscriptionService
                                  .toggleSubscription(distributor.id);

                              if (success && context.mounted) {
                                isSubscribed.value = !isSubscribed.value!;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isSubscribed.value!
                                          ? 'تم الاشتراك في إشعارات ${distributor.displayName}'
                                          : 'تم إلغاء الاشتراك في إشعارات ${distributor.displayName}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                              isLoading.value = false;
                            },
                      tooltip: isSubscribed.value!
                          ? 'إلغاء الاشتراك في الإشعارات'
                          : 'الاشتراك في الإشعارات',
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
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
