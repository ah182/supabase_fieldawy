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

class _JobOffersScreenState extends ConsumerState<JobOffersScreen> with SingleTickerProviderStateMixin {
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
    
    // إضافة listener لإخفاء الكيبورد عند تغيير التاب
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

  // دالة مساعدة لإخفاء الكيبورد
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

  // دالة لتحديث الاقتراحات
  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _ghostText = '';
        _fullSuggestion = '';
      });
      return;
    }

    // جمع جميع الوظائف من كلا المصدرين
    final allJobsState = ref.read(allJobOffersNotifierProvider);
    final myJobsState = ref.read(myJobOffersNotifierProvider);
    
    List<JobOffer> allJobs = [];
    
    allJobsState.whenData((jobs) => allJobs.addAll(jobs));
    myJobsState.whenData((jobs) => allJobs.addAll(jobs));

    // البحث عن أفضل اقتراح
    String bestMatch = '';
    for (final job in allJobs) {
      final title = job.title.toLowerCase();
      final description = job.description.toLowerCase();
      final queryLower = query.toLowerCase();
      
      if (title.startsWith(queryLower) && title.length > query.length) {
        bestMatch = job.title;
        break;
      } else if (description.contains(queryLower)) {
        // العثور على الكلمة التي تبدأ بالاستعلام
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
      if (bestMatch.isNotEmpty && bestMatch.toLowerCase().startsWith(query.toLowerCase())) {
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _hideKeyboard(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('jobOffers'.tr()),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.work_outline),
                text: 'availableJobs'.tr(),
              ),
              Tab(
                icon: const Icon(Icons.manage_accounts_outlined),
                text: 'myJobOffers'.tr(),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // شريط البحث
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: [
                  // النص الشبحي
                  if (_ghostText.isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 48, right: 12),
                        child: Text(
                          _ghostText,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  // حقل البحث الفعلي
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'البحث في الوظائف...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_fullSuggestion.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_tab, color: Colors.blue),
                                    onPressed: () {
                                      _searchController.text = _fullSuggestion;
                                      _searchController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: _fullSuggestion.length),
                                      );
                                      setState(() {
                                        _searchQuery = _fullSuggestion;
                                        _ghostText = '';
                                        _fullSuggestion = '';
                                      });
                                    },
                                    tooltip: 'قبول الاقتراح',
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.clear),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      
                      // تحديث الاقتراحات مع debounce
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        _updateSuggestions(value);
                      });
                    },
                    onTap: () {
                      // إظهار الاقتراحات عند النقر
                      if (_searchController.text.isNotEmpty) {
                        _updateSuggestions(_searchController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
            // محتوى التابات
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
        icon: const Icon(Icons.add),
        label: Text('addJobOffer'.tr()),
        elevation: 4,
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

    return jobsAsync.when(
      data: (jobs) {
        // فلترة الوظائف حسب البحث
        final filteredJobs = searchQuery.isEmpty
            ? jobs
            : jobs.where((job) =>
                job.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                job.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (job.userName != null && job.userName!.toLowerCase().contains(searchQuery.toLowerCase()))
              ).toList();

        if (filteredJobs.isEmpty) {
          if (searchQuery.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 100,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'لم يتم العثور على وظائف',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'جرب كلمات بحث أخرى',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_off_outlined,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'noJobsAvailable'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'noJobsAvailableDesc'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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
            await ref.read(allJobOffersNotifierProvider.notifier).refreshAllJobs();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              return _JobOfferCard(
                job: job,
                showActions: false,
                onTap: () => _showJobDetailsDialog(context, job),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل الوظائف',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(allJobOffersNotifierProvider.notifier).refreshAllJobs();
              },
              child: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showJobDetailsDialog(BuildContext context, JobOffer job) {
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

    return jobsAsync.when(
      data: (jobs) {
        // فلترة الوظائف حسب البحث
        final filteredJobs = searchQuery.isEmpty
            ? jobs
            : jobs.where((job) =>
                job.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                job.description.toLowerCase().contains(searchQuery.toLowerCase())
              ).toList();

        if (filteredJobs.isEmpty) {
          if (searchQuery.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 100,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'لم يتم العثور على وظائف',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'جرب كلمات بحث أخرى',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.post_add_outlined,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'noMyJobOffers'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'noMyJobOffersDesc'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
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
                    label: Text('addYourFirstJob'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
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
                    final success = await ref.read(myJobOffersNotifierProvider.notifier).deleteJob(job.id);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم حذف العرض بنجاح'.tr())),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل عروضك',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(myJobOffersNotifierProvider.notifier).refreshMyJobs();
              },
              child: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'.tr()),
        content: Text('هل أنت متأكد من حذف هذا العرض؟'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }
}

class _JobOfferCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.work,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(job.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              job.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _openWhatsApp(job.phone),
              icon: const Icon(Icons.chat, size: 18),
              label: Text('whatsapp'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            if (showActions) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text('edit'.tr()),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    label: Text('delete'.tr()),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.work,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'jobDetails'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(job.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              Text(
                'jobTitle'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'jobDescription'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              
              if (job.userName != null) ...[
                Text(
                  'postedBy'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      job.userName!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${job.viewsCount} ${'views'.tr()}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _openWhatsApp(job.phone),
                  icon: const Icon(Icons.chat, size: 20),
                  label: Text(
                    'contactViaWhatsApp'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
