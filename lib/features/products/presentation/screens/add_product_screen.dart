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
    final isRestricted = userRole == 'doctor';

    void showRestrictionMessage() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
          content: Text(
            'products.distributor_only_feature'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    }

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
            title: 'products.add_options.expire_soon'.tr(),
            subtitle: 'products.add_options.expire_desc'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ExpireDrugsScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.local_offer_rounded,
            title: 'products.add_options.limited_offer'.tr(),
            subtitle: 'products.add_options.offer_desc'.tr(),
            isLocked: isRestricted,
            onTap: () {
              if (isRestricted) {
                showRestrictionMessage();
              } else {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const LimitedOfferScreen()));
              }
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.medical_services_rounded,
            title: 'products.add_options.surgical'.tr(),
            subtitle: 'products.add_options.surgical_desc'.tr(),
            isLocked: false,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SurgicalToolsScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.menu_book_rounded,
            title: 'products.add_options.books'.tr(),
            subtitle: 'products.add_options.books_desc'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const BooksScreen(),
              ));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.school_rounded,
            title: 'products.add_options.courses'.tr(),
            subtitle: 'products.add_options.courses_desc'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const CoursesScreen(),
              ));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.local_fire_department_rounded,
            title: 'products.add_options.ads'.tr(),
            subtitle: 'products.add_options.ads_desc'.tr(),
            badge: 'products.add_options.soon'.tr(),
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
    this.isLocked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // تحديد ألوان ديناميكية للحالة المقفلة
    final lockedBgColor = isDark 
        ? theme.colorScheme.surfaceVariant.withOpacity(0.3) 
        : Colors.grey.shade100;
    final lockedIconColor = isDark ? Colors.white24 : Colors.grey;
    final lockedTextColor = isDark ? Colors.white38 : Colors.grey.shade600;

    return Opacity(
      opacity: isLocked ? 0.6 : 1.0,
      child: Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        color: isLocked ? lockedBgColor : null,
        child: Stack(
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              leading: Icon(
                icon, 
                size: 40, 
                color: isLocked ? lockedIconColor : theme.colorScheme.primary
              ),
              title: Text(
                title, 
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isLocked ? lockedTextColor : null,
                )
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  color: isLocked ? lockedTextColor.withOpacity(0.7) : null,
                ),
              ),
              trailing: Icon(
                isLocked ? Icons.lock_outline : Icons.arrow_forward_ios_rounded,
                color: isLocked ? lockedIconColor : null,
              ),
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
      ),
    );
  }
}
