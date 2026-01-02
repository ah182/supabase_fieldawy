import 'package:fieldawy_store/features/leaderboard/application/spin_wheel_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/leaderboard/application/leaderboard_provider.dart';
import 'package:fieldawy_store/features/leaderboard/presentation/screens/fortune_wheel_screen.dart';
import 'package:fieldawy_store/features/leaderboard/presentation/screens/referral_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/settings/presentation/screens/settings_screen.dart';

// Added Imports
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/search_history_view.dart';
import 'package:fieldawy_store/features/home/application/search_history_provider.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/quick_filters_bar.dart';
import 'package:fieldawy_store/features/leaderboard/application/leaderboard_filters_provider.dart';
import 'package:fieldawy_store/core/utils/location_proximity.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  String _ghostText = '';
  String _fullSuggestion = '';
  Timer? _debounce;
  bool _hasShownRules = false;
  
  static const String _historyTabId = 'leaderboard';

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

    final leaderboardData = ref.read(leaderboardProvider);
    if (leaderboardData is AsyncData<List<UserModel>>) {
      final users = leaderboardData.value;
      final filtered = users.where((user) {
        final displayName = (user.displayName ?? '').toLowerCase();
        return displayName.startsWith(query.toLowerCase());
      }).toList();
      
      if (filtered.isNotEmpty) {
        final suggestion = filtered.first.displayName ?? '';
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
    }
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
                        final filters = ref.watch(leaderboardFiltersProvider);
                        final hasActiveFilters = filters.selectedGovernorate != null; 
                        
                        if (!hasActiveFilters) return const SizedBox.shrink();
                        
                        return InkWell(
                          onTap: () {
                            ref.read(leaderboardFiltersProvider.notifier).resetFilters();
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
            const QuickFiltersBar(showCheapest: false, useLeaderboardFilters: true),
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
    final seasonAsync = ref.watch(currentSeasonProvider);
    final leaderboardData = ref.watch(leaderboardProvider);
    final userDataAsync = ref.watch(userDataProvider);
    final wasInvitedAsync = ref.watch(wasInvitedProvider);
    final theme = Theme.of(context);
    final currentUserId = ref.watch(authStateChangesProvider).asData?.value?.id;
    final filters = ref.watch(leaderboardFiltersProvider);

    // Logic to show rules dialog once when referral code is available
    final referralCode = userDataAsync.asData?.value?.referralCode;
    if (referralCode != null && !_hasShownRules) {
      _hasShownRules = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLeaderboardRulesDialog(context, referralCode);
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _hideKeyboard,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                floating: false, // Make it static
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
                  'leaderboard_feature.title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  wasInvitedAsync.when(
                    data: (wasInvited) => !wasInvited 
                        ? IconButton(
                            icon: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: theme.colorScheme.secondary,
                              size: 22,
                            ),
                            tooltip: 'Enter Referral Code',
                            onPressed: () => _showEnterReferralCodeDialog(context, ref),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  IconButton(
                    onPressed: () {
                      final referralCode = userDataAsync.asData?.value?.referralCode;
                      _showLeaderboardRulesDialog(context, referralCode);
                    },
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.secondary,
                      size: 22,
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(65),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                      hintText: 'leaderboard_feature.search_hint'.tr(),
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
                                final isFilterActive = filters.selectedGovernorate != null || filters.isNearest;
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
          body: leaderboardData.when(
            skipLoadingOnRefresh: true,
            data: (users) {
              // 1. Filtering
              var displayUsers = users.where((user) {
                // Text Search
                if (_debouncedSearchQuery.isNotEmpty) {
                  final query = _debouncedSearchQuery.toLowerCase();
                  final matchesName = (user.displayName ?? '').toLowerCase().contains(query) ||
                                      (user.email ?? '').toLowerCase().contains(query);
                  if (!matchesName) return false;
                }
                
                // Governorate Filter
                if (filters.selectedGovernorate != null) {
                  final userGovs = user.governorates ?? [];
                  if (!userGovs.contains(filters.selectedGovernorate)) return false;
                }
                
                return true;
              }).toList();

              // 2. Sorting (Nearest)
              if (filters.isNearest) {
                final currentUser = userDataAsync.asData?.value;
                if (currentUser != null) {
                  displayUsers = LocationProximity.sortByProximity<UserModel>(
                    items: displayUsers,
                    getProximityScore: (user) {
                      return LocationProximity.calculateProximityScore(
                        userGovernorates: currentUser.governorates,
                        userCenters: currentUser.centers,
                        distributorGovernorates: user.governorates,
                        distributorCenters: user.centers,
                      );
                    },
                  );
                }
              }
              
              if (displayUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        size: 80,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'leaderboard_feature.no_results'.tr(namedArgs: {'query': _debouncedSearchQuery}),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (filters.selectedGovernorate != null)
                        TextButton(
                          onPressed: () => ref.read(leaderboardFiltersProvider.notifier).resetFilters(),
                          child: Text('إعادة تعيين الفلاتر'),
                        ),
                    ],
                  ),
                );
              }
              
              return RefreshIndicator(
                edgeOffset: 8,
                displacement: 32,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                onRefresh: () async {
                  ref.invalidate(leaderboardProvider);
                  ref.invalidate(currentSeasonProvider);
                  await ref.read(leaderboardProvider.future);
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: seasonAsync.when(
                        data: (season) => season == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: _CountdownTimer(endDate: season.endDate),
                              ),
                        loading: () => const SizedBox(
                          height: 72,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (e, st) => const SizedBox.shrink(),
                      ),
                    ),
                    // Current User Card
                    SliverToBoxAdapter(
                      child: () {
                        final currentUserInList = displayUsers.where((u) => u.id == currentUserId).firstOrNull;
                        if (currentUserInList == null) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _buildCurrentUserCard(context, currentUserInList),
                        );
                      }(),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0 && displayUsers.length >= 3) {
                              return _buildPodium(context, displayUsers.take(3).toList());
                            }

                            final actualIndex =
                                displayUsers.length >= 3 ? index + 2 : index;
                            if (actualIndex >= displayUsers.length) {
                              return const SizedBox.shrink();
                            }

                            final user = displayUsers[actualIndex];
                            final rank = user.rank ?? (actualIndex + 1);

                            if (rank <= 3 && displayUsers.length < 3) {
                              return _buildTopRankerCard(context, user, rank);
                            } else if (rank == 4 || rank == 5) {
                              return _buildSpecialRankerTile(context, user, rank);
                            } else {
                              return _buildRegularRankerTile(context, user, rank);
                            }
                          },
                          childCount: displayUsers.length >= 3
                              ? displayUsers.length - 3 + 1
                              : displayUsers.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
        floatingActionButton: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFAB47BC),
                        const Color(0xFF8E24AA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 176, 39, 155).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showRewardsBottomSheet(context),
                      borderRadius: BorderRadius.circular(16),
                      child:  Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.card_giftcard,
                              color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'leaderboard_feature.rewards'.tr(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final availabilityAsync = ref.watch(spinWheelAvailabilityProvider);
                    return availabilityAsync.when(
                      loading: () => const SizedBox(height: 52),
                      error: (err, stack) => const SizedBox.shrink(), // Or show an error
                      data: (details) {
                        final bool isAvailable = details.availability == SpinWheelAvailability.available;
                        return Opacity(
                          opacity: isAvailable ? 1.0 : 0.6,
                          child: Container(
                            height: 52,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFFCA28),
                                  const Color(0xFFFB8C00),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                if (isAvailable)
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isAvailable
                                    ? () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const FortuneWheelScreen(),
                                          ),
                                        );
                                        ref.invalidate(spinWheelAvailabilityProvider);
                                      }
                                    : () async {
                                        String title = 'leaderboard_feature.spin_wheel_status.unavailable'.tr();
                                        String message = 'leaderboard_feature.spin_wheel_status.unavailable_msg'.tr();
                                        switch (details.availability) {
                                          case SpinWheelAvailability.notWinner:
                                            title = 'leaderboard_feature.spin_wheel_status.not_qualified'.tr();
                                            message = 'leaderboard_feature.spin_wheel_status.not_qualified_msg'.tr();
                                            break;
                                          case SpinWheelAvailability.windowClosed:
                                            title = 'leaderboard_feature.spin_wheel_status.window_closed'.tr();
                                            message = 'leaderboard_feature.spin_wheel_status.window_closed_msg'.tr();
                                            break;
                                          case SpinWheelAvailability.alreadyClaimed:
                                            title = 'leaderboard_feature.spin_wheel_status.already_claimed'.tr();
                                            message = 'leaderboard_feature.spin_wheel_status.already_claimed_msg'.tr() + 
                                                      '\n\n' + 
                                                      'leaderboard_feature.spin_wheel_status.claimed_details'.tr(namedArgs: {
                                                        'prize': details.claimedPrize ?? '',
                                                        'rank': (details.rank ?? '').toString()
                                                      });
                                            break;
                                          default:
                                            break;
                                        }
                                        await _showInfoDialog(
                                          context,
                                          title: title,
                                          message: message,
                                        );
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isAvailable
                                          ? Icons.casino
                                          : Icons.lock_outline,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'leaderboard_feature.spin_wheel'.tr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Future<void> _showInfoDialog(
    BuildContext context,
    {
    required String title,
    required String message,
  } ) async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: theme.textTheme.bodyLarge),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('leaderboard_feature.actions.ok'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnterReferralCodeDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => const ReferralEntryDialog(),
    );
  }

  Future<void> _showLeaderboardRulesDialog(BuildContext context, String? referralCode) async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'leaderboard_feature.info.title'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'leaderboard_feature.info.referral_code'.tr(),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        if (referralCode != null) {
                          Clipboard.setData(ClipboardData(text: referralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('leaderboard_feature.info.code_copied'.tr())),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            style: BorderStyle.values[1], // dashed logic simplified
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              referralCode ?? 'جاري التحميل...',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.copy,
                                size: 16, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'leaderboard_feature.info.referral_bonus_prefix'.tr(),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              'leaderboard_feature.info.settings_page_link'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              _buildRuleItem(
                context,
                Icons.person_add_alt_1_rounded,
                'leaderboard_feature.info.rules_title'.tr(),
                [
                  'leaderboard_feature.info.rule_1'.tr(),
                  'leaderboard_feature.info.rule_2'.tr(),
                ],
              ),
              const SizedBox(height: 16),
              _buildRuleItem(
                context,
                Icons.update_rounded,
                'leaderboard_feature.info.season_renewal_title'.tr(),
                [
                  'leaderboard_feature.info.season_renewal_rule_1'.tr(),
                  'leaderboard_feature.info.season_renewal_rule_2'.tr(),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('leaderboard_feature.actions.ok'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, IconData icon, String title,
      List<String> points) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...points.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: CircleAvatar(
                      radius: 2,
                      backgroundColor: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  void _showRewardsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) =>
            _RewardsInfoSheet(scrollController: scrollController),
      ),
    );
  }

  Widget _buildPodium(BuildContext context, List<UserModel> topThree) {
    final theme = Theme.of(context);

    if (topThree.length < 3) return const SizedBox.shrink();

    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Colors.amber[700],
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'leaderboard_feature.top_champions'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildPodiumPosition(
                  context,
                  second,
                  2,
                  Colors.grey[400]!,
                  140,
                ),
              ),
              Expanded(
                child: _buildPodiumPosition(
                  context,
                  first,
                  1,
                  Colors.amber[400]!,
                  180,
                ),
              ),
              Expanded(
                child: _buildPodiumPosition(
                  context,
                  third,
                  3,
                  const Color(0xFFCD7F32),
                  120,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition(
    BuildContext context,
    UserModel user,
    int rank,
    Color color,
    double height,
  ) {
    final theme = Theme.of(context);
    final avatarSize = rank == 1 ? 70.0 : 60.0;
    final iconSize = rank == 1 ? 32.0 : 28.0;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: rank == 1 ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? Icon(Icons.person, size: avatarSize / 2)
                    : null,
              ),
            ),
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Icon(
                Icons.emoji_events,
                color: color,
                size: iconSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            user.displayName ?? 'No Name',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: rank == 1 ? FontWeight.bold : FontWeight.w600,
              fontSize: rank == 1 ? 14 : 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${user.points ?? 0}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.4),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: rank == 1 ? 36 : 28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentUserCard(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final rank = user.rank ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 22, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: Colors.amber[300],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'leaderboard_feature.your_rank'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${user.points ?? 0}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'leaderboard_feature.points'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 9,
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

  Widget _buildTopRankerCard(BuildContext context, UserModel user, int rank) {
    final theme = Theme.of(context);
    final colors = [
      Colors.amber[400]!,
      Colors.grey[400]!,
      const Color(0xFFCD7F32),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[rank - 1].withOpacity(0.15),
            colors[rank - 1].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors[rank - 1].withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors[rank - 1].withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors[rank - 1],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors[rank - 1],
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: colors[rank - 1],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${user.points ?? 0} ${'leaderboard_feature.points'.tr()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors[rank - 1].withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${user.points ?? 0}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors[rank - 1],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularRankerTile(
      BuildContext context, UserModel user, int rank) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 22)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${user.points ?? 0} ${'leaderboard_feature.points'.tr()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${user.points ?? 0}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialRankerTile(
      BuildContext context, UserModel user, int rank) {
    final theme = Theme.of(context);
    final color = Colors.blue[400]!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 22)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${user.points ?? 0} ${'leaderboard_feature.points'.tr()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${user.points ?? 0}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime endDate;
  const _CountdownTimer({required this.endDate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remaining = _computeRemaining();
        });
      }
    });
  }

  Duration _computeRemaining() {
    final now = DateTime.now().toUtc();
    final end = widget.endDate.toUtc();
    final diff = end.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 87, 142, 194),
            const Color.fromARGB(255, 36, 119, 170),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 39, 121, 176).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'leaderboard_feature.season_ends_in'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _timeBox(context, '$days', 'leaderboard_feature.time_units.days'.tr()),
              _timeSeparator(),
              _timeBox(context, _two(hours), 'leaderboard_feature.time_units.hours'.tr()),
              _timeSeparator(),
              _timeBox(context, _two(minutes), 'leaderboard_feature.time_units.min'.tr()),
              _timeSeparator(),
              _timeBox(context, _two(seconds), 'leaderboard_feature.time_units.sec'.tr()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RewardsInfoSheet extends StatelessWidget {
  final ScrollController scrollController;
  const _RewardsInfoSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber[400]!, Colors.orange[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'leaderboard_feature.rewards_sheet.title'.tr(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'leaderboard_feature.rewards_sheet.subtitle'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _RewardTierCard(
                  rank: 'leaderboard_feature.ranks.first'.tr(),
                  rankIcon: '🥇',
                  color: Colors.amber,
                  rewards: [
                    'leaderboard_feature.prizes.cash_1000'.tr(),
                    'leaderboard_feature.prizes.books_3'.tr(),
                    'leaderboard_feature.prizes.courses_2'.tr(),
                    'leaderboard_feature.prizes.golden_box'.tr(),
                  ],
                ),
                _RewardTierCard(
                  rank: 'leaderboard_feature.ranks.second'.tr(),
                  rankIcon: '🥈',
                  color: Colors.grey,
                  rewards: [
                    'leaderboard_feature.prizes.cash_500'.tr(),
                    'leaderboard_feature.prizes.books_2'.tr(),
                    'leaderboard_feature.prizes.courses_2'.tr(),
                    'leaderboard_feature.prizes.silver_box'.tr(),
                  ],
                ),
                _RewardTierCard(
                  rank: 'leaderboard_feature.ranks.third'.tr(),
                  rankIcon: '🥉',
                  color: const Color(0xFFCD7F32),
                  rewards: [
                    'leaderboard_feature.prizes.cash_250'.tr(),
                    'leaderboard_feature.prizes.books_1'.tr(),
                    'leaderboard_feature.prizes.courses_1'.tr(),
                    'leaderboard_feature.prizes.bronze_box'.tr(),
                  ],
                ),
                _RewardTierCard(
                  rank: 'leaderboard_feature.ranks.fourth_fifth'.tr(),
                  rankIcon: '🏅',
                  color: Colors.blue,
                  rewards: [
                    'leaderboard_feature.prizes.cash_100'.tr(),
                    'leaderboard_feature.prizes.books_1'.tr(),
                    'leaderboard_feature.prizes.courses_1'.tr(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTierCard extends StatelessWidget {
  final String rank;
  final String rankIcon;
  final Color color;
  final List<String> rewards;

  const _RewardTierCard({
    required this.rank,
    required this.rankIcon,
    required this.color,
    required this.rewards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    rankIcon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rank,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...rewards.map((reward) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reward,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
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