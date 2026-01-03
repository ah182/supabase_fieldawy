import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/core/caching/image_cache_manager.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/distributors/application/distributor_filters_provider.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/home/application/search_history_provider.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/home/presentation/mixins/search_tracking_mixin.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/quick_filters_bar.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/search_history_view.dart';
import 'package:fieldawy_store/services/distributor_subscription_service.dart';
import 'package:fieldawy_store/services/subscription_cache_service.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

final subscribedDistributorsIdsProvider = FutureProvider<Set<String>>((ref) async {
  await SubscriptionCacheService.init();
  final list = await DistributorSubscriptionService.getSubscribedDistributorIds();
  return list.toSet();
});

final distributorsProvider = FutureProvider<List<DistributorModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final cache = ref.watch(cachingServiceProvider);
  const cacheKey = 'distributors_edge';

  final networkFuture = NetworkGuard.execute(() async {
    return await supabase.functions.invoke('get-distributors');
  }).then((response) {
    if (response.data == null) {
      return <DistributorModel>[]; 
    }
    final List<dynamic> data = response.data;
    cache.set(cacheKey, data, duration: const Duration(minutes: 30));
    final result = data.map((d) => DistributorModel.fromMap(Map<String, dynamic>.from(d))).toList();
    return result;
  }).catchError((error) {
    return <DistributorModel>[];
  });

  final cached = cache.get<List<dynamic>>(cacheKey);
  if (cached != null) {
    return cached.map((data) => DistributorModel.fromMap(Map<String, dynamic>.from(data))).toList();
  }

  try {
    return await networkFuture;
  } catch (e) {
    return <DistributorModel>[];
  }
});

class DistributorsScreen extends ConsumerStatefulWidget {
  const DistributorsScreen({super.key});

  @override
  ConsumerState<DistributorsScreen> createState() => _DistributorsScreenState();
}

