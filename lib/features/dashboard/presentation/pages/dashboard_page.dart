import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/features/dashboard/application/dashboard_provider.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/dashboard_stats_card.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/quick_actions_panel.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/recent_products_widget.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/performance_chart_widget.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/top_products_widget.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/alerts_notifications_widget.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/regional_stats_widget.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/advanced_views_analytics_widget.dart';
import 'package:fieldawy_store/features/dashboard/presentation/widgets/trends_analytics_widget_updated.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> 
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh dashboard when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshDashboard();
    }
  }

  // Function to refresh all dashboard data
  Future<void> _refreshDashboard() async {
    // Increment refresh counter to trigger all providers
    final currentCount = ref.read(dashboardRefreshProvider);
    ref.read(dashboardRefreshProvider.notifier).state = currentCount + 1;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final isRefreshing = ref.watch(dashboardRefreshNotifierProvider);

    return MainScaffold(
      selectedIndex: 2, // Dashboard is at index 2 for distributors
      body: Stack(
        children: [
          Column(
            children: [
              // Welcome Header with refresh button
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً بك في لوحة التحكم المتقدمة',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إحصائياتك الخاصة • ترندات عالمية • تحليلات متقدمة',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.dashboard,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Manual refresh button
                        InkWell(
                          onTap: () {
                            ref.read(dashboardRefreshNotifierProvider.notifier).refreshDashboard();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'تحديث',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person, size: 20),
                          const SizedBox(width: 8),
                          Text('إحصائياتي الخاصة'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public, size: 20),
                          const SizedBox(width: 8),
                          Text('الترندات العالمية'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Personal Statistics
                    _buildPersonalStatsTab(dashboardStatsAsync),
                    
                    // Tab 2: Global Trends
                    _buildGlobalTrendsTab(),
                  ],
                ),
              ),
            ],
          ),
          
          // Refreshing indicator
          if (isRefreshing)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('جارٍ تحديث البيانات...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Tab 1: Personal Statistics
  Widget _buildPersonalStatsTab(AsyncValue<dynamic> dashboardStatsAsync) {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Stats Header
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'إحصائياتي الشخصية',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تفاصيل شاملة عن أداء منتجاتك ونشاطك في التطبيق',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Stats Cards
            dashboardStatsAsync.when(
              data: (stats) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatsCard(
                          title: 'إجمالي المنتجات',
                          value: '${stats.totalProducts}',
                          icon: Icons.inventory,
                          color: Colors.blue,
                          growth: stats.monthlyGrowth,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DashboardStatsCard(
                          title: 'العروض النشطة',
                          value: '${stats.activeOffers}',
                          icon: Icons.local_offer,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatsCard(
                          title: 'إجمالي المشاهدات',
                          value: '${stats.totalViews}',
                          icon: Icons.visibility,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DashboardStatsCard(
                          title: 'متوسط التقييم',
                          value: '${stats.averageRating.toStringAsFixed(1)}',
                          icon: Icons.star,
                          color: Colors.amber,
                          subtitle: 'من 5.0',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                    ],
                  ),
                ],
              ),
              error: (error, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'خطأ في تحميل الإحصائيات',
                          style: TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _refreshDashboard,
                          child: Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions Panel
            const QuickActionsPanel(),

            const SizedBox(height: 24),

            // Advanced Views Analytics Widget
            const AdvancedViewsAnalyticsWidget(),

            const SizedBox(height: 24),

            // Original Charts and Analytics
            const PerformanceChartWidget(),

            const SizedBox(height: 24),

            // Responsive Layout for Products and Alerts
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 768) {
                  // Desktop layout - two columns
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            const RecentProductsWidget(),
                            const SizedBox(height: 16),
                            const TopProductsWidget(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            const AlertsNotificationsWidget(),
                            const SizedBox(height: 16),
                            const RegionalStatsWidget(),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile layout - single column
                  return Column(
                    children: [
                      const RecentProductsWidget(),
                      const SizedBox(height: 16),
                      const AlertsNotificationsWidget(),
                      const SizedBox(height: 16),
                      const TopProductsWidget(),
                      const SizedBox(height: 16),
                      const RegionalStatsWidget(),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            // Footer for personal tab
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'إحصائياتك الشخصية - محدثة كل دقيقة',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Tab 2: Global Trends
  Widget _buildGlobalTrendsTab() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Global Trends Header
            Row(
              children: [
                Icon(Icons.public, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  'الترندات العالمية',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اكتشف المنتجات الأكثر رواجاً عالمياً واحصل على توصيات ذكية',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Global Trends Analytics Widget (Updated with real data)
            const TrendsAnalyticsWidgetUpdated(),

            const SizedBox(height: 24),

            // Footer for global trends tab
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'بيانات عالمية من جميع الموزعين - محدثة كل ساعة',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'آخر تحديث: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: 80,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}