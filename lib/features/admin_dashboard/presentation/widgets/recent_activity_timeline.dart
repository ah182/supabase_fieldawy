// ignore_for_file: duplicate_import

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/admin_dashboard/data/activity_repository.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/admin_dashboard/data/activity_repository.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:responsive_builder/responsive_builder.dart';

class RecentActivityTimeline extends ConsumerWidget {
  const RecentActivityTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentActivitiesProvider);

    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isMobile = sizingInformation.isMobile;
        final padding = isMobile ? 12.0 : 24.0;

        return Card(
          elevation: 4,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.timeline,
                          color: Colors.purple.shade700, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () {
                        ref.invalidate(recentActivitiesProvider);
                      },
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Activity List
                activitiesAsync.when(
                  loading: () => Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('Error loading activities'),
                          TextButton(
                            onPressed: () {
                              ref.invalidate(recentActivitiesProvider);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (activities) {
                    if (activities.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(padding),
                          child: const Column(
                            children: [
                              Icon(Icons.history, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No recent activities'),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activities.length > 10 ? 10 : activities.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _ActivityItem(activity: activity);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.activity});

  final ActivityLog activity;

  @override
  Widget build(BuildContext context) {
    final activityIcon = _getActivityIcon(activity.activityType);
    final activityColor = _getActivityColor(activity.activityType);
    final timeAgo = timeago.format(activity.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(activityIcon, size: 20, color: activityColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (activity.userName != null) ...[
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        activity.userName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'user_approved':
        return Icons.check_circle;
      case 'user_rejected':
        return Icons.cancel;
      case 'product_added':
        return Icons.add_shopping_cart;
      case 'offer_created':
        return Icons.local_offer;
      case 'user_registered':
        return Icons.person_add;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityColor(String activityType) {
    switch (activityType) {
      case 'user_approved':
        return Colors.green;
      case 'user_rejected':
        return Colors.red;
      case 'product_added':
        return Colors.blue;
      case 'offer_created':
        return Colors.orange;
      case 'user_registered':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}


