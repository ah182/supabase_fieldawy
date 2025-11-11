import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/pending_approvals_widget.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/quick_actions_panel.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/recent_activity_timeline.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/notification_manager_widget.dart';
import 'package:fieldawy_store/core/services/backup_restore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin Dashboard نسخة Mobile - مصممة خصيصاً للهواتف
class MobileAdminDashboardScreen extends ConsumerStatefulWidget {
  const MobileAdminDashboardScreen({super.key});

  @override
  ConsumerState<MobileAdminDashboardScreen> createState() => _MobileAdminDashboardScreenState();
}

class _MobileAdminDashboardScreenState extends ConsumerState<MobileAdminDashboardScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Approvals'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
            Tab(icon: Icon(Icons.settings), text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildApprovalsTab(),
          _buildNotificationsTab(),
          _buildSystemTab(),
        ],
      ),
    );
  }

  // Tab 1: Overview - الإحصائيات والإجراءات السريعة
  Widget _buildOverviewTab() {
    final productsAsync = ref.watch(adminAllProductsProvider);
    final usersCountAsync = ref.watch(totalUsersProvider);
    final doctorsCountAsync = ref.watch(doctorsCountProvider);
    final distributorsCountAsync = ref.watch(distributorsCountProvider);
    final companiesCountAsync = ref.watch(companiesCountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAllProductsProvider);
        ref.invalidate(totalUsersProvider);
        ref.invalidate(doctorsCountProvider);
        ref.invalidate(distributorsCountProvider);
        ref.invalidate(companiesCountProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards - 2 columns للموبايل
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                usersCountAsync.when(
                  loading: () => const _MobileStatCard(
                    title: 'Total Users',
                    value: '...',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  error: (err, stack) => const _MobileStatCard(
                    title: 'Total Users',
                    value: 'Error',
                    icon: Icons.error_outline,
                    color: Colors.red,
                  ),
                  data: (count) => _MobileStatCard(
                    title: 'Total Users',
                    value: count.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                doctorsCountAsync.when(
                  loading: () => const _MobileStatCard(
                    title: 'Doctors',
                    value: '...',
                    icon: Icons.medical_services,
                    color: Colors.green,
                  ),
                  error: (err, stack) => const _MobileStatCard(
                    title: 'Doctors',
                    value: 'Error',
                    icon: Icons.error_outline,
                    color: Colors.red,
                  ),
                  data: (count) => _MobileStatCard(
                    title: 'Doctors',
                    value: count.toString(),
                    icon: Icons.medical_services,
                    color: Colors.green,
                  ),
                ),
                distributorsCountAsync.when(
                  loading: () => const _MobileStatCard(
                    title: 'Distributors',
                    value: '...',
                    icon: Icons.local_shipping,
                    color: Colors.purple,
                  ),
                  error: (err, stack) => const _MobileStatCard(
                    title: 'Distributors',
                    value: 'Error',
                    icon: Icons.error_outline,
                    color: Colors.red,
                  ),
                  data: (count) => _MobileStatCard(
                    title: 'Distributors',
                    value: count.toString(),
                    icon: Icons.local_shipping,
                    color: Colors.purple,
                  ),
                ),
                companiesCountAsync.when(
                  loading: () => const _MobileStatCard(
                    title: 'Companies',
                    value: '...',
                    icon: Icons.business,
                    color: Colors.teal,
                  ),
                  error: (err, stack) => const _MobileStatCard(
                    title: 'Companies',
                    value: 'Error',
                    icon: Icons.error_outline,
                    color: Colors.red,
                  ),
                  data: (count) => _MobileStatCard(
                    title: 'Companies',
                    value: count.toString(),
                    icon: Icons.business,
                    color: Colors.teal,
                  ),
                ),
                productsAsync.when(
                  loading: () => const _MobileStatCard(
                    title: 'Products',
                    value: '...',
                    icon: Icons.inventory_2,
                    color: Colors.orange,
                  ),
                  error: (err, stack) => const _MobileStatCard(
                    title: 'Products',
                    value: 'Error',
                    icon: Icons.error_outline,
                    color: Colors.red,
                  ),
                  data: (products) {
                    final distributorProducts = products.where((p) => 
                      p.distributorId != null && p.distributorId!.isNotEmpty
                    ).length;
                    
                    return _MobileStatCard(
                      title: 'Products',
                      value: distributorProducts.toString(),
                      icon: Icons.inventory_2,
                      color: Colors.orange,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Quick Actions - للموبايل
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const QuickActionsPanel(),
            const SizedBox(height: 24),
            // Recent Activity
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const RecentActivityTimeline(),
          ],
        ),
      ),
    );
  }

  // Tab 2: Approvals - الموافقات المنتظرة
  Widget _buildApprovalsTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Approvals',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          PendingApprovalsWidget(),
        ],
      ),
    );
  }

  // Tab 3: Notifications - إدارة الإشعارات
  Widget _buildNotificationsTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Notifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          NotificationManagerWidget(),
        ],
      ),
    );
  }

  // Tab 4: System - إعدادات النظام
  Widget _buildSystemTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Backup & Restore Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.backup,
                          color: Colors.green.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup & Restore',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage system backups',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Backup Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => BackupRestoreService.createBackup(context: context),
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Create Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Restore Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => BackupRestoreService.restoreFromBackup(context: context),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Restore Backup'),
                      style: OutlinedButton.styleFrom(
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
          ),
          const SizedBox(height: 16),
          // System Info Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System Info',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Application details',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildInfoRow('Version', '1.0.0'),
                  _buildInfoRow('Platform', 'Mobile'),
                  _buildInfoRow('Last Updated', 'Today'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat Card مصممة للموبايل - أصغر وأكثر كفاءة
class _MobileStatCard extends StatelessWidget {
  const _MobileStatCard({
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
      elevation: 2,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
