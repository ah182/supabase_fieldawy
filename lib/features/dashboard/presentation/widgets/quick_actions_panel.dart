import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/limited_offer_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/surgical_tools_screen.dart';
import 'package:fieldawy_store/features/vet_supplies/presentation/screens/vet_supplies_screen.dart';
import 'package:fieldawy_store/features/settings/presentation/screens/settings_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/my_products_screen.dart';
import 'package:fieldawy_store/features/jobs/presentation/screens/job_offers_screen.dart';
import 'package:fieldawy_store/features/books/presentation/screens/books_screen.dart';
import 'package:fieldawy_store/features/courses/presentation/screens/courses_screen.dart';

// -------------------------------------------------------------------
// 2. كلاس مساعد لتنظيم بيانات الأزرار
// -------------------------------------------------------------------
class _QuickActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// -------------------------------------------------------------------
// 3. الـ Widget الرئيسية بتصميم عصري وجذاب
// -------------------------------------------------------------------
class QuickActionsPanel extends StatelessWidget {
  const QuickActionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // تجميع كل الإجراءات في قائمة واحدة لسهولة إدارتها
    final List<_QuickActionItem> actions = [
      _QuickActionItem(
        icon: Icons.add_circle_outline,
        label: 'dashboard_feature.quick_actions.add_product'.tr(),
        color: Colors.blue,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const AddProductScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.local_offer,
        label: 'dashboard_feature.quick_actions.add_offer'.tr(),
        color: Colors.green,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const LimitedOfferScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.inventory,
        label: 'dashboard_feature.quick_actions.my_products'.tr(),
        color: Colors.indigo,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const MyProductsScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.medical_services,
        label: 'dashboard_feature.quick_actions.surgical_tools'.tr(),
        color: Colors.purple,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const SurgicalToolsScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.pets,
        label: 'dashboard_feature.quick_actions.vet_supplies'.tr(),
        color: Colors.teal,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const VetSuppliesScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.work,
        label: 'dashboard_feature.quick_actions.job_offers'.tr(),
        color: Colors.orange,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const JobOffersScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.menu_book,
        label: 'dashboard_feature.quick_actions.vet_books'.tr(),
        color: Colors.brown,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const BooksScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.school,
        label: 'dashboard_feature.quick_actions.courses'.tr(),
        color: Colors.deepPurple,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const CoursesScreen(),
          ));
        },
      ),
      _QuickActionItem(
        icon: Icons.settings,
        label: 'dashboard_feature.quick_actions.settings'.tr(),
        color: Colors.grey.shade700,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ));
        },
      ),
    ];

    return Card(
      elevation: 2, // ✅ تخفيف الظل لمظهر أنعم
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)), // ✅ زيادة الحواف الدائرية
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- الهيدر (العنوان) ---
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  'dashboard_feature.quick_actions.title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- استخدام GridView لعرض الأزرار بشكل عصري ---
            GridView.count(
              crossAxisCount: 2, // ✅ عرض عنصرين في كل صف
              shrinkWrap: true, // ✅ ضروري داخل Column
              physics:
                  const NeverScrollableScrollPhysics(), // ✅ لمنع السكرول داخل الكارد
              crossAxisSpacing: 12, // ✅ مسافة أفقية
              mainAxisSpacing: 12, // ✅ مسافة رأسية
              childAspectRatio:
                  (3 / 2.5), // ✅ ضبط النسبة بين العرض والارتفاع للزر
              children: actions.map((item) {
                return _buildQuickActionButton(context, item: item);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // --- تصميم الزر الجديد ---
  // أبسط، أنظف، ويعتمد على الأيقونة والنص بشكل عمودي
  Widget _buildQuickActionButton(
    BuildContext context, {
    required _QuickActionItem item,
  }) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.1), // ✅ لون خلفية خفيف جداً
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 32), // ✅ أيقونة بحجم أوضح
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
