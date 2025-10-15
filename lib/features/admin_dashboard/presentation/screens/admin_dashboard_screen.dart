import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
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
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
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
                data: (products) => _StatCard(
                  title: 'Total Products',
                  value: products.length.toString(),
                  icon: Icons.inventory_2,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
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
