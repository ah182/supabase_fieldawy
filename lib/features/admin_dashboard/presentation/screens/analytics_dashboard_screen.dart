import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/user_growth_analytics.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/top_performers_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/advanced_search_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/geographic_distribution_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/offers_tracker_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/system_health_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/performance_monitor_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/error_logs_viewer.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title
          Text(
            'Analytics & Insights',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // User Growth Analytics
          const UserGrowthAnalytics(),
          const SizedBox(height: 24),
          // Top Performers
          const TopPerformersWidget(),
          const SizedBox(height: 24),
          // Advanced Search
          SizedBox(
            height: 600,
            child: const AdvancedSearchWidget(),
          ),
          const SizedBox(height: 24),
          // Geographic Distribution & System Health
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: const GeographicDistributionWidget(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: const SystemHealthWidget(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Offers Tracker
          const OffersTrackerWidget(),
          const SizedBox(height: 24),
          // Performance & Errors
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: const PerformanceMonitorWidget(),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: const ErrorLogsViewer(),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
