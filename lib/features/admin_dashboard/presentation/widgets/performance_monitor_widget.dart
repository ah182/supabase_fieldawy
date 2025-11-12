import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider for performance summary
final performanceSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  
  try {
    // Get summary from view
    final summary = await supabase
        .from('performance_summary_24h')
        .select()
        .limit(10);
    
    // Get overall stats
    final avgTime = await supabase.rpc('get_avg_api_time_24h');
    
    return {
      'summary': summary,
      'avg_time': avgTime ?? 0,
    };
  } catch (e) {
    throw Exception('Failed to load performance data: $e');
  }
});

class PerformanceMonitorWidget extends ConsumerWidget {
  const PerformanceMonitorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(performanceSummaryProvider);

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
                  child: Icon(Icons.speed, color: Colors.blue.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Performance Monitor (24h)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref.invalidate(performanceSummaryProvider);
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            performanceAsync.when(
              loading: () => const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SizedBox(
                height: 300,
                child: Center(child: Text('Error: ${err.toString()}')),
              ),
              data: (data) {
                final summary = data['summary'] as List<dynamic>;
                final avgTime = data['avg_time'] as int;

                if (summary.isEmpty) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No performance data yet'),
                          SizedBox(height: 8),
                          Text(
                            'Data will appear as users use the app',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Calculate stats
                final totalCalls = summary.fold<int>(
                    0, (sum, item) => sum + (item['call_count'] as int));
                final avgDuration = avgTime;

                return Column(
                  children: [
                    // Summary Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Avg Response',
                            value: '${avgDuration}ms',
                            icon: Icons.timer,
                            color: _getColorForDuration(avgDuration),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Total Calls',
                            value: totalCalls.toString(),
                            icon: Icons.api,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // API List
                    SizedBox(
                      height: 300,
                      child: ListView.separated(
                        itemCount: summary.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = summary[index];
                          return _ApiItem(
                            name: item['metric_name'] as String,
                            avgDuration: item['avg_duration'] as int,
                            maxDuration: item['max_duration'] as int,
                            callCount: item['call_count'] as int,
                            errorCount: item['error_count'] as int,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForDuration(int ms) {
    if (ms < 300) return Colors.green;
    if (ms < 800) return Colors.orange;
    return Colors.red;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
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
            ],
          ),
        ],
      ),
    );
  }
}

class _ApiItem extends StatelessWidget {
  const _ApiItem({
    required this.name,
    required this.avgDuration,
    required this.maxDuration,
    required this.callCount,
    required this.errorCount,
  });

  final String name;
  final int avgDuration;
  final int maxDuration;
  final int callCount;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final color = _getColorForDuration(avgDuration);
    final hasErrors = errorCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasErrors ? Icons.warning : Icons.check_circle,
              color: hasErrors ? Colors.orange : color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.call_made, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$callCount calls',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (hasErrors) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.error, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$errorCount errors',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Duration
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '${avgDuration}ms',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    avgDuration < 300
                        ? Icons.arrow_downward
                        : avgDuration > 800
                            ? Icons.arrow_upward
                            : Icons.remove,
                    size: 16,
                    color: color,
                  ),
                ],
              ),
              Text(
                'max: ${maxDuration}ms',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorForDuration(int ms) {
    if (ms < 300) return Colors.green;
    if (ms < 800) return Colors.orange;
    return Colors.red;
  }
}


