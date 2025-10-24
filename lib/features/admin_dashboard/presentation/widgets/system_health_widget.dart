import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';

import 'package:fieldawy_store/features/admin_dashboard/data/activity_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SystemHealthWidget extends ConsumerWidget {
  const SystemHealthWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersListProvider);
    final productsAsync = ref.watch(adminAllProductsProvider);
    // Temporary - use direct query
    final offersAsync = ref.watch(FutureProvider<List>((ref) async {
      final supabase = Supabase.instance.client;
      return await supabase.from('offers').select();
    }));
    final activitiesAsync = ref.watch(recentActivitiesProvider);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.health_and_safety,
                      color: Colors.green.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'System Health & Alerts',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref.invalidate(allUsersListProvider);
                    ref.invalidate(adminAllProductsProvider);
                    ref.invalidate(recentActivitiesProvider);
                  },
                  tooltip: 'Refresh All',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // System Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Systems Operational',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Dashboard is running smoothly',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 6),
                        Text(
                          'ONLINE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Health Metrics
            Row(
              children: [
                Expanded(
                  child: usersAsync.when(
                    loading: () => _MetricCard(
                      label: 'Database',
                      status: 'Loading...',
                      icon: Icons.storage,
                      isHealthy: null,
                    ),
                    error: (err, stack) => _MetricCard(
                      label: 'Database',
                      status: 'Error',
                      icon: Icons.storage,
                      isHealthy: false,
                    ),
                    data: (users) => _MetricCard(
                      label: 'Database',
                      status: 'Healthy',
                      icon: Icons.storage,
                      isHealthy: true,
                      subtitle: '${users.length} users',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: productsAsync.when(
                    loading: () => _MetricCard(
                      label: 'Products',
                      status: 'Loading...',
                      icon: Icons.inventory_2,
                      isHealthy: null,
                    ),
                    error: (err, stack) => _MetricCard(
                      label: 'Products',
                      status: 'Error',
                      icon: Icons.inventory_2,
                      isHealthy: false,
                    ),
                    data: (products) => _MetricCard(
                      label: 'Products',
                      status: 'Healthy',
                      icon: Icons.inventory_2,
                      isHealthy: true,
                      subtitle: '${products.length} items',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: activitiesAsync.when(
                    loading: () => _MetricCard(
                      label: 'Activity Logs',
                      status: 'Loading...',
                      icon: Icons.timeline,
                      isHealthy: null,
                    ),
                    error: (err, stack) => _MetricCard(
                      label: 'Activity Logs',
                      status: 'Error',
                      icon: Icons.timeline,
                      isHealthy: false,
                    ),
                    data: (activities) => _MetricCard(
                      label: 'Activity Logs',
                      status: 'Healthy',
                      icon: Icons.timeline,
                      isHealthy: true,
                      subtitle: '${activities.length} recent',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Active Alerts
            Text(
              'Active Alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildAlerts(ref, usersAsync, offersAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildAlerts(WidgetRef ref, usersAsync, offersAsync) {
    final List<Widget> alerts = [];

    // Check pending users
    usersAsync.whenData((users) {
      final pendingCount =
          users.where((u) => u.accountStatus == 'pending_review').length;
      if (pendingCount > 5) {
        alerts.add(_AlertItem(
          icon: Icons.people,
          color: Colors.orange,
          title: 'High number of pending user requests',
          description: '$pendingCount users waiting for approval',
          severity: 'Medium',
        ));
      }
    });

    // Check expiring offers
    offersAsync.whenData((offers) {
      final now = DateTime.now();
      final expiringSoon = offers
          .where((o) =>
              o.expirationDate.isAfter(now) &&
              o.expirationDate.difference(now).inHours < 24)
          .length;
      if (expiringSoon > 0) {
        alerts.add(_AlertItem(
          icon: Icons.access_time,
          color: Colors.orange,
          title: 'Offers expiring soon',
          description: '$expiringSoon offer(s) will expire within 24 hours',
          severity: 'Low',
        ));
      }
    });

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
            const SizedBox(width: 12),
            Text(
              'No active alerts',
              style: TextStyle(
                color: Colors.green.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: alerts,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.status,
    required this.icon,
    required this.isHealthy,
    this.subtitle,
  });

  final String label;
  final String status;
  final IconData icon;
  final bool? isHealthy;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = isHealthy == null
        ? Colors.grey
        : isHealthy!
            ? Colors.green
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Icon(
                isHealthy == null
                    ? Icons.pending
                    : isHealthy!
                        ? Icons.check_circle
                        : Icons.error,
                color: color,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  const _AlertItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.severity,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String severity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              severity,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
