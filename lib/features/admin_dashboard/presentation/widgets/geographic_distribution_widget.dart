import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';

class GeographicDistributionWidget extends ConsumerWidget {
  const GeographicDistributionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersListProvider);

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
                    color: Colors.cyan.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.map,
                      color: Colors.cyan.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Geographic Distribution',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref.invalidate(allUsersListProvider);
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            _buildContent(usersAsync, ref, context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<UserModel>> usersAsync, WidgetRef ref, BuildContext context) {
    // Handle loading state
    if (usersAsync.isLoading && !usersAsync.hasValue) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Handle error state
    if (usersAsync.hasError && !usersAsync.hasValue) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading data'),
              TextButton(
                onPressed: () {
                  ref.invalidate(allUsersListProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Handle data state
    if (usersAsync.hasValue) {
      final users = usersAsync.value!;
                // Calculate distribution by governorate
                final Map<String, Map<String, int>> govDistribution = {};
                int totalWithGov = 0;

                for (var user in users) {
                  if (user.governorates != null &&
                      user.governorates!.isNotEmpty) {
                    totalWithGov++;
                    for (var gov in user.governorates!) {
                      if (!govDistribution.containsKey(gov)) {
                        govDistribution[gov] = {
                          'total': 0,
                          'doctor': 0,
                          'distributor': 0,
                          'company': 0,
                        };
                      }
                      govDistribution[gov]!['total'] =
                          (govDistribution[gov]!['total'] ?? 0) + 1;
                      govDistribution[gov]![user.role] =
                          (govDistribution[gov]![user.role] ?? 0) + 1;
                    }
                  }
                }

                if (govDistribution.isEmpty) {
                  return const SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No geographic data available'),
                        ],
                      ),
                    ),
                  );
                }

                // Sort by total users (descending)
                final sortedGovs = govDistribution.entries.toList()
                  ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

                // Top 3 governorates
                final top3 = sortedGovs.take(3).toList();

                return Column(
                  children: [
                    // Summary Stats
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'Total Governorates',
                            value: govDistribution.length.toString(),
                            icon: Icons.location_city,
                            color: Colors.cyan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Users with Location',
                            value: totalWithGov.toString(),
                            icon: Icons.people,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Coverage',
                            value:
                                '${(totalWithGov / users.length * 100).toStringAsFixed(0)}%',
                            icon: Icons.pie_chart,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Top 3 Governorates
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top 3 Governorates',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: top3.asMap().entries.map((entry) {
                              final index = entry.key;
                              final gov = entry.value;
                              final medal = index == 0
                                  ? '🥇'
                                  : index == 1
                                      ? '🥈'
                                      : '🥉';
                              return Expanded(
                                child: _TopGovCard(
                                  rank: medal,
                                  name: gov.key,
                                  count: gov.value['total']!,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // All Governorates List
                    SizedBox(
                      height: 400,
                      child: ListView.separated(
                        itemCount: sortedGovs.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final entry = sortedGovs[index];
                          final govName = entry.key;
                          final data = entry.value;
                          final total = data['total']!;
                          final percentage =
                              (total / totalWithGov * 100).toStringAsFixed(1);

                          return _GovernorateItem(
                            name: govName,
                            total: total,
                            percentage: percentage,
                            doctors: data['doctor'] ?? 0,
                            distributors: data['distributor'] ?? 0,
                            companies: data['company'] ?? 0,
                          );
                        },
                      ),
                    ),
                  ],
                );
    }

    // Fallback - should never reach here
    return const SizedBox(
      height: 400,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TopGovCard extends StatelessWidget {
  const _TopGovCard({
    required this.rank,
    required this.name,
    required this.count,
  });

  final String rank;
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              rank,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$count users',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GovernorateItem extends StatelessWidget {
  const _GovernorateItem({
    required this.name,
    required this.total,
    required this.percentage,
    required this.doctors,
    required this.distributors,
    required this.companies,
  });

  final String name;
  final int total;
  final String percentage;
  final int doctors;
  final int distributors;
  final int companies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.cyan.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(Icons.location_on,
                  color: Colors.cyan.shade700, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          // Name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _RoleBadge(
                        icon: Icons.medical_services,
                        count: doctors,
                        color: Colors.green),
                    const SizedBox(width: 8),
                    _RoleBadge(
                        icon: Icons.local_shipping,
                        count: distributors,
                        color: Colors.purple),
                    const SizedBox(width: 8),
                    _RoleBadge(
                        icon: Icons.business,
                        count: companies,
                        color: Colors.teal),
                  ],
                ),
              ],
            ),
          ),
          // Count and percentage
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Progress bar
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: double.parse(percentage) / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan.shade400),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
