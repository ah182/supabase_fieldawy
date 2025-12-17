import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_builder/responsive_builder.dart';

class PendingApprovalsWidget extends ConsumerWidget {
  const PendingApprovalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersListProvider);

    // Handle loading
    if (usersAsync.isLoading && !usersAsync.hasValue) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Handle error
    if (usersAsync.hasError && !usersAsync.hasValue) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error: ${usersAsync.error.toString()}'),
        ),
      );
    }

    // Handle data
    if (usersAsync.hasValue) {
      final users = usersAsync.value!;
        final pendingUsers = users
            .where((u) => u.accountStatus == 'pending_review' || u.accountStatus == 'pending_re_review')
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
                              fontSize: 20
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
          child: ResponsiveBuilder(
            builder: (context, sizingInformation) {
              final isMobile = sizingInformation.isMobile;
              
              return Padding(
                padding: EdgeInsets.all(isMobile ? 11.0 : 24.0),
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
                              color: Colors.orange.shade700, size: isMobile ? 24 : 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending Approvals',
                                style: isMobile 
                                    ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                                    : Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$totalPending requests waiting for review',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: isMobile ? 12 : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (!isMobile) // Show refresh button only on non-mobile or use icon only
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
                        ) else
                        IconButton(
                          onPressed: () {
                            ref.invalidate(allUsersListProvider);
                          },
                          icon: const Icon(Icons.refresh, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Pending counts
                    if (isMobile) ...[
                      _PendingCount(
                        icon: Icons.medical_services,
                        label: 'Doctors',
                        count: pendingDoctors.length,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _PendingCount(
                        icon: Icons.local_shipping,
                        label: 'Distributors',
                        count: pendingDistributors.length,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 8),
                      _PendingCount(
                        icon: Icons.business,
                        label: 'Companies',
                        count: pendingCompanies.length,
                        color: Colors.teal,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _PendingCount(
                              icon: Icons.medical_services,
                              label: 'Doctors',
                              count: pendingDoctors.length,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PendingCount(
                              icon: Icons.local_shipping,
                              label: 'Distributors',
                              count: pendingDistributors.length,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PendingCount(
                              icon: Icons.business,
                              label: 'Companies',
                              count: pendingCompanies.length,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Pending list
                    ...pendingDoctors.take(3).map((user) => _UserPendingItem(
                          user: user,
                          onApprove: () => _approveUser(ref, user),
                          onReject: () => _rejectUser(context, ref, user),
                        )),
                    ...pendingDistributors.take(3).map((user) => _UserPendingItem(
                          user: user,
                          onApprove: () => _approveUser(ref, user),
                          onReject: () => _rejectUser(context, ref, user),
                        )),
                    ...pendingCompanies.take(3).map((user) => _UserPendingItem(
                          user: user,
                          onApprove: () => _approveUser(ref, user),
                          onReject: () => _rejectUser(context, ref, user),
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
              );
            },
          ),
        );
    }
    // Fallback
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      ),
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

  Future<void> _rejectUser(BuildContext context, WidgetRef ref, UserModel user) async {
    print('Open reject dialog for user: ${user.id}');
    final reasonController = TextEditingController();

    return showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Rejection reason...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(userRepositoryProvider).updateUserStatus(
                        user.id,
                        'rejected',
                        rejectionReason: reasonController.text,
                      );
                  ref.invalidate(allUsersListProvider);
                } catch (e) {
                  debugPrint('Error rejecting user: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  static void _showDocumentDialog(BuildContext context, String documentUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'User Document',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              // Image
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      documentUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text('Failed to load document'),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  // Open in new tab
                                  // ignore: avoid_print
                                  print('Open URL: $documentUrl');
                                },
                                child: const Text('Open in new tab'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (user.documentUrl != null)
            IconButton(
              icon: const Icon(Icons.description, size: 20),
              onPressed: () {
                PendingApprovalsWidget._showDocumentDialog(context, user.documentUrl!);
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
