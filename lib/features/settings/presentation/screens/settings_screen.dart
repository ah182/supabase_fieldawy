import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/leaderboard/presentation/screens/leaderboard_screen.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/theme/app_theme.dart';

// ignore: unused_import
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/clinics/presentation/widgets/location_permission_dialog.dart';


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
    final selectedIndex = isDoctor ? 4 : 4; // Settings is at index 4 for both

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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
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

                  // --- Enter Referral Code Section (if applicable) ---
                  const _ReferralEntrySection(),

                  // --- Referral Code Section ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Referral Code',
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
                      leading: Icon(Icons.card_giftcard,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(userData.asData?.value?.referralCode ?? 'Loading...'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          final referralCode = userData.asData?.value?.referralCode;
                          if (referralCode != null) {
                            Clipboard.setData(ClipboardData(text: referralCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Referral code copied!')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Leaderboard Section ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Leaderboard',
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
                      leading: Icon(Icons.leaderboard,
                          color: Theme.of(context).colorScheme.primary),
                      title: const Text('View Leaderboard'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- قسم الموقع (للأطباء فقط) ---
                  if (isDoctor) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'موقع العيادة',
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
                        leading: Icon(Icons.local_hospital,
                            color: Theme.of(context).colorScheme.primary),
                        title: const Text('تحديث موقع العيادة'),
                        subtitle: const Text('تحديث موقع عيادتك الثابت على الخريطة'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final user = userData.asData?.value;
                          if (user != null) {
                            await showLocationPermissionDialog(
                              context,
                              user.id,
                              user.displayName ?? 'الطبيب',
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],


                  const SizedBox(height: 24),


                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferralEntrySection extends ConsumerStatefulWidget {
  const _ReferralEntrySection();

  @override
  ConsumerState<_ReferralEntrySection> createState() => _ReferralEntrySectionState();
}

class _ReferralEntrySectionState extends ConsumerState<_ReferralEntrySection> {
  final _referralCodeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  Future<void> _submitReferralCode() async {
    if (_referralCodeController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      await Supabase.instance.client.functions.invoke('handle-referral', body: {
        'referral_code': _referralCodeController.text.trim(),
        'invited_id': currentUser.id,
      });

      // Invalidate providers to refresh the UI
      ref.invalidate(wasInvitedProvider);
      ref.invalidate(userDataProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral code applied successfully!')),
      );

      _referralCodeController.clear();

    } on FunctionException catch (e) {
      final details = e.details;
      // Check for the specific self-referral error message from the edge function
      if (details is Map && details['error'] == 'You cannot refer yourself') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot use your own referral code.')),
        );
      } else {
        // Handle other function-related errors (e.g., invalid code)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired referral code.')),
        );
      }
    } catch (e) {
      // Handle other unexpected errors (e.g., network issues)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wasInvitedAsync = ref.watch(wasInvitedProvider);
    final textTheme = Theme.of(context).textTheme;

    return wasInvitedAsync.when(
      data: (wasInvited) {
        if (wasInvited) {
          return const SizedBox.shrink(); // User has been invited, show nothing
        }

        // Show the referral entry UI
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Enter Referral Code',
                style: textTheme.titleSmall?.copyWith(color: Colors.grey.shade600),
              ),
            ),
            Card(
              elevation: 1,
              shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _referralCodeController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Enter referral code',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.card_giftcard,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submitReferralCode,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            child: const Text('Apply'),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(), // Don't show anything while loading
      error: (e, s) => const SizedBox.shrink(), // Or show an error message
    );
  }
}
