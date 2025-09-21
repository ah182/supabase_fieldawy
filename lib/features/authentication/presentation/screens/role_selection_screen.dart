import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/domain/user_role.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/document_upload_screen.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? selectedRole;
  final GlobalKey _buttonKey = GlobalKey();

  Future<void> _openMenu() async {
    const double gap = 12.0;

    final RenderBox button =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonGlobal = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    final double left = buttonGlobal.dx;
    final double top = buttonGlobal.dy + buttonSize.height + gap;
    final double right = overlay.size.width - (left + buttonSize.width);

    final RelativeRect position = RelativeRect.fromLTRB(left, top, right, 0);

    final roles = [
      {
        "label": "Veterinarian",
        "role": UserRole.doctor,
        "icon": Icons.local_hospital
      },
      {
        "label": "Distribution company",
        "role": UserRole.company,
        "icon": Icons.business
      },
      {
        "label": "Individual distributor",
        "role": UserRole.distributor,
        "icon": Icons.storefront
      },
    ];

    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      color: Colors.white,
      items: roles.map((roleData) {
        final label = roleData["label"] as String;
        final icon = roleData["icon"] as IconData;
        final isSelected = selectedRole == label;

        return PopupMenuItem<String>(
          value: label,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            width: buttonSize.width - 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.black87),
                    ),
                  ],
                ),
                if (isSelected)
                  const Icon(Icons.check, color: Colors.green, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        selectedRole = selected;
      });

      final rolesMap = {
        "Veterinarian": UserRole.doctor,
        "Distribution company": UserRole.company,
        "Individual distributor": UserRole.distributor,
      };

      final role = rolesMap[selected];
      if (role != null) {
        if (!mounted) return;
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => DocumentUploadScreen(role: role),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.ease;

              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          tooltip: 'العودة لتسجيل الدخول',
          onPressed: () {
            ref.read(authServiceProvider).signOut();
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 79, 189, 189),
              Color.fromARGB(255, 91, 181, 213)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'choose_your_role'.tr(),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can not change your role later.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // زر اختيار الدور
                GestureDetector(
                  key: _buttonKey,
                  onTap: _openMenu,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 251, 251, 251)
                          .withOpacity(0.95),
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
                            const Icon(Icons.person,
                                size: 20, color: Color.fromARGB(136, 5, 5, 7)),
                            const SizedBox(width: 9),
                            Text(
                              selectedRole ?? "Select Role",
                              style: textTheme.bodyLarge
                                  ?.copyWith(color: Colors.black87),
                            ),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.black54),
                      ],
                    ),
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
