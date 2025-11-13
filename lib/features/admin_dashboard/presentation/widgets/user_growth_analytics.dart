import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/admin_dashboard/data/analytics_repository.dart';
import 'package:intl/intl.dart';

class UserGrowthAnalytics extends ConsumerStatefulWidget {
  const UserGrowthAnalytics({super.key});

  @override
  ConsumerState<UserGrowthAnalytics> createState() => _UserGrowthAnalyticsState();
}

class _UserGrowthAnalyticsState extends ConsumerState<UserGrowthAnalytics> {
  String _selectedPeriod = '7days'; // '7days' or '30days'

  @override
  Widget build(BuildContext context) {
    final growthAsync = _selectedPeriod == '7days'
        ? ref.watch(userGrowthLast7DaysProvider)
        : ref.watch(userGrowthLast30DaysProvider);

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
                  child: Icon(Icons.trending_up,
                      color: Colors.green.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'User Growth Analytics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Period selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: '7days',
                      label: Text('Last 7 Days'),
                      icon: Icon(Icons.calendar_today, size: 16),
                    ),
                    ButtonSegment(
                      value: '30days',
                      label: Text('Last 30 Days'),
                      icon: Icon(Icons.calendar_month, size: 16),
                    ),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedPeriod = newSelection.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Charts
            growthAsync.when(
              loading: () => const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading growth data'),
                      TextButton(
                        onPressed: () {
                          ref.invalidate(userGrowthLast7DaysProvider);
                          ref.invalidate(userGrowthLast30DaysProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (growthData) {
                if (growthData.isEmpty) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: Text('No growth data available'),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Summary Stats
                    _buildSummaryStats(growthData),
                    const SizedBox(height: 24),
                    // Line Chart
                    _buildLineChart(growthData),
                    const SizedBox(height: 24),
                    // Bar Chart by Role
                    _buildBarChart(growthData),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats(List<UserGrowthData> data) {
    final totalNewUsers = data.fold<int>(0, (sum, item) => sum + item.newUsers);
    final totalDoctors = data.fold<int>(0, (sum, item) => sum + item.byRole['doctor']!);
    final totalDistributors = data.fold<int>(0, (sum, item) => sum + item.byRole['distributor']!);
    final totalCompanies = data.fold<int>(0, (sum, item) => sum + item.byRole['company']!);

    final growthRate = data.length > 1
        ? ((data.last.totalUsers - data.first.totalUsers) / data.first.totalUsers * 100)
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'New Users',
            value: '$totalNewUsers',
            icon: Icons.person_add,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Doctors',
            value: '$totalDoctors',
            icon: Icons.medical_services,
            color: Colors.green,
            subtitle: '${(totalDoctors / totalNewUsers * 100).toStringAsFixed(0)}%',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Distributors',
            value: '$totalDistributors',
            icon: Icons.local_shipping,
            color: Colors.purple,
            subtitle: '${(totalDistributors / totalNewUsers * 100).toStringAsFixed(0)}%',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Companies',
            value: '$totalCompanies',
            icon: Icons.business,
            color: Colors.teal,
            subtitle: '${(totalCompanies / totalNewUsers * 100).toStringAsFixed(0)}%',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Growth Rate',
            value: '${growthRate.toStringAsFixed(1)}%',
            icon: growthRate >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            color: growthRate >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(List<UserGrowthData> data) {
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.newUsers.toDouble());
    }).toList();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < data.length) {
                    final date = data[value.toInt()].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<UserGrowthData> data) {
    // Aggregate by role
    final doctors = data.fold<int>(0, (sum, item) => sum + item.byRole['doctor']!);
    final distributors = data.fold<int>(0, (sum, item) => sum + item.byRole['distributor']!);
    final companies = data.fold<int>(0, (sum, item) => sum + item.byRole['company']!);
    final viewers = data.fold<int>(0, (sum, item) => sum + item.byRole['viewer']!);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: [doctors, distributors, companies, viewers].reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(
                toY: doctors.toDouble(),
                color: Colors.green,
                width: 40,
              ),
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(
                toY: distributors.toDouble(),
                color: Colors.purple,
                width: 40,
              ),
            ]),
            BarChartGroupData(x: 2, barRods: [
              BarChartRodData(
                toY: companies.toDouble(),
                color: Colors.teal,
                width: 40,
              ),
            ]),
            BarChartGroupData(x: 3, barRods: [
              BarChartRodData(
                toY: viewers.toDouble(),
                color: Colors.orange,
                width: 40,
              ),
            ]),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text('Doctors', style: TextStyle(fontSize: 12));
                    case 1:
                      return const Text('Distributors', style: TextStyle(fontSize: 12));
                    case 2:
                      return const Text('Companies', style: TextStyle(fontSize: 12));
                    case 3:
                      return const Text('Viewers', style: TextStyle(fontSize: 12));
                    default:
                      return const Text('');
                  }
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
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
          ),
          if (subtitle != null)
            Text(
              subtitle!,
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
}


