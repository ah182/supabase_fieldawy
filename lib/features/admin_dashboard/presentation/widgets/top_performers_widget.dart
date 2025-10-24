import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/admin_dashboard/data/analytics_repository.dart';

class TopPerformersWidget extends ConsumerStatefulWidget {
  const TopPerformersWidget({super.key});

  @override
  ConsumerState<TopPerformersWidget> createState() => _TopPerformersWidgetState();
}

class _TopPerformersWidgetState extends ConsumerState<TopPerformersWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.emoji_events,
                      color: Colors.amber.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Top Performers',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users or products...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Top Products', icon: Icon(Icons.inventory_2)),
                Tab(text: 'Top Users', icon: Icon(Icons.people)),
              ],
            ),
            const SizedBox(height: 16),
            // TabBarView
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductsTab(),
                  _buildUsersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_searchQuery.isNotEmpty) {
      // Search mode
      final searchAsync = ref.watch(searchProductStatsProvider(_searchQuery));
      return searchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
        data: (products) => _buildProductsList(products, isSearch: true),
      );
    } else {
      // Top 10 mode
      final topAsync = ref.watch(topProductsByViewsProvider(10));
      return topAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
        data: (products) => _buildProductsList(products),
      );
    }
  }

  Widget _buildProductsList(List<ProductPerformanceStats> products,
      {bool isSearch = false}) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No products found' : 'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final product = products[index];
        final rank = index + 1;
        
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor(rank),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isSearch ? '•' : '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            product.productName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.company != null)
                Text('Company: ${product.company}'),
              Text('Distributor: ${product.distributorName ?? "N/A"}'),
              Row(
                children: [
                  Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${product.totalViews} views'),
                  const SizedBox(width: 16),
                  Icon(Icons.medical_services, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('${product.doctorViews} doctor views'),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (product.price != null)
                Text(
                  '${product.price!.toStringAsFixed(0)} LE',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              Text(
                '${product.distributorCount} distributors',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          onTap: () => _showProductDetails(product),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    if (_searchQuery.isNotEmpty) {
      // Search mode
      final searchAsync = ref.watch(searchUserStatsProvider(_searchQuery));
      return searchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
        data: (users) => _buildUsersList(users, isSearch: true),
      );
    } else {
      // Top 10 mode
      final topAsync = ref.watch(topUsersByActivityProvider(
          TopUsersParams(role: null, limit: 10)));
      return topAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
        data: (users) => _buildUsersList(users),
      );
    }
  }

  Widget _buildUsersList(List<UserActivityStats> users,
      {bool isSearch = false}) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No users found' : 'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final user = users[index];
        final rank = index + 1;

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor(rank),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isSearch ? '•' : '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            user.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email ?? 'No email'),
              Row(
                children: [
                  _getRoleChip(user.role),
                  const SizedBox(width: 8),
                  Icon(Icons.search, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${user.totalSearches} searches'),
                  const SizedBox(width: 12),
                  Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${user.totalViews} views'),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.totalActivity}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                'Total Activity',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          onTap: () => _showUserDetails(user),
        );
      },
    );
  }

  Widget _getRoleChip(String role) {
    Color color;
    IconData icon;

    switch (role) {
      case 'doctor':
        color = Colors.green;
        icon = Icons.medical_services;
        break;
      case 'distributor':
        color = Colors.purple;
        icon = Icons.local_shipping;
        break;
      case 'company':
        color = Colors.teal;
        icon = Icons.business;
        break;
      default:
        color = Colors.grey;
        icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600; // Gold
      case 2:
        return Colors.grey.shade500; // Silver
      case 3:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors.blue.shade400;
    }
  }

  void _showProductDetails(ProductPerformanceStats product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.productName),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Company', product.company ?? 'N/A'),
              _DetailRow('Price', product.price != null ? '${product.price} LE' : 'N/A'),
              _DetailRow('Distributor', product.distributorName ?? 'N/A'),
              const Divider(),
              _DetailRow('Total Views', '${product.totalViews}'),
              _DetailRow('Doctor Views', '${product.doctorViews}'),
              _DetailRow('Distributors Count', '${product.distributorCount}'),
              if (product.lastViewedAt != null)
                _DetailRow('Last Viewed', product.lastViewedAt.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserActivityStats user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.displayName),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Email', user.email ?? 'N/A'),
              _DetailRow('Role', user.role.toUpperCase()),
              const Divider(),
              _DetailRow('Total Searches', '${user.totalSearches}'),
              _DetailRow('Total Views', '${user.totalViews}'),
              _DetailRow('Total Products', '${user.totalProducts}'),
              _DetailRow('Total Activity', '${user.totalActivity}'),
              const Divider(),
              _DetailRow('Last Activity', user.lastActivityAt.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
