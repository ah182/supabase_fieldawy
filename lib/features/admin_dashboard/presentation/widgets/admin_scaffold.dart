import 'package:fieldawy_store/core/localization/language_provider.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/product_management_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/users_management_screen.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/analytics_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminScaffold extends ConsumerStatefulWidget {
  const AdminScaffold({super.key});

  @override
  ConsumerState<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends ConsumerState<AdminScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isArabic = locale.languageCode == 'ar';

    final List<String> pageTitles = isArabic
        ? [
            'لوحة التحكم',
            'إدارة المستخدمين',
            'إدارة المنتجات',
            'التحليلات والإحصائيات',
          ]
        : [
            'Dashboard',
            'Users Management',
            'Products Management',
            'Analytics & Insights',
          ];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(pageTitles[_selectedIndex]),
          actions: [
            // Language Toggle Button
            Tooltip(
              message: isArabic ? 'Switch to English' : 'التبديل إلى العربية',
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'ar',
                      label: Text('ع'),
                      icon: Icon(Icons.language, size: 16),
                    ),
                    ButtonSegment(
                      value: 'en',
                      label: Text('EN'),
                      icon: Icon(Icons.language, size: 16),
                    ),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (Set<String> newSelection) {
                    final newLocale = Locale(newSelection.first);
                    ref.read(languageProvider.notifier).setLocale(newLocale);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
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
              destinations: <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: Text(isArabic ? 'لوحة التحكم' : 'Dashboard'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.people_outlined),
                  selectedIcon: const Icon(Icons.people),
                  label: Text(isArabic ? 'المستخدمين' : 'Users'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2),
                  label: Text(isArabic ? 'المنتجات' : 'Products'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.analytics_outlined),
                  selectedIcon: const Icon(Icons.analytics),
                  label: Text(isArabic ? 'التحليلات' : 'Analytics'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // This is the main content.
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  // Dashboard Screen
                  AdminDashboardScreen(), 
                  // Users Screen
                  UsersManagementScreen(),
                  // Products Screen
                  ProductManagementScreen(),
                  // Analytics Screen
                  AnalyticsDashboardScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
