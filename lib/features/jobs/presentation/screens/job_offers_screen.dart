import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/jobs/application/job_offers_provider.dart';
import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:fieldawy_store/features/jobs/presentation/screens/add_job_offer_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _ghostText = '';
  String _fullSuggestion = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _hideKeyboard();
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
      final queryLower = query.toLowerCase();

      if (title.startsWith(queryLower) && title.length > query.length) {
        bestMatch = job.title;
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
                expandedHeight: 200,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: theme.colorScheme.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.8),
                          theme.colorScheme.primary,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.work_outline,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'job_offers_feature.title'.tr(),
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Find your next opportunity',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: Colors.white.withOpacity(0.9),
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
                    ),
                  ),
                ),
                title: innerBoxIsScrolled
                    ? Text(
                        'job_offers_feature.title'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ];
          },
          body: Column(
            children: [
              // Search bar
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (_ghostText.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 52, right: 12),
                          child: Text(
                            _ghostText,
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.3),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'job_offers_feature.search_hint'.tr(),
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        prefixIcon: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_fullSuggestion.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.keyboard_tab_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                        onPressed: () {
                                          _searchController.text =
                                              _fullSuggestion;
                                          _searchController.selection =
                                              TextSelection.fromPosition(
                                            TextPosition(
                                                offset: _fullSuggestion.length),
                                          );
                                          setState(() {
                                            _searchQuery = _fullSuggestion;
                                            _ghostText = '';
                                            _fullSuggestion = '';
                                          });
                                        },
                                        tooltip: 'Accept suggestion',
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _ghostText = '';
                                        _fullSuggestion = '';
                                      });
                                    },
                                  ),
                                ],
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      style: theme.textTheme.bodyLarge,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });

                        _debounce?.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 300), () {
                          _updateSuggestions(value);
                        });
                      },
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          _updateSuggestions(_searchController.text);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      theme.colorScheme.onSurface.withOpacity(0.6),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.explore_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text('job_offers_feature.available_jobs'.tr()),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_center_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text('job_offers_feature.my_jobs'.tr()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AvailableJobsTab(searchQuery: _searchQuery),
                    _MyJobOffersTab(searchQuery: _searchQuery),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddJobOfferScreen(),
                ),
              );

              if (result == true && mounted) {
                ref
                    .read(allJobOffersNotifierProvider.notifier)
                    .refreshAllJobs();
                ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
              }
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.add_rounded, size: 24),
            label: Text(
              'job_offers_feature.add_job'.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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

    return jobsAsync.when(
      data: (jobs) {
        final filteredJobs = searchQuery.isEmpty
            ? jobs
            : jobs
                .where((job) =>
                    job.title
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    job.description
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    (job.userName != null &&
                        job.userName!
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase())))
                .toList();

        if (filteredJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.work_off_outlined,
                      size: 80,
                      color: theme.colorScheme.primary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'job_offers_feature.no_jobs_found'.tr()
                        : 'job_offers_feature.no_jobs_available'.tr(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'Try different keywords'
                        : 'job_offers_feature.no_jobs_desc'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(allJobOffersNotifierProvider.notifier)
                .refreshAllJobs();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 60, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'job_offers_feature.error_occurred'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(allJobOffersNotifierProvider.notifier)
                      .refreshAllJobs();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text('job_offers_feature.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetailsDialog(
      BuildContext context, JobOffer job, WidgetRef ref) {
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
            : jobs
                .where((job) =>
                    job.title
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    job.description
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                .toList();

        if (filteredJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.post_add_outlined,
                      size: 80,
                      color: theme.colorScheme.primary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'job_offers_feature.no_jobs_found'.tr()
                        : 'job_offers_feature.no_my_jobs'.tr(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'Try different keywords'
                        : 'job_offers_feature.no_my_jobs_desc'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (searchQuery.isEmpty) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AddJobOfferScreen(),
                          ),
                        );

                        if (result == true) {
                          ref
                              .read(myJobOffersNotifierProvider.notifier)
                              .refreshMyJobs();
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text('job_offers_feature.add_first_job'.tr()),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(myJobOffersNotifierProvider.notifier)
                .refreshMyJobs();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    ref
                        .read(myJobOffersNotifierProvider.notifier)
                        .refreshMyJobs();
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
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
                              const SizedBox(width: 12),
                              Text('job_offers_feature.delete_success'.tr()),
                            ],
                          ),
                          backgroundColor: Colors.green[600],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 60, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'job_offers_feature.error_occurred'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(myJobOffersNotifierProvider.notifier)
                      .refreshMyJobs();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text('job_offers_feature.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text('job_offers_feature.confirm_delete_title'.tr()),
          ],
        ),
        content: Text('job_offers_feature.confirm_delete_msg'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('job_offers_feature.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('job_offers_feature.delete'.tr()),
          ),
        ],
      ),
    );
  }
}

class _JobOfferCard extends ConsumerStatefulWidget {
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
  ConsumerState<_JobOfferCard> createState() => _JobOfferCardState();
}

class _JobOfferCardState extends ConsumerState<_JobOfferCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primaryContainer.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.work_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.job.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(widget.job.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.visibility_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.job.viewsCount}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.job.description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openWhatsApp(widget.job.phone),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_rounded,
                                      size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'job_offers_feature.contact_whatsapp'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.showActions) ...[
                  const SizedBox(height: 12),
                  Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text('job_offers_feature.edit'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text('job_offers_feature.delete'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today'.tr();
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr();
    } else if (difference.inDays < 7) {
      return '${'daysAgo'.tr()} ${difference.inDays}';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}

class _JobDetailsDialog extends StatelessWidget {
  const _JobDetailsDialog({required this.job});

  final JobOffer job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primaryContainer.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.work_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'job_offers_feature.job_details'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(job.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'job_offers_feature.job_title'.tr(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'job_offers_feature.job_description'.tr(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.userName != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'job_offers_feature.posted_by'.tr(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                job.userName!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${job.viewsCount} ${'job_offers_feature.views'.tr()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openWhatsApp(job.phone),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_rounded,
                                  size: 22, color: Colors.white),
                              const SizedBox(width: 12),
                              Text(
                                'job_offers_feature.contact_whatsapp'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today'.tr();
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr();
    } else if (difference.inDays < 7) {
      return '${'daysAgo'.tr()} ${difference.inDays}';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}
