import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/jobs/application/job_offers_provider.dart';
import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:fieldawy_store/features/jobs/presentation/screens/add_job_offer_screen.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/search_history_view.dart';
import 'package:fieldawy_store/features/home/application/search_history_provider.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/quick_filters_bar.dart';
import 'package:fieldawy_store/features/jobs/application/job_filters_provider.dart';
import 'package:fieldawy_store/widgets/refreshable_error_widget.dart';
import 'package:fieldawy_store/core/providers/governorates_provider.dart';
import 'package:fieldawy_store/core/models/governorate_model.dart';

class JobOffersScreen extends ConsumerStatefulWidget {
  const JobOffersScreen({super.key});

  @override
  ConsumerState<JobOffersScreen> createState() => _JobOffersScreenState();
}

class _JobOffersScreenState extends ConsumerState<JobOffersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  String _ghostText = '';
  String _fullSuggestion = '';
  Timer? _debounce;
  
  static const String _historyTabId = 'jobs';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _hideKeyboard();
      }
    });

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
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _hideKeyboard() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      HapticFeedback.lightImpact();
      setState(() {
        if (_searchController.text.isEmpty) {
          _ghostText = '';
          _fullSuggestion = '';
        }
      });
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

    final allJobsState = ref.read(allJobOffersNotifierProvider);
    final myJobsState = ref.read(myJobOffersNotifierProvider);

    List<JobOffer> allJobs = [];

    allJobsState.whenData((jobs) => allJobs.addAll(jobs));
    myJobsState.whenData((jobs) => allJobs.addAll(jobs));

    String bestMatch = '';
    for (final job in allJobs) {
      final title = job.title.toLowerCase();
      final description = job.description.toLowerCase();
      final address = job.workplaceAddress.toLowerCase();
      final queryLower = query.toLowerCase();

      if (title.startsWith(queryLower) && title.length > query.length) {
        bestMatch = job.title;
        break;
      } else if (address.startsWith(queryLower) && address.length > query.length) {
        bestMatch = job.workplaceAddress;
        break;
      } else if (description.contains(queryLower)) {
        final words = description.split(' ');
        for (final word in words) {
          if (word.startsWith(queryLower) && word.length > query.length) {
            bestMatch = word;
            break;
          }
        }
        if (bestMatch.isNotEmpty) break;
      }
    }

    setState(() {
      if (bestMatch.isNotEmpty &&
          bestMatch.toLowerCase().startsWith(query.toLowerCase())) {
        _ghostText = query + bestMatch.substring(query.length);
        _fullSuggestion = bestMatch;
      } else {
        _ghostText = '';
        _fullSuggestion = '';
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
                        final filters = ref.watch(jobFiltersProvider);
                        final hasActiveFilters = filters.isNearest || filters.selectedGovernorate != null;
                        
                        if (!hasActiveFilters) return const SizedBox.shrink();
                        
                        return InkWell(
                          onTap: () {
                            ref.read(jobFiltersProvider.notifier).resetFilters();
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
            const QuickFiltersBar(showCheapest: false, useJobFilters: true),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _hideKeyboard(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                expandedHeight: 0, // No expanded height needed as content is in bottom
                floating: true,
                pinned: true,
                elevation: 0,
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
                title: Text(
                  'job_offers_feature.title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(165),
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
                                      hintText: 'job_offers_feature.search_hint'.tr(),
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
                                final filters = ref.watch(jobFiltersProvider);
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
                      
                      // Tabs
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.8),
                                theme.colorScheme.primary.withOpacity(0.8),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                          labelColor: Colors.white,
                          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(text: 'job_offers_feature.available_jobs'.tr()),
                            Tab(text: 'job_offers_feature.my_jobs'.tr()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _AvailableJobsTab(searchQuery: _debouncedSearchQuery),
              _MyJobOffersTab(searchQuery: _debouncedSearchQuery),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AddJobOfferScreen(),
              ),
            );

            if (result == true && mounted) {
              ref.read(allJobOffersNotifierProvider.notifier).refreshAllJobs();
              ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
            }
          },
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'job_offers_feature.add_job'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _AvailableJobsTab extends ConsumerWidget {
  const _AvailableJobsTab({this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(allJobOffersNotifierProvider);
    final theme = Theme.of(context);
    final filters = ref.watch(jobFiltersProvider);
    final governoratesAsync = ref.watch(governoratesProvider);

    return jobsAsync.when(
      data: (jobs) {
        // 1. Initial Filtering by Search Query
        var filteredJobs = searchQuery.isEmpty
            ? jobs
            : jobs.where((job) {
                final query = searchQuery.toLowerCase();
                return job.title.toLowerCase().contains(query) ||
                    job.description.toLowerCase().contains(query) ||
                    job.workplaceAddress.toLowerCase().contains(query) ||
                    (job.userName != null &&
                        job.userName!.toLowerCase().contains(query));
              }).toList();

        // 2. Filter by Governorate (Local Logic including Centers)
        if (filters.selectedGovernorate != null) {
          final governorates = governoratesAsync.asData?.value ?? [];
          final selectedGovModel = governorates.firstWhere(
            (g) => g.name == filters.selectedGovernorate,
            orElse: () => GovernorateModel(id: -1, name: '', centers: []),
          );
          
          final searchTerms = [filters.selectedGovernorate!, ...selectedGovModel.centers];

          filteredJobs = filteredJobs.where((job) {
             for (final term in searchTerms) {
               if (job.workplaceAddress.contains(term)) return true;
             }
             return false;
          }).toList();
        }

        // 3. Sorting
        // Nearest is not easily applicable without user coordinates relative to job.
        // Assuming there is no coordinate data for jobs currently in this simple model, 
        // we might skip actual geo-calculation unless 'workplaceAddress' can be resolved.
        // For now, if "Nearest" is selected, we might just keep default sort or implement if coordinates existed.

        if (filteredJobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    searchQuery.isNotEmpty || filters.selectedGovernorate != null
                        ? Icons.search_off_rounded
                        : Icons.work_off_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isNotEmpty || filters.selectedGovernorate != null
                      ? 'job_offers_feature.no_jobs_found'.tr()
                      : 'job_offers_feature.no_jobs_available'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (filters.selectedGovernorate != null || filters.isNearest)
                  TextButton(
                    onPressed: () => ref.read(jobFiltersProvider.notifier).resetFilters(),
                    child: Text('إعادة تعيين الفلاتر'),
                  ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.read(allJobOffersNotifierProvider.notifier).refreshAllJobs(),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(allJobOffersNotifierProvider.notifier).refreshAllJobs();
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              return _JobOfferCard(
                job: job,
                showActions: false,
                onTap: () => _showJobDetailsDialog(context, job, ref),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => RefreshableErrorWidget(
        message: 'products.error_occurred'.tr(),
        onRetry: () {
          ref.read(cachingServiceProvider).invalidate('all_job_offers_v2');
          ref.read(allJobOffersNotifierProvider.notifier).refreshAllJobs();
        },
      ),
    );
  }

  void _showJobDetailsDialog(BuildContext context, JobOffer job, WidgetRef ref) {
    ref.read(allJobOffersNotifierProvider.notifier).incrementViews(job.id);
    showDialog(
      context: context,
      builder: (context) => _JobDetailsDialog(job: job),
    );
  }
}

class _MyJobOffersTab extends ConsumerWidget {
  const _MyJobOffersTab({this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(myJobOffersNotifierProvider);
    final theme = Theme.of(context);

    return jobsAsync.when(
      data: (jobs) {
        final filteredJobs = searchQuery.isEmpty
            ? jobs
            : jobs.where((job) {
                final query = searchQuery.toLowerCase();
                return job.title.toLowerCase().contains(query) ||
                    job.description.toLowerCase().contains(query);
              }).toList();

        if (filteredJobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.post_add_rounded,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'job_offers_feature.no_my_jobs'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (searchQuery.isEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddJobOfferScreen(),
                        ),
                      );
                      if (result == true) {
                        ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text('job_offers_feature.add_first_job'.tr()),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs(),
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              return _JobOfferCard(
                job: job,
                showActions: true,
                onEdit: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AddJobOfferScreen(jobToEdit: job),
                    ),
                  );
                  if (result == true) {
                    ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
                  }
                },
                onDelete: () async {
                  final confirmed = await _showDeleteDialog(context);
                  if (confirmed == true) {
                    final success = await ref
                        .read(myJobOffersNotifierProvider.notifier)
                        .deleteJob(job.id);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('job_offers_feature.delete_success'.tr()),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => RefreshableErrorWidget(
        message: 'products.error_occurred'.tr(),
        onRetry: () {
          ref.read(cachingServiceProvider).invalidateWithPrefix('my_job_offers_');
          ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
        },
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('job_offers_feature.confirm_delete_title'.tr()),
        content: Text('job_offers_feature.confirm_delete_msg'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('job_offers_feature.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('job_offers_feature.delete'.tr()),
          ),
        ],
      ),
    );
  }
}

class _JobOfferCard extends ConsumerWidget {
  const _JobOfferCard({
    required this.job,
    this.showActions = false,
    this.onDelete,
    this.onEdit,
    this.onTap,
  });

  final JobOffer job;
  final bool showActions;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showUserDetails(context, ref, job.userId),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        backgroundImage: job.userPhotoUrl != null 
                            ? CachedNetworkImageProvider(job.userPhotoUrl!) 
                            : null,
                        child: job.userPhotoUrl == null 
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.work_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 28,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  job.workplaceAddress,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(job.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.visibility_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                NumberFormatter.formatCompact(job.viewsCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  job.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!showActions) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: Text(
                            'job_offers_feature.job_details'.tr(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                    if (showActions) ...[
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton.filledTonal(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_rounded, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                foregroundColor: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_rounded, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.errorContainer,
                                foregroundColor: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today'.tr();
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr();
    } else if (difference.inDays < 7) {
      return 'daysAgo'.tr(namedArgs: {'count': difference.inDays.toString()});
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

class _JobDetailsDialog extends ConsumerWidget {
  const _JobDetailsDialog({required this.job});

  final JobOffer job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showUserDetails(context, ref, job.userId),
                      child: CircleAvatar(
                        radius: 28, // Slightly larger since container is removed
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        backgroundImage: job.userPhotoUrl != null 
                            ? CachedNetworkImageProvider(job.userPhotoUrl!) 
                            : null,
                        child: job.userPhotoUrl == null 
                            ? Icon(Icons.work_rounded, color: theme.colorScheme.primary, size: 28) 
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy').format(job.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoSection(
                      title: 'job_offers_feature.workplace_address'.tr(),
                      content: job.workplaceAddress,
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),
                    _InfoSection(
                      title: 'job_offers_feature.job_description'.tr(),
                      content: job.description,
                      icon: Icons.description_outlined,
                    ),
                    if (job.userName != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'job_offers_feature.posted_by'.tr(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showUserDetails(context, ref, job.userId),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                               CircleAvatar(
                                  radius: 16,
                                  backgroundImage: job.userPhotoUrl != null ? CachedNetworkImageProvider(job.userPhotoUrl!) : null,
                                  child: job.userPhotoUrl == null ? Icon(Icons.person, size: 16) : null,
                               ),
                               const SizedBox(width: 12),
                               Expanded(
                                 child: Text(
                                    job.userName!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.5,
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Contact Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(job.phone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: Text(
                          'job_offers_feature.contact_whatsapp'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('job_offers_feature.cancel'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final message = Uri.encodeComponent('whatsappInquiry'.tr());
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.content,
    required this.icon,
  });

  final String title;
  final String content;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// User Details Helpers
// ===================================================================

void _showUserDetails(BuildContext context, WidgetRef ref, String userId) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final userModel = await ref.read(userRepositoryProvider).getUser(userId);
    
    if (context.mounted) {
      Navigator.pop(context); // Close loading
      if (userModel != null) {
        _showUserBottomSheet(context, userModel);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('surgical_tools_feature.messages.user_load_error'.tr())),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('surgical_tools_feature.messages.generic_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    }
  }
}

void _showUserBottomSheet(BuildContext context, UserModel user) {
  final theme = Theme.of(context);
  final isDistributor = user.role == 'distributor' || user.role == 'company';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user.photoUrl != null
                      ? CachedNetworkImageProvider(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName ?? 'comments_feature.user'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoleLabel(user.role),
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
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
                if (isDistributor && user.distributionMethod != null)
                  _buildDetailTile(
                    theme,
                    Icons.local_shipping,
                    'distributors_feature.distribution_method'.tr(),
                    _getDistributionMethodLabel(user.distributionMethod!),
                  ),
                if (user.governorates != null && user.governorates!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              isDistributor ? 'distributors_feature.coverage_areas'.tr() : 'distributors_feature.location'.tr(),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: user.governorates!.map((gov) => Container(
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
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (user.whatsappNumber != null && user.whatsappNumber!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openWhatsApp(user.whatsappNumber!),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                      label: Text('distributors_feature.contact_whatsapp'.tr(), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (isDistributor) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                                                  final distributor = DistributorModel(
                                                    id: user.id,
                                                    displayName: user.displayName ?? '',
                                                    photoURL: user.photoUrl,
                                                    // email: user.email, // Removed
                                                    distributorType: user.role,
                                                    whatsappNumber: user.whatsappNumber,
                                                    governorates: user.governorates,
                                                    centers: user.centers,
                                                    distributionMethod: user.distributionMethod,
                                                  );                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DistributorProductsScreen(
                              distributor: distributor,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2),
                      label: Text('distributors_feature.view_products'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDetailTile(ThemeData theme, IconData icon, String title, String value) {
  return ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: theme.colorScheme.primary),
    ),
    title: Text(title, style: theme.textTheme.bodySmall),
    subtitle: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    contentPadding: EdgeInsets.zero,
  );
}

String _getRoleLabel(String role) {
  switch (role) {
    case 'doctor': return 'auth.role_veterinarian'.tr();
    case 'distributor': return 'auth.role_distributor'.tr();
    case 'company': return 'auth.role_company'.tr();
    default: return role;
  }
}

String _getDistributionMethodLabel(String method) {
  switch (method) {
    case 'direct_distribution': return 'auth.profile.distribution.direct_distribution'.tr();
    case 'order_delivery': return 'auth.profile.distribution.order_delivery'.tr();
    case 'both': return 'auth.profile.distribution.both_methods'.tr();
    default: return method;
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

Future<void> _openWhatsApp(String phone) async {
  final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final url = 'https://wa.me/20$cleanPhone';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}