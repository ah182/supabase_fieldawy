import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/notifications/data/notification_preferences_repository.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/notifications/application/notification_preferences_provider.dart';
import 'package:fieldawy_store/services/distributor_subscription_service.dart';
// ignore: unnecessary_import
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _priceActionEnabled = true;
  bool _expireSoonEnabled = true;
  bool _offersEnabled = true;
  bool _surgicalToolsEnabled = true;
  bool _booksEnabled = true;
  bool _coursesEnabled = true;
  bool _jobOffersEnabled = true;
  bool _vetSuppliesEnabled = true;

  late TabController _tabController;
  List<Map<String, dynamic>> _subscribedDistributors = [];
  bool _isLoadingDistributors = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPreferences();
    _loadSubscribedDistributors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      // استخدام Repository مع الكاش
      final repository = ref.read(notificationPreferencesRepositoryProvider);
      final prefs = await repository.getPreferences();
      
      setState(() {
        _priceActionEnabled = prefs['price_action'] ?? true;
        _expireSoonEnabled = prefs['expire_soon'] ?? true;
        _offersEnabled = prefs['offers'] ?? true;
        _surgicalToolsEnabled = prefs['surgical_tools'] ?? true;
        _booksEnabled = prefs['books'] ?? true;
        _coursesEnabled = prefs['courses'] ?? true;
        _jobOffersEnabled = prefs['job_offers'] ?? true;
        _vetSuppliesEnabled = prefs['vet_supplies'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notifications_feature.load_error'.tr())),
        );
      }
    }
  }

  Future<void> _loadSubscribedDistributors() async {
    setState(() => _isLoadingDistributors = true);
    try {
      // استخدام Repository مع الكاش
      final repository = ref.read(notificationPreferencesRepositoryProvider);
      final distributors = await repository.getSubscribedDistributors();
      
      print('📦 Loaded ${distributors.length} subscribed distributors from cache');
      
      setState(() {
        _subscribedDistributors = distributors.map((d) => {
          'distributor_id': d.id,
          'distributor_model': d,
        }).toList();
        _isLoadingDistributors = false;
      });
    } catch (e) {
      print('❌ Error in _loadSubscribedDistributors: $e');
      setState(() => _isLoadingDistributors = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notifications_feature.distributors_error'.tr())),
        );
      }
    }
  }

  Future<void> _updatePreference(String type, bool value) async {
    try {
      // استخدام Repository مع invalidation
      final repository = ref.read(notificationPreferencesRepositoryProvider);
      await repository.updatePreference(type, value);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('notifications_feature.save_success'.tr()),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notifications_feature.save_error'.tr())),
        );
      }
      // Revert the change
      await _loadPreferences();
    }
  }

  Future<void> _unsubscribeFromDistributor(String distributorId, String distributorName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('notifications_feature.unsubscribe_confirm_title'.tr()),
        content: Text('notifications_feature.unsubscribe_confirm_msg'.tr(namedArgs: {'name': distributorName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('notifications_feature.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('notifications_feature.confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await DistributorSubscriptionService.unsubscribe(distributorId);
        if (success && mounted) {
          // Invalidate cache بعد إلغاء الاشتراك
          final repository = ref.read(notificationPreferencesRepositoryProvider);
          repository.invalidateCache();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('notifications_feature.unsubscribe_success'.tr()),
              duration: const Duration(seconds: 2),
            ),
          );
          await _loadSubscribedDistributors();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('notifications_feature.unsubscribe_failed'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('notifications_feature.generic_error'.tr())),
                  );        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('notifications_feature.title'.tr()),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.notifications_rounded),
              text: 'notifications_feature.general_tab'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.people_rounded),
              text: 'notifications_feature.distributors_tab'.tr(),
            ),
          ],
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // General Notifications Tab
          _buildGeneralNotificationsTab(colorScheme, textTheme),
          // Subscribed Distributors Tab
          _buildSubscribedDistributorsTab(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildGeneralNotificationsTab(ColorScheme colorScheme, TextTheme textTheme) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'notifications_feature.choose_types'.tr(),
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Price Action Toggle
                _buildNotificationToggle(
                  icon: Icons.monetization_on_rounded,
                  iconColor: Colors.green,
                  title: 'notifications_feature.types.price_action'.tr(),
                  subtitle: 'notifications_feature.types.price_action_desc'.tr(),
                  value: _priceActionEnabled,
                  onChanged: (value) {
                    setState(() => _priceActionEnabled = value);
                    _updatePreference('price_action', value);
                  },
                ),

                const SizedBox(height: 12),

                // Expire Soon Toggle
                _buildNotificationToggle(
                  icon: Icons.warning_rounded,
                  iconColor: Colors.orange,
                  title: 'notifications_feature.types.expire_soon'.tr(),
                  subtitle: 'notifications_feature.types.expire_soon_desc'.tr(),
                  value: _expireSoonEnabled,
                  onChanged: (value) {
                    setState(() => _expireSoonEnabled = value);
                    _updatePreference('expire_soon', value);
                  },
                ),

                const SizedBox(height: 12),

                // Offers Toggle
                _buildNotificationToggle(
                  icon: Icons.local_offer_rounded,
                  iconColor: Colors.red,
                  title: 'notifications_feature.types.offers'.tr(),
                  subtitle: 'notifications_feature.types.offers_desc'.tr(),
                  value: _offersEnabled,
                  onChanged: (value) {
                    setState(() => _offersEnabled = value);
                    _updatePreference('offers', value);
                  },
                ),

                const SizedBox(height: 12),

                // Surgical Tools Toggle
                _buildNotificationToggle(
                  icon: Icons.medical_services_rounded,
                  iconColor: Colors.blue,
                  title: 'notifications_feature.types.surgical_tools'.tr(),
                  subtitle: 'notifications_feature.types.surgical_tools_desc'.tr(),
                  value: _surgicalToolsEnabled,
                  onChanged: (value) {
                    setState(() => _surgicalToolsEnabled = value);
                    _updatePreference('surgical_tools', value);
                  },
                ),

                const SizedBox(height: 12),

                // Books Toggle
                _buildNotificationToggle(
                  icon: Icons.book_rounded,
                  iconColor: Colors.purple,
                  title: 'notifications_feature.types.books'.tr(),
                  subtitle: 'notifications_feature.types.books_desc'.tr(),
                  value: _booksEnabled,
                  onChanged: (value) {
                    setState(() => _booksEnabled = value);
                    _updatePreference('books', value);
                  },
                ),

                const SizedBox(height: 12),

                // Courses Toggle
                _buildNotificationToggle(
                  icon: Icons.school_rounded,
                  iconColor: Colors.teal,
                  title: 'notifications_feature.types.courses'.tr(),
                  subtitle: 'notifications_feature.types.courses_desc'.tr(),
                  value: _coursesEnabled,
                  onChanged: (value) {
                    setState(() => _coursesEnabled = value);
                    _updatePreference('courses', value);
                  },
                ),

                const SizedBox(height: 12),

                // Job Offers Toggle
                _buildNotificationToggle(
                  icon: Icons.work_rounded,
                  iconColor: Colors.indigo,
                  title: 'notifications_feature.types.job_offers'.tr(),
                  subtitle: 'notifications_feature.types.job_offers_desc'.tr(),
                  value: _jobOffersEnabled,
                  onChanged: (value) {
                    setState(() => _jobOffersEnabled = value);
                    _updatePreference('job_offers', value);
                  },
                ),

                const SizedBox(height: 12),

                // Vet Supplies Toggle
                _buildNotificationToggle(
                  icon: Icons.medical_services_outlined,
                  iconColor: Colors.cyan,
                  title: 'notifications_feature.types.vet_supplies'.tr(),
                  subtitle: 'notifications_feature.types.vet_supplies_desc'.tr(),
                  value: _vetSuppliesEnabled,
                  onChanged: (value) {
                    setState(() => _vetSuppliesEnabled = value);
                    _updatePreference('vet_supplies', value);
                  },
                ),

                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'notifications_feature.info_text'.tr(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
  }

  Widget _buildSubscribedDistributorsTab(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoadingDistributors) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_subscribedDistributors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 80,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'notifications_feature.no_subscriptions'.tr(),
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'notifications_feature.subscribe_hint'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currentUser = ref.watch(userDataProvider).asData?.value;

    return RefreshIndicator(
      onRefresh: _loadSubscribedDistributors,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        itemCount: _subscribedDistributors.length,
        itemBuilder: (context, index) {
          final distributorData = _subscribedDistributors[index];
          final distributor = distributorData['distributor_model'] as DistributorModel;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildDistributorCard(
              colorScheme,
              textTheme,
              distributor,
              currentUser,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDistributorCard(
    ColorScheme colorScheme,
    TextTheme textTheme,
    DistributorModel distributor,
    UserModel? currentUser,
  ) {
    final isCompany = distributor.distributorType == 'company';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
          onTap: () => _showDistributorDetails(context, colorScheme, textTheme, distributor),
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
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: distributor.photoURL != null && distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: distributor.photoURL!,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: ImageLoadingIndicator(size: 24),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 28,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: colorScheme.onSurfaceVariant,
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
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompany ? Icons.business_rounded : Icons.person_outline_rounded,
                              size: 12,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distributor.companyName ??
                                  (isCompany ? 'distributionCompany'.tr() : 'individualDistributor'.tr()),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // المؤشرات البصرية
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade400, Colors.green.shade600],
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
                                  const Icon(Icons.location_on, size: 11, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    'قريب منك',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (currentUser?.governorates != null &&
                              LocationProximity.hasCommonGovernorate(
                                userGovernorates: currentUser!.governorates!,
                                distributorGovernorates: distributor.governorates,
                              ))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade300, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_city, size: 10, color: Colors.blue.shade700),
                                  const SizedBox(width: 2),
                                  Text(
                                    'نفس المحافظة',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // عداد المنتجات
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  size: 11,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'productCount'.tr(args: [distributor.productCount.toString()]),
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
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
                // أيقونة إلغاء الاشتراك
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    icon: Icon(
                      Icons.notifications_off_outlined,
                      color: colorScheme.error,
                    ),
                    onPressed: () => _unsubscribeFromDistributor(
                      distributor.id,
                      distributor.displayName,
                    ),
                    tooltip: 'إلغاء الاشتراك في الإشعارات',
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDistributorDetails(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    DistributorModel distributor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: distributor.photoURL != null && distributor.photoURL!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: distributor.photoURL!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) =>
                                  const Center(child: ImageLoadingIndicator(size: 32)),
                              errorWidget: (context, url, error) => Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    distributor.displayName,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (distributor.companyName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        distributor.companyName!,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outline.withOpacity(0.2)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDetailListTile(
                    colorScheme,
                    textTheme,
                    Icons.email_rounded,
                    'email'.tr(),
                    distributor.email ?? 'notAvailable'.tr(),
                  ),
                  _buildDetailListTile(
                    colorScheme,
                    textTheme,
                    Icons.inventory_2_rounded,
                    'numberOfProducts'.tr(),
                    'productCount'.tr(args: [distributor.productCount.toString()]),
                  ),
                  _buildDetailListTile(
                    colorScheme,
                    textTheme,
                    Icons.business_rounded,
                    'distributorType'.tr(),
                    distributor.distributorType == 'company'
                        ? 'distributionCompany'.tr()
                        : 'individualDistributor'.tr(),
                  ),
                  if (distributor.whatsappNumber != null && distributor.whatsappNumber!.isNotEmpty)
                    _buildDetailListTile(
                      colorScheme,
                      textTheme,
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
                            builder: (context) => DistributorProductsScreen(distributor: distributor),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2_rounded, size: 18),
                      label: Text('viewProducts'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailListTile(
    ColorScheme colorScheme,
    TextTheme textTheme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context, DistributorModel distributor) async {
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

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final message = Uri.encodeComponent('whatsappInquiry'.tr());
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

  Widget _buildNotificationToggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
