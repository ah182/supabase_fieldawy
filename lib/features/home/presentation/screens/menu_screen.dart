import 'package:fieldawy_store/features/clinics/presentation/screens/clinics_map_screen.dart';

// ignore: unused_import
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/admin_dashboard/presentation/widgets/admin_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/theme/app_theme.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/settings/presentation/screens/settings_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_screen.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/presentation/screens/my_products_screen.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:fieldawy_store/features/orders/presentation/screens/orders_screen.dart';
import 'package:fieldawy_store/features/reviews/products_reviews_screen.dart';
import 'package:fieldawy_store/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fieldawy_store/features/jobs/presentation/screens/job_offers_screen.dart';
import 'package:fieldawy_store/features/vet_supplies/presentation/screens/vet_supplies_screen.dart';
import 'package:fieldawy_store/features/analytics/presentation/pages/analytics_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/admin_dashboard/presentation/screens/admin_dashboard_screen.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 36.0, 24.0, 16.0),
              child: userDataAsync.when(
                data: (user) => _buildMenuHeader(context, ref, user),
                loading: () => const Center(
                    child: ShimmerLoader(
                  width: 40,
                  height: 40,
                  isCircular: true,
                  baseColor: Colors.white,
                )),
                error: (e, s) =>
                    const Text('Error', style: TextStyle(color: Colors.white)),
              ),
            ),
            Expanded(
              child: userDataAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();

                  List<Widget> menuItems = [];
                  if (user.role == 'admin') {
                    // Admin gets admin dashboard + all other items
                    menuItems = [
                      _getAdminMenuItems(context),
                      const Divider(color: Colors.white24, thickness: 1, height: 24),
                    ];
                    
                    // Add all other items, remove duplicates by title
                    final allItems = [
                      ..._getDoctorMenuItems(context),
                      ..._getDistributorMenuItems(context),
                    ];
                    final uniqueItems = <String, Widget>{};
                    for (var item in allItems) {
                      if (item is ListTile) {
                        final title = (item.title as Text).data;
                        if (title != null) {
                          uniqueItems.putIfAbsent(title, () => item);
                        }
                      }
                    }
                    menuItems.addAll(uniqueItems.values);
                  } else if (user.role == 'doctor') {
                    menuItems = _getDoctorMenuItems(context);
                  } else if (user.role == 'distributor' || user.role == 'company') {
                    menuItems = _getDistributorMenuItems(context);
                  } else {
                    menuItems = _getViewerMenuItems(context);
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    children: [
                      ...menuItems,
                      const Divider(color: Colors.white24, thickness: 1, height: 24),
                      _buildMenuItem(
                        icon: FontAwesomeIcons.whatsapp,
                        title: (context.locale.languageCode == 'en') ? 'Contact Support' : 'تواصل مع الدعم',
                        onTap: () async {
                          final Uri whatsappUrl = Uri.parse("https://wa.me/201017016217?text=مرحبا، أحتاج مساعدة في تطبيق فيلداوي");
                          if (await canLaunchUrl(whatsappUrl)) {
                            await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const Text('Error loading menu',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            _buildMenuItem(
              icon: Icons.logout,
              title: 'home.menu.sign_out'.tr(),
              onTap: () {
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.question,
                  animType: AnimType.scale,
                  title: 'home.menu.logout_confirm_title'.tr(),
                  desc: 'home.menu.logout_confirm_msg'.tr(),
                  btnCancelOnPress: () {},
                  btnOkOnPress: () {
                    ref.read(authServiceProvider).signOut();
                  },
                ).show();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _getDistributorMenuItems(BuildContext context) {
    return [
    
      _buildMenuItem(
          icon: Icons.map_outlined, // New map icon
          title: 'home.menu.clinics_map'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ClinicsMapScreen()));
          }),
      _buildMenuItem(
          icon: Icons.rate_review,
          title: 'home.menu.product_rating'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ProductsWithReviewsScreen()));
          }),
      _buildMenuItem(
          icon: Icons.dashboard_outlined,
          title: 'home.menu.dashboard'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const DashboardPage()));
          }),
     
      _buildMenuItem(
          icon: Icons.inventory_2_outlined, // أيقونة جديدة
          title: 'home.menu.my_medicines'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const MyProductsScreen()));
          }),
      _buildMenuItem(
          icon: Icons.production_quantity_limits_outlined,
          title: 'home.menu.add_products'.tr(),
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AddProductScreen()));
          },
        ),
      _buildMenuItem(
          icon: Icons.inventory_2_outlined,
          title: 'home.menu.vet_supplies'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const VetSuppliesScreen()));
          }),
      _buildMenuItem(
          icon: Icons.work_outline,
          title: 'home.menu.job_offers'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const JobOffersScreen()));
          }),
      _buildMenuItem(
          icon: Icons.person_outline,
          title: 'home.menu.profile'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ProfileScreen()));
          }),
      _buildMenuItem(
          icon: Icons.settings_outlined,
          title: 'home.menu.settings'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SettingsScreen()));
          }),
    ];
  }

  List<Widget> _getDoctorMenuItems(BuildContext context) {
    return [
      
      _buildMenuItem(
          icon: Icons.map_outlined, // New map icon
          title: 'home.menu.clinics_map'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ClinicsMapScreen()));
          }),
      _buildMenuItem(
          icon: Icons.rate_review,
          title: 'home.menu.product_rating'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ProductsWithReviewsScreen()));
          }),
      _buildMenuItem(
          icon: Icons.analytics_outlined,
          title: 'home.menu.analytics'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const AnalyticsPage()));
          }),
      _buildMenuItem(
          icon: Icons.people_alt_outlined,
          title: 'home.menu.distributors'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const DistributorsScreen()));
          }),
      _buildMenuItem(
          icon: Icons.shopping_cart_outlined,
          title: 'home.menu.orders'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const OrdersScreen()));
          }),
      _buildMenuItem(
          icon: Icons.add_business_outlined,
          title: 'home.menu.add_products'.tr(),
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AddProductScreen()));
          },
        ),
      _buildMenuItem(
          icon: Icons.inventory_2_outlined,
          title: 'home.menu.vet_supplies'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const VetSuppliesScreen()));
          }),
      _buildMenuItem(
          icon: Icons.work_outline,
          title: 'home.menu.job_offers'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const JobOffersScreen()));
          }),
      _buildMenuItem(
          icon: Icons.person_outline,
          title: 'home.menu.profile'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ProfileScreen()));
          }),
      _buildMenuItem(
          icon: Icons.settings_outlined,
          title: 'home.menu.settings'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SettingsScreen()));
          }),
    ];
  }

  List<Widget> _getViewerMenuItems(BuildContext context) {
    return [
      _buildMenuItem(
          icon: Icons.map_outlined, // New map icon
          title: 'home.menu.clinics_map'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ClinicsMapScreen()));
          }),
      _buildMenuItem(
          icon: Icons.rate_review,
          title: 'home.menu.product_rating'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ProductsWithReviewsScreen()));
          }),
      _buildMenuItem(
          icon: Icons.work_outline,
          title: 'home.menu.job_offers'.tr(),
          onTap: () {
            ZoomDrawer.of(context)!.close();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const JobOffersScreen()));
          }),
      _buildMenuItem(
          icon: Icons.person_outline, title: 'home.menu.profile'.tr(), onTap: () {}),
    ];
  }

  Widget _buildMenuHeader(
      BuildContext context, WidgetRef ref, UserModel? user) {
    if (user == null) return const SizedBox.shrink();

    final currentThemeMode = ref.watch(themeNotifierProvider);

    void changeTheme(ThemeMode mode) {
      ref.read(themeNotifierProvider.notifier).setThemeMode(mode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                if (currentThemeMode == ThemeMode.light) {
                  changeTheme(ThemeMode.dark);
                } else {
                  changeTheme(ThemeMode.light);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 60,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: currentThemeMode == ThemeMode.dark
                      ? const Color.fromARGB(255, 125, 125, 125).withOpacity(0.2)
                      : const Color.fromARGB(255, 125, 125, 125).withOpacity(0.2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      left: currentThemeMode == ThemeMode.light ? 2.0 : 30.0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Icon(
                          Icons.light_mode,
                          size: 16,
                          color: currentThemeMode == ThemeMode.light
                              ? Theme.of(context).colorScheme.primary
                              : const Color.fromARGB(255, 251, 171, 106),
                        ),
                        Icon(
                          Icons.dark_mode,
                          size: 16,
                          color: currentThemeMode == ThemeMode.dark
                              ? Theme.of(context).colorScheme.primary
                              : const Color.fromARGB(255, 250, 251, 251),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }



// ... existing code ...

  Widget _getAdminMenuItems(BuildContext context) {
    return _buildMenuItem(
      icon: Icons.admin_panel_settings,
      title: 'home.menu.admin_dashboard'.tr(),
      onTap: () {
        ZoomDrawer.of(context)!.close();
        // استخدام النسخة Web المناسبة للإدارة
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const AdminScaffold()));
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      splashColor: Colors.white24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
