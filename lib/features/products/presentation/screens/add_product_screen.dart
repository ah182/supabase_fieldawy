import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/books/presentation/screens/books_screen.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/courses_screen.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/presentation/screens/expire_drugs_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/limited_offer_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/surgical_tools_screen.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddProductScreen extends ConsumerWidget {
  const AddProductScreen({super.key});

  static const routeName = '/add-product'; // Optional: for named routes

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userDataProvider).asData?.value?.role ?? '';
    final selectedIndex = (userRole == 'distributor' || userRole == 'company') ? 1 : 1;

    return MainScaffold(
      selectedIndex: selectedIndex,
      appBar: AppBar(
        title: Text('addProduct.title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _OptionCard(
            icon: Icons.warning_amber_rounded,
            title: 'addProduct.expireSoon.title'.tr(),
            subtitle: 'addProduct.expireSoon.subtitle'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ExpireDrugsScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.local_offer_rounded,
            title: 'addProduct.limitedOffer.title'.tr(),
            subtitle: 'addProduct.limitedOffer.subtitle'.tr(),
           onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LimitedOfferScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.medical_services_rounded,
            title: 'addProduct.surgical.title'.tr(),
            subtitle: 'addProduct.surgical.subtitle'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SurgicalToolsScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.menu_book_rounded,
            title: 'addProduct.vetBooks.title'.tr(),
            subtitle: 'addProduct.vetBooks.subtitle'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const BooksScreen(),
              ));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.school_rounded,
            title: 'addProduct.vetCourses.title'.tr(),
            subtitle: 'addProduct.vetCourses.subtitle'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const CoursesScreen(),
              ));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.local_fire_department_rounded,
            title: 'addProduct.limitedAds.title'.tr(),
            subtitle: 'addProduct.limitedAds.subtitle'.tr(),
            badge: 'يتوفر قريباً',
            onTap: () {
              // TODO: Navigate to the correct screen
            },
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Stack(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.arrow_forward_ios_rounded),
            onTap: onTap,
          ),
          if (badge != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
