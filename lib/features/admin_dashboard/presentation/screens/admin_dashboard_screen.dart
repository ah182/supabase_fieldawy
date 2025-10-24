import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/pending_approvals_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/quick_actions_panel.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/recent_activity_timeline.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/notification_manager_widget.dart';
import 'package:fieldawy_store/core/services/backup_restore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminAllProductsProvider);
    final usersCountAsync = ref.watch(totalUsersProvider);
    final doctorsCountAsync = ref.watch(doctorsCountProvider);
    final distributorsCountAsync = ref.watch(distributorsCountProvider);
    final companiesCountAsync = ref.watch(companiesCountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          // Stats Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              usersCountAsync.when(
                loading: () => const _StatCard(
                  title: 'Total Users',
                  value: '...',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                error: (err, stack) => const _StatCard(
                  title: 'Total Users',
                  value: 'Error',
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
                data: (count) => _StatCard(
                  title: 'Total Users',
                  value: count.toString(),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
              doctorsCountAsync.when(
                loading: () => const _StatCard(
                  title: 'Doctors',
                  value: '...',
                  icon: Icons.medical_services,
                  color: Colors.green,
                ),
                error: (err, stack) => const _StatCard(
                  title: 'Doctors',
                  value: 'Error',
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
                data: (count) => _StatCard(
                  title: 'Doctors',
                  value: count.toString(),
                  icon: Icons.medical_services,
                  color: Colors.green,
                ),
              ),
              distributorsCountAsync.when(
                loading: () => const _StatCard(
                  title: 'Distributors',
                  value: '...',
                  icon: Icons.local_shipping,
                  color: Colors.purple,
                ),
                error: (err, stack) => const _StatCard(
                  title: 'Distributors',
                  value: 'Error',
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
                data: (count) => _StatCard(
                  title: 'Distributors',
                  value: count.toString(),
                  icon: Icons.local_shipping,
                  color: Colors.purple,
                ),
              ),
              companiesCountAsync.when(
                loading: () => const _StatCard(
                  title: 'Companies',
                  value: '...',
                  icon: Icons.business,
                  color: Colors.teal,
                ),
                error: (err, stack) => const _StatCard(
                  title: 'Companies',
                  value: 'Error',
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
                data: (count) => _StatCard(
                  title: 'Companies',
                  value: count.toString(),
                  icon: Icons.business,
                  color: Colors.teal,
                ),
              ),
              productsAsync.when(
                loading: () => const _StatCard(
                  title: 'Total Products',
                  value: '...',
                  icon: Icons.inventory_2,
                  color: Colors.orange,
                ),
                error: (err, stack) => const _StatCard(
                  title: 'Total Products',
                  value: 'Error',
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
                data: (products) {
                  // Count only Distributor + OCR products (exclude Catalog products)
                  final distributorProducts = products.where((p) => 
                    p.distributorId != null && p.distributorId!.isNotEmpty
                  ).length;
                  
                  return _StatCard(
                    title: 'Total Products',
                    value: distributorProducts.toString(),
                    icon: Icons.inventory_2,
                    color: Colors.orange,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // New Features Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Approvals (Left - 40%)
              Expanded(
                flex: 4,
                child: const PendingApprovalsWidget(),
              ),
              const SizedBox(width: 16),
              // Quick Actions (Right - 60%)
              Expanded(
                flex: 6,
                child: const QuickActionsPanel(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Recent Activity Timeline (Full Width)
          const RecentActivityTimeline(),
          const SizedBox(height: 24),
          // Notification Manager
          const NotificationManagerWidget(),
          const SizedBox(height: 24),
          // Backup & Restore
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.backup, color: Colors.green.shade700, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Backup & Restore',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Create a backup of all data or restore from a previous backup.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => BackupRestoreService.createBackup(context: context),
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('Create Backup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => BackupRestoreService.restoreFromBackup(context: context),
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Restore Backup'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
