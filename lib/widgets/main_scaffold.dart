
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:fieldawy_store/features/category/presentation/screens/category_screen.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/my_products_screen.dart';
import 'package:fieldawy_store/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/profile_screen.dart';
import 'package:fieldawy_store/features/settings/presentation/screens/settings_screen.dart';

class MainScaffold extends ConsumerWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final int selectedIndex;
  final Widget? floatingActionButton;

  const MainScaffold({
    Key? key,
    required this.body,
    this.appBar,
    required this.selectedIndex,
    this.floatingActionButton,
  }) : super(key: key);

  void _onItemTapped(BuildContext context, WidgetRef ref, int index) {
    if (index == selectedIndex) return;

    final userRole = ref.read(userDataProvider).asData?.value?.role ?? '';

    Widget screen;
    if (userRole == 'distributor' || userRole == 'company') {
      switch (index) {
        case 0:
          screen = const MyProductsScreen();
          break;
        case 1:
          screen = const DashboardPage();
          break;
        case 2:
          screen = const ProfileScreen();
          break;
        case 3:
          screen = const SettingsScreen();
          break;
        default:
          screen = const MyProductsScreen();
      }
    } else { // doctor
      switch (index) {
        case 0:
          screen = const DistributorsScreen();
          break;
        case 1:
          screen = const CategoryScreen();
          break;
        case 2:
          screen = const ProfileScreen();
          break;
        case 3:
          screen = const SettingsScreen();
          break;
        default:
          screen = const DistributorsScreen();
      }
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userDataProvider);

    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: userData.when(
        data: (user) {
          final isDistributor = user?.role == 'distributor' || user?.role == 'company';
          final isDoctor = user?.role == 'doctor';

          return SalomonBottomBar(
            currentIndex: selectedIndex,
            onTap: (index) => _onItemTapped(context, ref, index),
            items: [
              if (isDistributor)
                SalomonBottomBarItem(
                  icon: const Icon(Icons.production_quantity_limits),
                  title: const Text("Products"),
                  selectedColor: Colors.purple,
                ),
              if (isDoctor)
                SalomonBottomBarItem(
                  icon: const Icon(Icons.store),
                  title: const Text("Distributors"),
                  selectedColor: Colors.orange,
                ),
              if (isDistributor)
                SalomonBottomBarItem(
                  icon: const Icon(Icons.dashboard),
                  title: const Text("Dashboard"),
                  selectedColor: Colors.pink,
                )
              else
                SalomonBottomBarItem(
                  icon: const Icon(Icons.category),
                  title: const Text("Categories"),
                  selectedColor: Colors.pink,
                ),
              SalomonBottomBarItem(
                icon: const Icon(Icons.person),
                title: const Text("Profile"),
                selectedColor: Colors.teal,
              ),
              SalomonBottomBarItem(
                icon: const Icon(Icons.settings),
                title: const Text("Settings"),
                selectedColor: Colors.blue,
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (err, stack) => const SizedBox.shrink(),
      ),
    );
  }
}
