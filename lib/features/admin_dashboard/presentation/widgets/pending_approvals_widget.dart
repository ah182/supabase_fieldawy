import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingApprovalsWidget extends ConsumerWidget {
  const PendingApprovalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersListProvider);

    return usersAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error: ${err.toString()}'),
        ),
      ),
      data: (users) {
        final pendingUsers = users
            .where((u) => u.accountStatus == 'pending_review')
            .toList();

        final pendingDoctors =
            pendingUsers.where((u) => u.role == 'doctor').toList();
        final pendingDistributors =
            pendingUsers.where((u) => u.role == 'distributor').toList();
        final pendingCompanies =
            pendingUsers.where((u) => u.role == 'company').toList();

        final totalPending = pendingUsers.length;

        if (totalPending == 0) {
          return Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'No Pending Approvals',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('All user requests have been reviewed! 🎉'),
                ],
              ),
            ),
          );
        }

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
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.pending_actions,
                          color: Colors.orange.shade700, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Approvals',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '$totalPending requests waiting for review',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(allUsersListProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Pending counts
                Row(
                  children: [
                    _PendingCount(
                      icon: Icons.medical_services,
                      label: 'Doctors',
                      count: pendingDoctors.length,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _PendingCount(
                      icon: Icons.local_shipping,
                      label: 'Distributors',
                      count: pendingDistributors.length,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 16),
                    _PendingCount(
                      icon: Icons.business,
                      label: 'Companies',
                      count: pendingCompanies.length,
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Pending list
                ...pendingDoctors.take(3).map((user) => _UserPendingItem(
                      user: user,
                      onApprove: () => _approveUser(ref, user),
                      onReject: () => _rejectUser(ref, user),
                    )),
                ...pendingDistributors.take(3).map((user) => _UserPendingItem(
                      user: user,
                      onApprove: () => _approveUser(ref, user),
                      onReject: () => _rejectUser(ref, user),
                    )),
                ...pendingCompanies.take(3).map((user) => _UserPendingItem(
                      user: user,
                      onApprove: () => _approveUser(ref, user),
                      onReject: () => _rejectUser(ref, user),
                    )),
                if (totalPending > 9) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // Navigate to Users Management
                        // You can implement navigation here
                      },
                      child: Text('View all $totalPending pending requests →'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveUser(WidgetRef ref, UserModel user) async {
    try {
      await ref
          .read(userRepositoryProvider)
          .updateUserStatus(user.id, 'approved');
      ref.invalidate(allUsersListProvider);
    } catch (e) {
      // Handle error
      debugPrint('Error approving user: $e');
    }
  }

  Future<void> _rejectUser(WidgetRef ref, UserModel user) async {
    try {
      await ref
          .read(userRepositoryProvider)
          .updateUserStatus(user.id, 'rejected');
      ref.invalidate(allUsersListProvider);
    } catch (e) {
      // Handle error
      debugPrint('Error rejecting user: $e');
    }
  }
}

class _PendingCount extends StatelessWidget {
  const _PendingCount({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserPendingItem extends StatelessWidget {
  const _UserPendingItem({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final UserModel user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final icon = user.role == 'doctor'
        ? Icons.medical_services
        : user.role == 'distributor'
            ? Icons.local_shipping
            : Icons.business;

    final color = user.role == 'doctor'
        ? Colors.green
        : user.role == 'distributor'
            ? Colors.purple
            : Colors.teal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  user.email ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (user.documentUrl != null)
            IconButton(
              icon: const Icon(Icons.description, size: 20),
              onPressed: () {
                // View document
              },
              tooltip: 'View Document',
            ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: onApprove,
            tooltip: 'Approve',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: onReject,
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }
}
