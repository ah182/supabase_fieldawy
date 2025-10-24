import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickActionsPanel extends ConsumerWidget {
  const QuickActionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(Icons.bolt, color: Colors.blue.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Actions Grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionButton(
                  icon: Icons.people,
                  label: 'Review Users',
                  color: Colors.blue,
                  onPressed: () {
                    // Navigate to Users Management
                    _navigateToUsersManagement(context);
                  },
                ),
                _ActionButton(
                  icon: Icons.inventory_2,
                  label: 'Manage Products',
                  color: Colors.orange,
                  onPressed: () {
                    // Navigate to Products Management
                    _navigateToProductsManagement(context);
                  },
                ),
                _ActionButton(
                  icon: Icons.local_offer,
                  label: 'Create Offer',
                  color: Colors.pink,
                  onPressed: () {
                    // Show create offer dialog
                    _showCreateOfferDialog(context);
                  },
                ),
                _ActionButton(
                  icon: Icons.book,
                  label: 'Add Book/Course',
                  color: Colors.teal,
                  onPressed: () {
                    // Show add book/course dialog
                    _showComingSoonDialog(context, 'Add Book/Course');
                  },
                ),
                _ActionButton(
                  icon: Icons.work,
                  label: 'Post Job',
                  color: Colors.purple,
                  onPressed: () {
                    // Show post job dialog
                    _showComingSoonDialog(context, 'Post Job Offer');
                  },
                ),
                _ActionButton(
                  icon: Icons.notifications,
                  label: 'Send Notification',
                  color: Colors.red,
                  onPressed: () {
                    // Show send notification dialog
                    _showComingSoonDialog(context, 'Send Notification');
                  },
                ),
                _ActionButton(
                  icon: Icons.add_circle,
                  label: 'Add Catalog Product',
                  color: Colors.green,
                  onPressed: () {
                    // Show add catalog product dialog
                    _showComingSoonDialog(context, 'Add Catalog Product');
                  },
                ),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'Refresh All',
                  color: Colors.grey,
                  onPressed: () {
                    // Refresh all providers
                    _refreshAllData(ref);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToUsersManagement(BuildContext context) {
    // Since we're using NavigationRail, we can't directly navigate
    // Instead, we could show a snackbar or implement a callback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigate to Users Management tab'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToProductsManagement(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigate to Products Management tab'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCreateOfferDialog(BuildContext context) {
    _showComingSoonDialog(context, 'Create Offer');
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature feature will be added in a future update!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _refreshAllData(WidgetRef ref) {
    // Invalidate all providers to refresh data
    ref.invalidate(totalUsersProvider);
    ref.invalidate(doctorsCountProvider);
    ref.invalidate(distributorsCountProvider);
    ref.invalidate(companiesCountProvider);
    ref.invalidate(adminAllProductsProvider);
    ref.invalidate(allUsersListProvider);
    
    // Show success message
    // Note: We'd need BuildContext here, so this is simplified
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
          elevation: 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
