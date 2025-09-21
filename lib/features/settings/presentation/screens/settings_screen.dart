import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/theme/app_theme.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import 'package:fieldawy_store/widgets/main_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    final selectedIndex = 3;

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
                  child: ListTile(
                    leading: Icon(Icons.language,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(context.locale.languageCode == 'ar'
                        ? 'العربية'
                        : 'English'),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                    onTap: () {
                      AwesomeDialog(
                        context: context,
                        dialogType: DialogType.question,
                        animType: AnimType.scale,
                        title: 'languageChangeConfirmationTitle'.tr(),
                        desc: 'languageChangeConfirmationMessage'.tr(namedArgs: {'language': context.locale.languageCode == 'ar' ? 'English' : 'العربية'}),
                        btnCancelOnPress: () {},
                        btnOkOnPress: () async {
                          // Change language directly after confirmation
                          if (context.locale.languageCode == 'ar') {
                            await context.setLocale(const Locale('en'));
                          } else {
                            await context.setLocale(const Locale('ar'));
                          }
                        },
                      ).show();
                    },
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