class _DistributorsScreenState extends ConsumerState<DistributorsScreen> with SearchTrackingMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  String _ghostText = '';
  String _fullSuggestion = '';
  Timer? _debounce;
  
  static const String _historyTabId = 'distributors';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {});
      if (_searchFocusNode.hasFocus) {
        HapticFeedback.selectionClick();
      } else {
        if (_searchController.text.isEmpty) {
          setState(() {
            _searchQuery = '';
            _ghostText = '';
            _fullSuggestion = '';
          });
        }
      }
    });

    // Sync subscriptions on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSubscriptions();
    });
  }

  Future<void> _syncSubscriptions() async {
    await SubscriptionCacheService.init();
    await DistributorSubscriptionService.syncSubscriptions();
    if (mounted) {
      ref.invalidate(subscribedDistributorsIdsProvider);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _hideKeyboard() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      HapticFeedback.lightImpact();
      if (_searchController.text.isEmpty) {
        setState(() {
          _ghostText = '';
          _fullSuggestion = '';
        });
      }
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _ghostText = '';
        _fullSuggestion = '';
      });
      return;
    }

    ref.read(distributorsProvider).whenData((distributors) {
      final filtered = distributors.where((distributor) {
        final displayName = distributor.displayName.toLowerCase();
        return displayName.startsWith(query.toLowerCase());
      }).toList();
      
      if (filtered.isNotEmpty) {
        final suggestion = filtered.first.displayName;
        setState(() {
          _ghostText = query + suggestion.substring(query.length);
          _fullSuggestion = suggestion;
        });
      } else {
        setState(() {
          _ghostText = '';
          _fullSuggestion = '';
        });
      }
    });
  }

  // --- Helper Methods for Dialogs ---

  void _showSearchHistoryDialog(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final history = ref.read(searchHistoryProvider)[_historyTabId] ?? [];
    
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'لا يوجد سجل بحث حالياً' : 'No search history available')),
      );
      return;
    }

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      alignment: const Alignment(0, -0.5),
      body: SearchHistoryView(
        tabId: _historyTabId,
        onClose: () => Navigator.pop(context),
        onTermSelected: (term) {
          _searchController.text = term;
          setState(() {
            _searchQuery = term;
            _debouncedSearchQuery = term;
          });
          ref.read(searchHistoryProvider.notifier).addSearchTerm(term, _historyTabId);
          Navigator.pop(context);
          _searchFocusNode.unfocus();
        },
      ),
    ).show();
  }

  void _showSearchFiltersDialog(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    
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
                  mainAxisSize: MainAxisSize.min,
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
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Consumer(
                      builder: (context, ref, child) {
                        final filters = ref.watch(distributorFiltersProvider);
                        final hasActiveFilters = filters.isNearest || filters.selectedGovernorate != null;
                        
                        if (!hasActiveFilters) return const SizedBox.shrink();
                        
                        return InkWell(
                          onTap: () {
                            ref.read(distributorFiltersProvider.notifier).resetFilters();
                          },
                          child: Text(
                            isAr ? 'مسح الكل' : 'Clear All',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 16),
            const QuickFiltersBar(showCheapest: false, useDistributorFilters: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).show();
  }

  Widget _buildSearchActionButton({
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    List<Color>? gradientColors,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: (isActive && gradientColors != null)
              ? LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive 
              ? (gradientColors == null ? color : null) 
              : (isDark ? Colors.white.withOpacity(0.08) : color.withOpacity(0.05)),
          boxShadow: isActive ? [
            BoxShadow(
              color: (gradientColors?.last ?? color).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ] : [],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive 
              ? Colors.white 
              : (isDark ? Colors.white70 : color.withOpacity(0.6)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distributorsAsync = ref.watch(distributorsProvider);
    final currentUserAsync = ref.watch(userDataProvider);
    final filters = ref.watch(distributorFiltersProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _hideKeyboard,
      child: MainScaffold(
        selectedIndex: 0,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                elevation: 0,
                centerTitle: true,
                backgroundColor: theme.colorScheme.surface,
                leading: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(20, 20),
                        painter: _ArrowBackPainter(color: Colors.black),
                      ),
                    ),
                  ),
                ),
                automaticallyImplyLeading: false, 
                title: Text(
                  'distributors_feature.title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(100), // Adjusted height for search bar only
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Row(
                          children: [
                            // Search Bar
                            Expanded(
                              child: Stack(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        ref.read(searchHistoryProvider.notifier).addSearchTerm(value, _historyTabId);
                                      }
                                      _searchFocusNode.unfocus();
                                    },
                                    onTap: () {
                                      if (!_searchFocusNode.hasFocus) {
                                        HapticFeedback.selectionClick();
                                      }
                                      if (_searchController.text.isNotEmpty) {
                                        _updateSuggestions(_searchController.text);
                                      }
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                      _debounce?.cancel();
                                      _debounce = Timer(const Duration(milliseconds: 300), () {
                                        setState(() {
                                          _debouncedSearchQuery = value;
                                        });
                                        _updateSuggestions(value);
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'distributors_feature.search_hint'.tr(),
                                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: _searchFocusNode.hasFocus 
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface.withOpacity(0.6),
                                        size: 22,
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                  _debouncedSearchQuery = '';
                                                  _ghostText = '';
                                                  _fullSuggestion = '';
                                                });
                                                HapticFeedback.lightImpact();
                                              },
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: theme.brightness == Brightness.dark
                                          ? theme.colorScheme.surface.withOpacity(0.8)
                                          : theme.colorScheme.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                  // Ghost Text
                                  if (_ghostText.isNotEmpty && _searchFocusNode.hasFocus)
                                    Positioned(
                                      top: 12,
                                      right: 37,
                                      child: AnimatedOpacity(
                                        opacity: _searchQuery.isNotEmpty ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: GestureDetector(
                                          onTap: () {
                                            if (_fullSuggestion.isNotEmpty) {
                                              _searchController.text = _fullSuggestion;
                                              setState(() {
                                                _searchQuery = _fullSuggestion;
                                                _debouncedSearchQuery = _fullSuggestion;
                                                _ghostText = '';
                                                _fullSuggestion = '';
                                              });
                                              ref.read(searchHistoryProvider.notifier).addSearchTerm(_searchController.text, _historyTabId);
                                              HapticFeedback.selectionClick();
                                              _searchFocusNode.requestFocus();
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.primary),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    _ghostText,
                                                    style: TextStyle(
                                                      color: theme.colorScheme.primary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Action Buttons (History & Filter)
                            const SizedBox(width: 8),
                            Consumer(
                              builder: (context, ref, child) {
                                final history = ref.watch(searchHistoryProvider)[_historyTabId] ?? [];
                                final isFilterActive = filters.isNearest || filters.selectedGovernorate != null;
                                final isHistoryActive = history.contains(_searchQuery) && _searchQuery.isNotEmpty;

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSearchActionButton(
                                      icon: Icons.history_rounded,
                                      color: Colors.indigo,
                                      isActive: isHistoryActive,
                                      gradientColors: [Colors.indigo, Colors.blueAccent],
                                      onTap: () => _showSearchHistoryDialog(context),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildSearchActionButton(
                                      icon: Icons.tune_rounded,
                                      color: Colors.teal,
                                      isActive: isFilterActive,
                                      gradientColors: [Colors.teal, Colors.cyan.shade600],
                                      onTap: () => _showSearchFiltersDialog(context),
                                    ),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: distributorsAsync.when(
            data: (distributors) {
              // 1. Filtering
              var filteredDistributors = distributors.where((distributor) {
                // Text Search
                if (_debouncedSearchQuery.isNotEmpty) {
                  final query = _debouncedSearchQuery.toLowerCase();
                  final matchesName = distributor.displayName.toLowerCase().contains(query) ||
                      (distributor.companyName?.toLowerCase().contains(query) ?? false) ||
                      (distributor.email?.toLowerCase().contains(query) ?? false);
                  if (!matchesName) return false;
                }
                
                // Governorate Filter
                if (filters.selectedGovernorate != null) {
                  final matchesGov = (distributor.governorates ?? []).contains(filters.selectedGovernorate);
                  if (!matchesGov) return false;
                }
                
                return true;
              }).toList();

              // 2. Sorting (Nearest)
              if (filters.isNearest) {
                final currentUser = currentUserAsync.asData?.value;
                if (currentUser != null) {
                  filteredDistributors = LocationProximity.sortByProximity<DistributorModel>(
                    items: filteredDistributors,
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
              }

              if (filteredDistributors.isEmpty) {
                return Center(
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
                      if (filters.selectedGovernorate != null || filters.isNearest)
                        TextButton(
                          onPressed: () => ref.read(distributorFiltersProvider.notifier).resetFilters(),
                          child: Text('إعادة تعيين الفلاتر'),
                        ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.refresh(distributorsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredDistributors.length,
                  itemBuilder: (context, index) {
                    final distributor = filteredDistributors[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: _buildDistributorCard(
                          context, theme, distributor, ref, null, _debouncedSearchQuery),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
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
                  Icons.inventory_2_rounded,
                  'distributors_feature.products_count'.tr(),
                  'distributors_feature.product_count_value'.tr(
                      namedArgs: {'count': distributor.productCount.toString()}),
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
}

// Widget منفصل للكارت مع state management محلي
class _DistributorCard extends ConsumerWidget {
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
    final subscribedIdsAsync = ref.watch(subscribedDistributorsIdsProvider);
    final isSubscribed = subscribedIdsAsync.asData?.value.contains(distributor.id) ?? false;

    // Local state for optimistic UI updates (using a StatefulWidget would be better for complex state, but here we trigger provider refresh)
    // Actually, converting to ConsumerStatefulWidget or HookConsumerWidget is cleaner if we need local state.
    // For simplicity, I'll rely on the provider refresh which should be fast enough.
    // To allow optimistic update, I need local state.
    // I'll make _DistributorCard Stateful.
    return _DistributorCardStateful(
      distributor: distributor,
      theme: theme,
      currentUser: currentUser,
      onShowDetails: onShowDetails,
      initialSubscribed: isSubscribed,
    );
  }
}

class _DistributorCardStateful extends ConsumerStatefulWidget {
  final DistributorModel distributor;
  final ThemeData theme;
  final UserModel? currentUser;
  final VoidCallback onShowDetails;
  final bool initialSubscribed;

  const _DistributorCardStateful({
    required this.distributor,
    required this.theme,
    required this.currentUser,
    required this.onShowDetails,
    required this.initialSubscribed,
  });

  @override
  ConsumerState<_DistributorCardStateful> createState() => _DistributorCardStatefulState();
}

class _DistributorCardStatefulState extends ConsumerState<_DistributorCardStateful> {
  late bool isSubscribed;
  late int subscribersCount;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    isSubscribed = widget.initialSubscribed;
    subscribersCount = widget.distributor.subscribersCount;
  }

  @override
  void didUpdateWidget(covariant _DistributorCardStateful oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubscribed != widget.initialSubscribed) {
      isSubscribed = widget.initialSubscribed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
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
          onTap: widget.onShowDetails,
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
                    color: widget.theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.distributor.photoURL != null &&
                            widget.distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.distributor.photoURL!,
                            cacheManager: CustomImageCacheManager(),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                color: widget.theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: ImageLoadingIndicator(size: 24),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: widget.theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 28,
                                color: widget.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: widget.theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: widget.theme.colorScheme.onSurfaceVariant,
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
                        widget.distributor.displayName,
                        style: widget.theme.textTheme.bodyLarge?.copyWith(
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
                          color: widget.theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.distributor.distributorType == 'company'
                                  ? Icons.business_rounded
                                  : Icons.person_outline_rounded,
                              size: 12,
                              color: widget.theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.distributor.companyName ??
                                    (widget.distributor.distributorType == 'company'
                                        ? 'distributors_feature.company'.tr()
                                        : 'distributors_feature.individual'.tr()),
                                style: widget.theme.textTheme.labelSmall?.copyWith(
                                  color: widget.theme.colorScheme.onSecondaryContainer,
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
                          if (widget.currentUser?.centers != null &&
                              LocationProximity.hasCommonCenter(
                                userCenters: widget.currentUser!.centers!,
                                distributorCenters: widget.distributor.centers,
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
                                      style: widget.theme.textTheme.labelSmall?.copyWith(
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
                          else if (widget.currentUser?.governorates != null &&
                                   LocationProximity.hasCommonGovernorate(
                                     userGovernorates: widget.currentUser!.governorates!,
                                     distributorGovernorates: widget.distributor.governorates,
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
                                      style: widget.theme.textTheme.labelSmall?.copyWith(
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
                              color: widget.theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  size: 11,
                                  color: widget.theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'distributors_feature.product_count_value'.tr(
                                      namedArgs: {'count': widget.distributor.productCount.toString()}),
                                  style: widget.theme.textTheme.labelMedium?.copyWith(
                                    color: widget.theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // عداد المشتركين
                          if (subscribersCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active_rounded,
                                    size: 11,
                                    color: widget.theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$subscribersCount',
                                    style: widget.theme.textTheme.labelMedium?.copyWith(
                                      color: widget.theme.colorScheme.primary,
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
                Container(
                    width: 33,
                    height: 33,
                    decoration: BoxDecoration(
                      color: isSubscribed
                          ? widget.theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSubscribed
                          ? null
                          : Border.all(
                              color: widget.theme.colorScheme.outline.withOpacity(0.3),
                              width: 1,
                            ),
                    ),
                    child: IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isSubscribed
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: isSubscribed
                            ? Colors.white
                            : widget.theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() {
                                isLoading = true;
                              });
                              // Toggle subscription
                              final success = await DistributorSubscriptionService
                                  .toggleSubscription(widget.distributor.id);

                              if (success) {
                                // Refresh the provider to update UI
                                ref.invalidate(subscribedDistributorsIdsProvider);
                                
                                setState(() {
                                  // Update local state for immediate feedback
                                  if (!isSubscribed) {
                                    isSubscribed = true;
                                    subscribersCount++;
                                  } else {
                                    isSubscribed = false;
                                    if (subscribersCount > 0) {
                                      subscribersCount--;
                                    }
                                  }
                                });

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        !isSubscribed // Logic inverted here because we already flipped local state? No, success means operation done.
                                            // Wait, if I flipped local state ABOVE, then isSubscribed reflects NEW state.
                                            // So if isSubscribed is true, it means I just subscribed.
                                            ? 'distributors_feature.unsubscribed'.tr(namedArgs: {'name': widget.distributor.displayName})
                                            : 'distributors_feature.subscribed'.tr(namedArgs: {'name': widget.distributor.displayName}),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                              setState(() {
                                isLoading = false;
                              });
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
                  color: widget.theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowBackPainter extends CustomPainter {
  final Color color;
  _ArrowBackPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Start from right (shaft)
    path.moveTo(size.width * 0.8, size.height / 2);
    // Draw to left
    path.lineTo(size.width * 0.2, size.height / 2);
    // Draw upper wing
    path.moveTo(size.width * 0.45, size.height * 0.25);
    path.lineTo(size.width * 0.2, size.height / 2);
    // Draw lower wing
    path.moveTo(size.width * 0.45, size.height * 0.75);
    path.lineTo(size.width * 0.2, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
