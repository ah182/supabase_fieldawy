import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class QuickActionsPanel extends StatelessWidget {
  const QuickActionsPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  'إجراءات سريعة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildQuickActionButton(
                  context,
                  icon: Icons.add_circle_outline,
                  label: 'addProduct'.tr(),
                  color: Colors.blue,
                  onTap: () {
                    // Navigate to add product screen
                    context.go('/add-product');
                  },
                ),
                _buildQuickActionButton(
                  context,
                  icon: Icons.local_offer,
                  label: 'إضافة عرض',
                  color: Colors.green,
                  onTap: () {
                    // Navigate to add offer screen
                    context.go('/limited-offer');
                  },
                ),
                _buildQuickActionButton(
                  context,
                  icon: Icons.medical_services,
                  label: 'أدوات جراحية',
                  color: Colors.purple,
                  onTap: () {
                    // Navigate to surgical tools
                    context.go('/surgical-tools');
                  },
                ),
                _buildQuickActionButton(
                  context,
                  icon: Icons.pets,
                  label: 'مستلزمات بيطرية',
                  color: Colors.teal,
                  onTap: () {
                    // Navigate to vet supplies
                    context.go('/vet-supplies');
                  },
                ),
                _buildQuickActionButton(
                  context,
                  icon: Icons.analytics,
                  label: 'التقارير',
                  color: Colors.indigo,
                  onTap: () {
                    // Navigate to analytics
                    _showComingSoonDialog(context);
                  },
                ),
                _buildQuickActionButton(
                  context,
                  icon: Icons.settings,
                  label: 'الإعدادات',
                  color: Colors.grey,
                  onTap: () {
                    // Navigate to settings
                    context.go('/settings');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('قريباً'),
        content: Text('هذه الميزة ستكون متاحة قريباً'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }
}