import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/users_management_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/product_management_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/analytics_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin Dashboard الكامل للويب - مع Navigation و Sidebar
class CompleteAdminDashboardScreen extends ConsumerStatefulWidget {
  const CompleteAdminDashboardScreen({super.key});

  @override
  ConsumerState<CompleteAdminDashboardScreen> createState() =>
      _CompleteAdminDashboardScreenState();
}

class _CompleteAdminDashboardScreenState
    extends ConsumerState<CompleteAdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavigationItem> _navItems = [
    _NavigationItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      screen: const AdminDashboardScreen(),
    ),
    _NavigationItem(
      icon: Icons.people,
      label: 'Users Management',
      screen: const UsersManagementScreen(),
    ),
    _NavigationItem(
      icon: Icons.inventory,
      label: 'Products Management',
      screen: const ProductManagementScreen(),
    ),
    _NavigationItem(
      icon: Icons.analytics,
      label: 'Analytics',
      screen: const AnalyticsDashboardScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _navItems[_selectedIndex].screen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      extended: MediaQuery.of(context).size.width > 1200,
      labelType: NavigationRailLabelType.none,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 2,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 32,
              ),
            ),
            if (MediaQuery.of(context).size.width > 1200) ...[
              const SizedBox(height: 12),
              const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: _navItems
          .map((item) => NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.icon),
                label: Text(item.label),
              ))
          .toList(),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.of(context).pop();
              },
              tooltip: 'Exit Dashboard',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          children: [
            Text(
              _navItems[_selectedIndex].label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Search Bar
            SizedBox(
              width: 300,
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Notifications
            IconButton(
              icon: const Badge(
                label: Text('3'),
                child: Icon(Icons.notifications_outlined),
              ),
              onPressed: () {},
              tooltip: 'Notifications',
            ),
            const SizedBox(width: 8),
            // Profile
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Text(
                'A',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;
  final Widget screen;

  _NavigationItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
