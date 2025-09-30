import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/theme/app_theme.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'package:fieldawy_store/widgets/main_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeNotifierProvider);
    final textTheme = Theme.of(context).textTheme;

    final userData = ref.watch(userDataProvider);
    final userRole = userData.asData?.value?.role ?? '';
    final isDoctor = userRole == 'doctor';
    final selectedIndex = isDoctor ? 4 : 3;

    // دالة مساعدة لتغيير الثيم لتجنب تكرار الكود
    void changeTheme(ThemeMode mode) {
      // تجنب إعادة تعيين نفس الثيم
      if (currentThemeMode != mode) {
        ref.read(themeNotifierProvider.notifier).setThemeMode(mode);
      }
    }

    return MainScaffold(
      selectedIndex: selectedIndex,
      appBar: AppBar(
        title: Text('settings'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- قسم اللغة ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'language'.tr(),
                    style: textTheme.titleSmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
                Card(
                  elevation: 1,
                  shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 60),
                    onSelected: (String localeCode) async {
                      await context.setLocale(Locale(localeCode));
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'ar',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('العربية'),
                            if (context.locale.languageCode == 'ar')
                              Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'en',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('English'),
                            if (context.locale.languageCode == 'en')
                              Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    ],
                    child: ListTile(
                      leading: Icon(Icons.language,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(context.locale.languageCode == 'ar'
                          ? 'العربية'
                          : 'English'),
                      trailing:
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- قسم المظهر (تم تعديله بالكامل) ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Appearance'.tr(),
                    style: textTheme.titleSmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
                Card(
                  elevation: 1,
                  shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      // --- تم استبدال SwitchListTile بـ ListTile و Switch مصغر ---
                      Consumer(
                        builder: (context, ref, child) {
                          final currentThemeMode = ref.watch(themeNotifierProvider);
                          return ListTile(
                            leading: const Icon(Icons.light_mode_outlined),
                            title: Text('LightMode'.tr()),
                            trailing: Transform.scale(
                              scale:
                                  0.8, // يمكنك تغيير هذا الرقم (مثلاً 0.7 أو 0.9)
                              child: Switch(
                                value: currentThemeMode == ThemeMode.light,
                                onChanged: (value) => changeTheme(ThemeMode.light),
                              ),
                            ),
                            onTap: () => changeTheme(ThemeMode.light),
                          );
                        },
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final currentThemeMode = ref.watch(themeNotifierProvider);
                          return ListTile(
                            leading: const Icon(Icons.dark_mode_outlined),
                            title: Text('DarkMode'.tr()),
                            trailing: Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: currentThemeMode == ThemeMode.dark,
                                onChanged: (value) => changeTheme(ThemeMode.dark),
                              ),
                            ),
                            onTap: () => changeTheme(ThemeMode.dark),
                          );
                        },
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final currentThemeMode = ref.watch(themeNotifierProvider);
                          return ListTile(
                            leading: const Icon(Icons.phonelink_setup_outlined),
                            title: Text('SystemDefault'.tr()),
                            trailing: Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: currentThemeMode == ThemeMode.system,
                                onChanged: (value) => changeTheme(ThemeMode.system),
                              ),
                            ),
                            onTap: () => changeTheme(ThemeMode.system),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- قسم الاختبار ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Testing Area',
                    style: textTheme.titleSmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
                Card(
                  elevation: 1,
                  shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.crop),
                    title: const Text('Test Image Cropper'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushNamed(context, '/image_cropper_test');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
