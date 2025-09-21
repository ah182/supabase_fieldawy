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

final distributorsProvider =
    FutureProvider<List<DistributorModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  const cacheKey = 'distributors';

  final cached = cache.get<List<DistributorModel>>(cacheKey);
  if (cached != null) return cached;

  final users = await supabase
      .from('users')
      .select()
      .or('role.eq.distributor,role.eq.company') // الشرط الأول OR
      .or('account_status.eq.approved,account_status.eq.pending_review') // الشرط الثاني OR
      .eq('is_profile_complete', true); // شرط AND

  if (users.isEmpty) return [];

  final distributorIds = users.map((u) => u['id'] as String).toList();

  final inList = '(${distributorIds.map((e) => '"$e"').join(',')})';
  final productRows = await supabase
      .from('distributor_products')
      .select('distributor_id')
      .filter('distributor_id', 'in', inList);

  final counts = <String, int>{};
  for (final row in productRows) {
    final id = row['distributor_id'] as String;
    counts[id] = (counts[id] ?? 0) + 1;
  }

  final result = users.map((u) {
    final id = u['id'] as String;
    return DistributorModel.fromMap({
      ...u,
      'productCount': counts[id] ?? 0,
      'distributorType': u['role'],
    });
  }).toList();

  cache.set(cacheKey, result);
  return result;
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
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Text(
        'distributors'.tr(),
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      pinned: true,
      floating: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: UnifiedSearchBar(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: (value) => searchQuery.value = value,
            onClear: () => searchQuery.value = '',
            hintText: 'searchDistributor'.tr(),
          ),
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
                  else ...[
                    SliverToBoxAdapter(
                      child: _buildStatsHeader(
                          context, theme, filteredDistributors),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final distributor = filteredDistributors[index];
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildDistributorCard(
                                context, theme, distributor),
                          );
                        },
                        childCount: filteredDistributors.length,
                      ),
                    ),
                  ]
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
                    padding: const EdgeInsets.only(
                        bottom: 16.0, left: 16.0, right: 16.0),
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

  // إحصائيات سريعة - badge صغير (عدد الموزعين فقط)
  Widget _buildStatsHeader(BuildContext context, ThemeData theme,
      List<DistributorModel> distributors) {
    final totalDistributors = distributors.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'showingAvailableDistributors'
                .tr(args: [totalDistributors.toString()]),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // كارت الموزع - مُصغر
  Widget _buildDistributorCard(
      BuildContext context, ThemeData theme, DistributorModel distributor) {
    final isCompany = distributor.distributorType == 'company';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 2,
        shadowColor: theme.shadowColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            _showDistributorDetails(context, theme, distributor);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: distributor.photoURL != null &&
                            distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: distributor.photoURL!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const ImageLoadingIndicator(size: 24),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 30),
                          )
                        : const Icon(Icons.person, size: 30),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distributor.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isCompany ? Icons.business : Icons.person_outline,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              distributor.companyName ??
                                  (isCompany
                                      ? 'distributionCompany'.tr()
                                      : 'individualDistributor'.tr()),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'productCount'.tr(
                                  args: [distributor.productCount.toString()]),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // عرض تفاصيل الموزع - تصميم جديد
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: distributor.photoURL != null &&
                            distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: distributor.photoURL!,
                            fit: BoxFit.contain,
                            placeholder: (context, url) =>
                                const ImageLoadingIndicator(size: 20),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 30),
                          )
                        : const Icon(Icons.person, size: 30),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  distributor.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
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
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDetailListTile(
                  theme,
                  Icons.email_outlined,
                  'email'.tr(),
                  distributor.email ?? 'notAvailable'.tr(),
                ),
                _buildDetailListTile(
                  theme,
                  Icons.inventory_2_outlined,
                  'numberOfProducts'.tr(),
                  'productCount'.tr(args: [distributor.productCount.toString()]),
                ),
                _buildDetailListTile(
                  theme,
                  Icons.business_outlined,
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
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text('viewProducts'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _openWhatsApp(context, distributor);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  child: const FaIcon(FontAwesomeIcons.whatsapp, size: 24),
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
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style:
              TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8))),
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
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'errorLoadingDistributors'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
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
            ElevatedButton.icon(
              onPressed: () {
                // إعادة تحميل البيانات
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.refresh),
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
              Icons.people_alt_outlined,
              size: 80,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'noDistributorsFound'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
              Icons.search_off,
              size: 80,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'noSearchResults'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      ),
      child: Row(
        children: [
          ShimmerLoader(width: 60, height: 60, isCircular: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoader(width: 150, height: 16),
                const SizedBox(height: 8),
                ShimmerLoader(width: 100, height: 12),
                const SizedBox(height: 8),
                ShimmerLoader(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
