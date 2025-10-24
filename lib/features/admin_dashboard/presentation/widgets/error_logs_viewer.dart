import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

// Provider for error summary
final errorSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  
  try {
    // Get error summary
    final summary = await supabase
        .from('error_summary_24h')
        .select()
        .limit(10);
    
    // Get total count
    final totalCount = await supabase.rpc('get_error_count_24h');
    
    // Get recent errors
    final recentErrors = await supabase
        .from('error_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(20);
    
    return {
      'summary': summary,
      'total_count': totalCount ?? 0,
      'recent_errors': recentErrors,
    };
  } catch (e) {
    throw Exception('Failed to load error data: $e');
  }
});

class ErrorLogsViewer extends ConsumerWidget {
  const ErrorLogsViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorAsync = ref.watch(errorSummaryProvider);

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
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bug_report, color: Colors.red.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error Logs (24h)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref.invalidate(errorSummaryProvider);
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            errorAsync.when(
              loading: () => const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SizedBox(
                height: 400,
                child: Center(child: Text('Error loading logs: ${err.toString()}')),
              ),
              data: (data) {
                final summary = data['summary'] as List<dynamic>;
                final totalCount = data['total_count'] as int;
                final recentErrors = data['recent_errors'] as List<dynamic>;

                if (totalCount == 0) {
                  return SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No errors in the last 24 hours!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your app is running smoothly 🎉',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Calculate affected users
                final affectedUsers = recentErrors
                    .where((e) => e['user_id'] != null)
                    .map((e) => e['user_id'])
                    .toSet()
                    .length;

                return Column(
                  children: [
                    // Summary Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total Errors',
                            value: totalCount.toString(),
                            icon: Icons.error,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Users Affected',
                            value: affectedUsers.toString(),
                            icon: Icons.people,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Error Types',
                            value: summary.length.toString(),
                            icon: Icons.category,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Error List
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'By Type', icon: Icon(Icons.bar_chart, size: 18)),
                              Tab(text: 'Recent', icon: Icon(Icons.access_time, size: 18)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 300,
                            child: TabBarView(
                              children: [
                                // By Type
                                ListView.separated(
                                  itemCount: summary.length,
                                  separatorBuilder: (context, index) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final item = summary[index];
                                    return _ErrorSummaryItem(
                                      errorType: item['error_type'] as String,
                                      count: item['count'] as int,
                                      affectedUsers: item['affected_users'] as int,
                                      lastOccurrence: DateTime.parse(item['last_occurrence'] as String),
                                    );
                                  },
                                ),
                                // Recent
                                ListView.separated(
                                  itemCount: recentErrors.length,
                                  separatorBuilder: (context, index) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final error = recentErrors[index];
                                    return _ErrorItem(error: error);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorSummaryItem extends StatelessWidget {
  const _ErrorSummaryItem({
    required this.errorType,
    required this.count,
    required this.affectedUsers,
    required this.lastOccurrence,
  });

  final String errorType;
  final int count;
  final int affectedUsers;
  final DateTime lastOccurrence;

  @override
  Widget build(BuildContext context) {
    final timeAgo = timeago.format(lastOccurrence);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.error, color: Colors.red.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.repeat, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$count times',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.people, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$affectedUsers users',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count > 10 ? 'HIGH' : count > 5 ? 'MED' : 'LOW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorItem extends StatelessWidget {
  const _ErrorItem({required this.error});

  final Map<String, dynamic> error;

  @override
  Widget build(BuildContext context) {
    final errorMessage = error['error_message'] as String;
    final route = error['route'] as String?;
    final createdAt = DateTime.parse(error['created_at'] as String);
    final timeAgo = timeago.format(createdAt);

    return InkWell(
      onTap: () => _showErrorDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (route != null)
                    Text(
                      'Route: $route',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow('Type', error['error_type'] ?? 'Unknown'),
                _DetailRow('Message', error['error_message'] ?? 'No message'),
                if (error['route'] != null) _DetailRow('Route', error['route']),
                if (error['user_email'] != null) _DetailRow('User', error['user_email']),
                if (error['platform'] != null) _DetailRow('Platform', error['platform']),
                const SizedBox(height: 16),
                if (error['stack_trace'] != null) ...[
                  const Text(
                    'Stack Trace:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error['stack_trace'],
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
