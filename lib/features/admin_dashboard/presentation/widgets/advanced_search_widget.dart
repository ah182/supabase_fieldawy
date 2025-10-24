import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';

class AdvancedSearchWidget extends ConsumerStatefulWidget {
  const AdvancedSearchWidget({super.key});

  @override
  ConsumerState<AdvancedSearchWidget> createState() => _AdvancedSearchWidgetState();
}

class _AdvancedSearchWidgetState extends ConsumerState<AdvancedSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'users', 'products'

  @override
  void dispose() {
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
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.search,
                      color: Colors.indigo.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Advanced Search',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Search bar with category filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search across all dashboard data...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'all',
                      label: Text('All'),
                      icon: Icon(Icons.all_inclusive, size: 16),
                    ),
                    ButtonSegment(
                      value: 'users',
                      label: Text('Users'),
                      icon: Icon(Icons.people, size: 16),
                    ),
                    ButtonSegment(
                      value: 'products',
                      label: Text('Products'),
                      icon: Icon(Icons.inventory_2, size: 16),
                    ),
                  ],
                  selected: {_selectedCategory},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedCategory = newSelection.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Search results
            if (_searchQuery.isEmpty)
              _buildEmptyState()
            else
              Expanded(
                child: _buildSearchResults(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Start typing to search...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for users, products, and more',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedCategory == 'all' || _selectedCategory == 'users')
            _buildUsersSection(),
          if (_selectedCategory == 'all' || _selectedCategory == 'products')
            _buildProductsSection(),
        ],
      ),
    );
  }

  Widget _buildUsersSection() {
    final usersAsync = ref.watch(allUsersListProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: ${err.toString()}'),
      data: (users) {
        final filteredUsers = users.where((user) {
          final query = _searchQuery.toLowerCase();
          return (user.displayName?.toLowerCase().contains(query) ?? false) ||
              (user.email?.toLowerCase().contains(query) ?? false) ||
              (user.role.toLowerCase().contains(query));
        }).toList();

        if (filteredUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Users',
              count: filteredUsers.length,
              icon: Icons.people,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            ...filteredUsers.take(5).map((user) => _UserResultItem(user: user)),
            if (filteredUsers.length > 5)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      // Navigate to Users Management
                    },
                    child: Text('View all ${filteredUsers.length} users →'),
                  ),
                ),
              ),
            const Divider(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildProductsSection() {
    final productsAsync = ref.watch(adminAllProductsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: ${err.toString()}'),
      data: (products) {
        final filteredProducts = products.where((product) {
          final query = _searchQuery.toLowerCase();
          return product.name.toLowerCase().contains(query) ||
              (product.company?.toLowerCase().contains(query) ?? false) ||
              (product.activePrinciple?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (filteredProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Products',
              count: filteredProducts.length,
              icon: Icons.inventory_2,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            ...filteredProducts.take(5).map((product) => _ProductResultItem(product: product)),
            if (filteredProducts.length > 5)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      // Navigate to Products Management
                    },
                    child: Text('View all ${filteredProducts.length} products →'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserResultItem extends StatelessWidget {
  const _UserResultItem({required this.user});

  final user;

  @override
  Widget build(BuildContext context) {
    final icon = user.role == 'doctor'
        ? Icons.medical_services
        : user.role == 'distributor'
            ? Icons.local_shipping
            : user.role == 'company'
                ? Icons.business
                : Icons.person;

    final color = user.role == 'doctor'
        ? Colors.green
        : user.role == 'distributor'
            ? Colors.purple
            : user.role == 'company'
                ? Colors.teal
                : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          user.displayName ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email ?? 'No email'),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.circle, size: 8, color: _getStatusColor(user.accountStatus)),
                const SizedBox(width: 4),
                Text(
                  user.accountStatus,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to user details
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending_review':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _ProductResultItem extends StatelessWidget {
  const _ProductResultItem({required this.product});

  final product;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: product.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported),
                  ),
                )
              : const Icon(Icons.inventory_2),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.company != null) Text('Company: ${product.company}'),
            if (product.activePrinciple != null)
              Text('Active: ${product.activePrinciple}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        trailing: product.price != null
            ? Text(
                '${product.price!.toStringAsFixed(0)} LE',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : null,
        onTap: () {
          // Navigate to product details
        },
      ),
    );
  }
}
