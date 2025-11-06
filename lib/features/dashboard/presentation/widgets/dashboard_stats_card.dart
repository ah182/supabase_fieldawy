import 'package:flutter/material.dart';

class DashboardStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  // final double? growth; // ❌ تم الحذف

  const DashboardStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    // this.growth, // ❌ تم الحذف
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- الأيقونة فقط ---
            _buildIcon(), // ✅ أصبح يستدعي الأيقونة مباشرة
            const SizedBox(height: 20),

            // --- القيمة (الرقم الكبير) ---
            Text(
              value,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 36,
              ),
            ),
            const SizedBox(height: 8),

            // --- العنوان ---
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),

            // --- العنوان الفرعي (إن وجد) ---
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              _buildSubtitleBadge(subtitle!, theme),
            ],
          ],
        ),
      ),
    );
  }

  // --- 1. دالة مساعدة لرسم الأيقونة ---
  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  // --- 2. دالة شارة النمو ---
  // ❌ تم حذف دالة _buildGrowthBadge بالكامل

  // --- 3. دالة مساعدة لرسم العنوان الفرعي ---
  Widget _buildSubtitleBadge(String subtitle, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
