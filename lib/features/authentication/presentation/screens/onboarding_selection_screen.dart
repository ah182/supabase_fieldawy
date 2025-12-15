import 'package:fieldawy_store/features/authentication/presentation/screens/governorate_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/domain/user_role.dart';


import 'package:fieldawy_store/features/authentication/services/auth_service.dart';

class OnboardingSelectionScreen extends HookConsumerWidget {
  const OnboardingSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    final selectedLanguage = useState<Locale?>(null);
    final selectedLanguageLabel = useState<String?>(null);
    final selectedRole = useState<UserRole?>(null);
    final selectedRoleLabel = useState<String?>(null);

    final languageButtonKey = useMemoized(() => GlobalKey());
    final roleButtonKey = useMemoized(() => GlobalKey());

    final isContinueEnabled =
        selectedLanguage.value != null && selectedRole.value != null;

    void onContinue() {
      if (!isContinueEnabled) return;

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              GovernorateSelectionScreen(role: selectedRole.value!),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final isRtl = context.locale.languageCode == 'ar';
            final begin = Offset(isRtl ? -1.0 : 1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: Curves.ease));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          tooltip: 'العودة لتسجيل الدخول',
          onPressed: () => ref.read(authServiceProvider).signOut(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 102, 199, 255),
              Color.fromARGB(255, 91, 181, 213)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'auth.complete_profile'.tr(),
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'auth.select_language_role_desc'.tr(),
                    style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildSelectorButton(
                    context,
                    key: languageButtonKey,
                    label: selectedLanguageLabel.value ?? "auth.select_language".tr(),
                    icon: Icons.language,
                    onTap: () => _openLanguageMenu(
                        context, languageButtonKey, selectedLanguage, selectedLanguageLabel),
                  ),
                  const SizedBox(height: 16),
                  _buildSelectorButton(
                    context,
                    key: roleButtonKey,
                    label: selectedRoleLabel.value ?? "auth.select_role".tr(),
                    icon: Icons.person,
                    onTap: () => _openRoleMenu(
                        context, roleButtonKey, selectedRole, selectedRoleLabel),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: isContinueEnabled ? onContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 117, 199, 221).withOpacity(1),
                      
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                      disabledBackgroundColor: Colors.white.withOpacity(0.5),
                    ),
                    child: Text(
                      'auth.continue'.tr(),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 248, 249, 249),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorButton(BuildContext context, {
    required GlobalKey key,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 251, 251, 251).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color.fromARGB(136, 5, 5, 7)),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.black87),
                ),
              ],
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Future<void> _openLanguageMenu(
    BuildContext context,
    GlobalKey buttonKey,
    ValueNotifier<Locale?> selectedLanguage,
    ValueNotifier<String?> selectedLanguageLabel,
  ) async {
    final languages = [
      {"label": "auth.english".tr(), "flag": "🇬🇧", "locale": const Locale('en')},
      {"label": "auth.arabic".tr(), "flag": "🇪🇬", "locale": const Locale('ar')},
    ];

    final selected = await _showCustomMenu<String>(
      context: context,
      buttonKey: buttonKey,
      items: languages.map((lang) {
        return {
          "value": lang["label"] as String,
          "label": lang["label"] as String,
          "iconWidget": Text(lang["flag"] as String, style: const TextStyle(fontSize: 20)),
        };
      }).toList(),
      selectedValue: selectedLanguageLabel.value,
    );

    if (selected != null) {
      final selectedLangData = languages.firstWhere((l) => l['label'] == selected);
      selectedLanguage.value = selectedLangData['locale'] as Locale?;
      selectedLanguageLabel.value = selectedLangData['label'] as String?;
      
      // Immediately apply the locale change
      if (context.mounted && selectedLanguage.value != null) {
        await context.setLocale(selectedLanguage.value!);
      }
    }
  }

  Future<void> _openRoleMenu(
    BuildContext context,
    GlobalKey buttonKey,
    ValueNotifier<UserRole?> selectedRole,
    ValueNotifier<String?> selectedRoleLabel,
  ) async {
    final roles = [
      {"label": "auth.role_veterinarian".tr(), "role": UserRole.doctor, "icon": Icons.local_hospital},
      {"label": "auth.role_company".tr(), "role": UserRole.company, "icon": Icons.business},
      {"label": "auth.role_distributor".tr(), "role": UserRole.distributor, "icon": Icons.storefront},
    ];

    final selected = await _showCustomMenu<String>(
      context: context,
      buttonKey: buttonKey,
      items: roles.map((roleData) {
        return {
          "value": roleData["label"] as String,
          "label": roleData["label"] as String,
          "iconWidget": Icon(roleData["icon"] as IconData, size: 20, color: Colors.blueAccent),
        };
      }).toList(),
      selectedValue: selectedRoleLabel.value,
    );

    if (selected != null) {
      final selectedRoleData = roles.firstWhere((r) => r['label'] == selected);
      selectedRole.value = selectedRoleData['role'] as UserRole?;
      selectedRoleLabel.value = selectedRoleData['label'] as String?;
    }
  }

  Future<T?> _showCustomMenu<T>({
    required BuildContext context,
    required GlobalKey buttonKey,
    required List<Map<String, dynamic>> items,
    T? selectedValue,
  }) async {
    const double gap = 12.0;
    final RenderBox button = buttonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonGlobal = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    final double left = buttonGlobal.dx;
    final double top = buttonGlobal.dy + buttonSize.height + gap;
    final double right = overlay.size.width - (left + buttonSize.width);

    final RelativeRect position = RelativeRect.fromLTRB(left, top, right, 0);

    return showMenu<T>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      color: Colors.white,
      items: items.map((item) {
        final value = item["value"] as T;
        final label = item["label"] as String;
        final iconWidget = item["iconWidget"] as Widget;
        final isSelected = selectedValue == value;

        return PopupMenuItem<T>(
          value: value,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            width: buttonSize.width - 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.black87),
                  ),
                ]),
                if (isSelected) const Icon(Icons.check, color: Colors.green, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
