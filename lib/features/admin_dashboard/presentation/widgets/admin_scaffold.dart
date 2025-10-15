import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/product_management_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/users_management_screen.dart';
import 'package:flutter/material.dart';

class AdminScaffold extends StatefulWidget {
  const AdminScaffold({super.key});

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outlined),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Products'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // This is the main content.
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                // Dashboard Screen
                const AdminDashboardScreen(), 
                // Users Screen
                const UsersManagementScreen(),
                // Products Screen
                const ProductManagementScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
