import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/dashboard/application/dashboard_provider.dart';

class AlertsNotificationsWidget extends ConsumerWidget {
  const AlertsNotificationsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringProductsAsync = ref.watch(expiringProductsProvider);

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
                Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  'تنبيهات هامة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            expiringProductsAsync.when(
              data: (products) {
                List<Widget> alerts = [];

                // Add expiring products alerts
                if (products.isNotEmpty) {
                  alerts.add(_buildAlert(
                    icon: Icons.schedule,
                    title: 'منتجات قاربت على الانتهاء',
                    subtitle: '${products.length} منتج ينتهي خلال سنة',
                    color: Colors.orange,
                    onTap: () {
                      _showExpiringProductsDialog(context, products);
                    },
                  ));
                }

                // Add other mock alerts
                alerts.addAll([
                  _buildAlert(
                    icon: Icons.inventory,
                    title: 'مخزون منخفض',
                    subtitle: 'تحقق من المخزون المتاح',
                    color: Colors.red,
                    onTap: () {},
                  ),
                  _buildAlert(
                    icon: Icons.trending_up,
                    title: 'فرصة تسويقية',
                    subtitle: 'منتجات لها طلب عالي',
                    color: Colors.green,
                    onTap: () {},
                  ),
                ]);

                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.green),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد تنبيهات',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return Column(children: alerts);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'خطأ في تحميل التنبيهات',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlert({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpiringProductsDialog(BuildContext context, List<Map<String, dynamic>> products) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('منتجات قاربت على الانتهاء'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final expiryDate = DateTime.tryParse(product['expiry_date'] ?? '');
              return ListTile(
                title: Text(product['name'] ?? 'منتج غير معروف'),
                subtitle: Text(
                  'ينتهي في: ${expiryDate != null ? DateFormat('yyyy/MM/dd').format(expiryDate) : 'غير محدد'}',
                ),
                leading: Icon(Icons.medication, color: Colors.orange),
              );
            },
          ),
        ),
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