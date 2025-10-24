import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/data_actions_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get counts for tabs
    final doctorsAsync = ref.watch(allDoctorsProvider);
    final distributorsAsync = ref.watch(allDistributorsProvider);
    final usersAsync = ref.watch(allUsersListProvider);
    
    final doctorsCount = doctorsAsync.maybeWhen(
      data: (doctors) => doctors.length,
      orElse: () => 0,
    );
    final distributorsCount = distributorsAsync.maybeWhen(
      data: (distributors) => distributors.length,
      orElse: () => 0,
    );
    final companiesCount = usersAsync.maybeWhen(
      data: (users) => users.where((u) => u.role == 'company').length,
      orElse: () => 0,
    );
    
    return Column(
      children: [
        // TabBar only (AdminScaffold has AppBar)
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 4,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.medical_services),
                text: 'Doctors ($doctorsCount)',
              ),
              Tab(
                icon: const Icon(Icons.local_shipping),
                text: 'Distributors ($distributorsCount)',
              ),
              Tab(
                icon: const Icon(Icons.business),
                text: 'Companies ($companiesCount)',
              ),
            ],
          ),
        ),
        // TabBarView
        Expanded(
          child: TabBarView(
        controller: _tabController,
        children: const [
          _DoctorsTab(),
          _DistributorsTab(),
          _CompaniesTab(),
        ],
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// Doctors Tab
// ===================================================================
class _DoctorsTab extends ConsumerWidget {
  const _DoctorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(allDoctorsProvider);

    return doctorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (doctors) {
        if (doctors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No doctors found'),
              ],
            ),
          );
        }

        // Convert doctors to Map format for export
        final doctorsData = doctors.map((doctor) => {
          'Name': doctor.displayName ?? 'N/A',
          'Email': doctor.email ?? 'N/A',
          'WhatsApp': doctor.whatsappNumber ?? 'N/A',
          'Role': doctor.role,
          'Status': doctor.accountStatus,
          'Governorates': doctor.governorates?.join(', ') ?? 'N/A',
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Export Toolbar
              DataActionsToolbar(
                title: 'Doctors',
                data: doctorsData,
                onRefresh: () => ref.invalidate(allDoctorsProvider),
              ),
              const SizedBox(height: 16),
              // Data Table
              SizedBox(
                width: double.infinity,
                child: PaginatedDataTable(
                  header: const Text('All Doctors'),
                  rowsPerPage: 10,
                  columns: const [
                    DataColumn(label: Text('Photo')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('WhatsApp')),
                    DataColumn(label: Text('Governorates')),
                    DataColumn(label: Text('Document')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: _UsersDataSource(doctors, context, ref, 'doctor'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================================================================
// Distributors Tab
// ===================================================================
class _DistributorsTab extends ConsumerWidget {
  const _DistributorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distributorsAsync = ref.watch(allDistributorsProvider);

    return distributorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (distributors) {
        if (distributors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No distributors found'),
              ],
            ),
          );
        }

        // Convert distributors to Map format for export
        final distributorsData = distributors.map((distributor) => {
          'Name': distributor.displayName ?? 'N/A',
          'Email': distributor.email ?? 'N/A',
          'WhatsApp': distributor.whatsappNumber ?? 'N/A',
          'Role': distributor.role,
          'Status': distributor.accountStatus,
          'Governorates': distributor.governorates?.join(', ') ?? 'N/A',
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Export Toolbar
              DataActionsToolbar(
                title: 'Distributors',
                data: distributorsData,
                onRefresh: () => ref.invalidate(allDistributorsProvider),
              ),
              const SizedBox(height: 16),
              // Data Table
              SizedBox(
                width: double.infinity,
                child: PaginatedDataTable(
                  header: const Text('All Distributors'),
                  rowsPerPage: 10,
                  columns: const [
                    DataColumn(label: Text('Photo')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('WhatsApp')),
                    DataColumn(label: Text('Governorates')),
                    DataColumn(label: Text('Document')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: _UsersDataSource(distributors, context, ref, 'distributor'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================================================================
// Companies Tab
// ===================================================================
class _CompaniesTab extends ConsumerStatefulWidget {
  const _CompaniesTab();

  @override
  ConsumerState<_CompaniesTab> createState() => _CompaniesTabState();
}

class _CompaniesTabState extends ConsumerState<_CompaniesTab> {

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersListProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (users) {
        // Filter companies only
        final companies = users.where((u) => u.role == 'company').toList();

        if (companies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No companies found'),
              ],
            ),
          );
        }

        // Convert companies to Map format for export
        final companiesData = companies.map((company) => {
          'Name': company.displayName ?? 'N/A',
          'Email': company.email ?? 'N/A',
          'WhatsApp': company.whatsappNumber ?? 'N/A',
          'Role': company.role,
          'Status': company.accountStatus,
          'Governorates': company.governorates?.join(', ') ?? 'N/A',
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Export Toolbar
              DataActionsToolbar(
                title: 'Companies',
                data: companiesData,
                onRefresh: () => ref.invalidate(allUsersListProvider),
              ),
              const SizedBox(height: 16),
              // Data Table
              SizedBox(
                width: double.infinity,
                child: PaginatedDataTable(
                  header: const Text('All Companies'),
                  rowsPerPage: 10,
                  columns: const [
                    DataColumn(label: Text('Photo')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('WhatsApp')),
                    DataColumn(label: Text('Governorates')),
                    DataColumn(label: Text('Document')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: _UsersDataSource(companies, context, ref, 'company'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================================================================
// Users Data Source
// ===================================================================
class _UsersDataSource extends DataTableSource {
  _UsersDataSource(this.users, this.context, this.ref, this.userType);

  final List<UserModel> users;
  final BuildContext context;
  final WidgetRef ref;
  final String userType;

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) {
      return null;
    }
    final user = users[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        // Photo
        DataCell(
          user.photoUrl != null && user.photoUrl!.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: user.photoUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircleAvatar(
                      radius: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const CircleAvatar(
                      radius: 20,
                      child: Icon(Icons.person, size: 20),
                    ),
                  ),
                )
              : const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.person, size: 20),
                ),
        ),
        // Name
        DataCell(Text(user.displayName ?? 'N/A')),
        // Email
        DataCell(
          Text(
            user.email ?? 'N/A',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        // WhatsApp
        DataCell(Text(user.whatsappNumber ?? 'N/A')),
        // Governorates
        DataCell(
          Text(
            user.governorates != null && user.governorates!.isNotEmpty
                ? user.governorates!.join(', ')
                : 'N/A',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Document
        DataCell(
          user.documentUrl != null && user.documentUrl!.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.description, color: Colors.blue, size: 20),
                  tooltip: 'View Document',
                  onPressed: () => _showDocumentPreview(user.documentUrl!),
                )
              : const Text('N/A', style: TextStyle(fontSize: 12)),
        ),
        // Status
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(user.accountStatus),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(user.accountStatus),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'View Details',
                onPressed: () => _showUserDetails(user),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Edit Status',
                onPressed: () => _showEditDialog(user),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: 'Delete User',
                onPressed: () => _showDeleteDialog(user),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status ?? 'pending_review') {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending_review':
        return Colors.orange;
      case 'pending_re_review':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String? status) {
    switch (status ?? 'pending_review') {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending_review':
        return 'Pending Review';
      case 'pending_re_review':
        return 'Pending Re-Review';
      default:
        return 'Pending Review';
    }
  }

  void _showDocumentPreview(String documentUrl) {
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
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Document Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Image preview
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: documentUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Failed to load document'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openUrlInBrowser(documentUrl),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open in Browser'),
                          ),
                        ],
                      ),
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

  void _openUrlInBrowser(String url) {
    // يمكن استخدام url_launcher package
    // launch(url);
    print('Open URL: $url');
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                Center(
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.photoUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const CircleAvatar(
                        radius: 50,
                        child: Icon(Icons.person, size: 50),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('Name', user.displayName),
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Role', user.role),
              _buildDetailRow('WhatsApp', user.whatsappNumber ?? 'N/A'),
              _buildDetailRow(
                'Governorates',
                user.governorates != null ? user.governorates!.join(', ') : 'N/A',
              ),
              _buildDetailRow(
                'Centers',
                user.centers != null ? user.centers!.join(', ') : 'N/A',
              ),
              _buildDetailRow('Status', user.accountStatus),
              _buildDetailRow(
                'Profile Complete',
                user.isProfileComplete == true ? 'Yes' : 'No',
              ),
              if (user.documentUrl != null && user.documentUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.description, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Document:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDocumentPreview(user.documentUrl!);
                      },
                      icon: const Icon(Icons.preview, size: 18),
                      label: const Text('View Document'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(UserModel user) {
    String selectedStatus = user.accountStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit User Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${user.displayName ?? user.email ?? "Unknown"}'),
              const SizedBox(height: 16),
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approved'),
                  ),
                  DropdownMenuItem(
                    value: 'pending_review',
                    child: Text('Pending Review'),
                  ),
                  DropdownMenuItem(
                    value: 'pending_re_review',
                    child: Text('Pending Re-Review'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Rejected'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedStatus = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // Show loading indicator
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('Updating status...'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                final repository = ref.read(userRepositoryProvider);
                print('🔄 Updating user ${user.id} status to: $selectedStatus');
                
                final success = await repository.updateUserStatus(
                  user.id,
                  selectedStatus,
                );

                print('✅ Update result: $success');

                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'User status updated successfully to $selectedStatus'
                            : 'Failed to update user status',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  if (success) {
                    print('🔄 Refreshing all user lists...');
                    // Invalidate all user lists to refresh data
                    ref.invalidate(allDoctorsProvider);
                    ref.invalidate(allDistributorsProvider);
                    ref.invalidate(allUsersListProvider);
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this user?'),
            const SizedBox(height: 16),
            Text(
              'Name: ${user.displayName ?? user.email ?? "Unknown"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Email: ${user.email}'),
            Text('Role: ${user.role}'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);

              final repository = ref.read(userRepositoryProvider);
              final success = await repository.deleteUser(user.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'User deleted successfully'
                          : 'Failed to delete user',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );

                if (success) {
                  if (userType == 'doctor') {
                    ref.invalidate(allDoctorsProvider);
                    ref.invalidate(doctorsCountProvider);
                  } else {
                    ref.invalidate(allDistributorsProvider);
                    ref.invalidate(distributorsCountProvider);
                  }
                  ref.invalidate(totalUsersProvider);
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => users.length;

  @override
  int get selectedRowCount => 0;
}
