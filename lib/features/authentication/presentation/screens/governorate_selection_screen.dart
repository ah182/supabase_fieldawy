import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/domain/user_role.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/document_upload_screen.dart';

// Your existing Governorate class (No changes)
class Governorate {
  final int id;
  final String name;
  final List<String> centers;

  Governorate({required this.id, required this.name, required this.centers});

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      id: json['id'],
      name: json['governorate'],
      centers: List<String>.from(json['centers']),
    );
  }
}

class GovernorateSelectionScreen extends HookConsumerWidget {
  final UserRole role;
  final Function(List<String> governorates, List<String> centers)? onContinue;
  final List<String>? initialGovernorates;
  final List<String>? initialCenters;

  const GovernorateSelectionScreen({
    super.key,
    required this.role,
    this.onContinue,
    this.initialGovernorates,
    this.initialCenters,
  });

  Future<List<Governorate>> _loadGovernorates(BuildContext context) async {
    final String response =
        await rootBundle.loadString('assets/governorates.json');
    final List<dynamic> data = json.decode(response);
    return data.map((json) => Governorate.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    // A more professional color palette
    const Color kPrimaryColor = Color(0xFF0D47A1); // Deep Blue

    const Color kBackgroundColor = Color(0xFFF4F6F8); // Light Gray

    const Color kTextColor = Color(0xFF0F172A); // Almost Black

    final governoratesFuture = useMemoized(() => _loadGovernorates(context));
    final snapshot = useFuture(governoratesFuture);

    final selectedGovernorates =
        useState<Set<String>>(Set.from(initialGovernorates ?? []));
    final selectedCenters =
        useState<Set<String>>(Set.from(initialCenters ?? []));

    final showHintArrow = useState<bool>(false);
    final hasShownHintOnce = useState<bool>(false);
    final scrollController = useScrollController();

    final List<Governorate> allGovs = snapshot.data ?? [];
    final List<String> orderedSelectedGovs = allGovs
        .where((g) => selectedGovernorates.value.contains(g.name))
        .map((g) => g.name)
        .toList();

    final Map<String, List<String>> centersByGov = {
      for (final g in allGovs)
        if (selectedGovernorates.value.contains(g.name)) g.name: g.centers
    };

    void _onContinuePressed() {
      if (onContinue != null) {
        onContinue!(selectedGovernorates.value.toList(), selectedCenters.value.toList());
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                DocumentUploadScreen(
              role: role,
              governorates: selectedGovernorates.value.toList(),
              centers: selectedCenters.value.toList(),
            ),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              final tween = Tween(begin: begin, end: end)
                  .chain(CurveTween(curve: Curves.ease));
              return SlideTransition(
                  position: animation.drive(tween), child: child);
            },
          ),
        );
      }
    }

    // Updated chip colors for the new theme
    Color chipBg(bool selected) =>
        selected ? const Color.fromARGB(255, 81, 203, 221) : Colors.transparent;
    Color chipFg(bool selected) => selected ? Colors.white : kTextColor;
    Color chipBorder(bool selected) => selected
        ? const Color.fromARGB(255, 248, 248, 248)
        : Colors.grey.shade300;

    final bool isContinueEnabled = selectedGovernorates.value.isNotEmpty;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0.5,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Column(
                children: [
                  
                  Text(
                    'Coverage Areas'.tr(), // عنوان رئيسي مختصر وجذاب
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'select governorates and centers you coverd'
                        .tr(), // نص الشرح
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: const Color.fromARGB(255, 54, 67, 88), // لون أفتح للنص الثانوي
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(color: kPrimaryColor)))
            else if (snapshot.hasError)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // ===== Governorates Card =====
                    _StyledCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderWithBadge(
                            title: 'Governorates'.tr(),
                            badge: '${selectedGovernorates.value.length}',
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: allGovs.map((governorate) {
                              final isSelected = selectedGovernorates.value
                                  .contains(governorate.name);
                              return _ChipPill(
                                label: governorate.name,
                                selected: isSelected,
                                onTap: () async {
                                  // Same logic, no changes
                                  final newSet = Set<String>.from(
                                      selectedGovernorates.value);
                                  final wasEmptyBefore =
                                      selectedGovernorates.value.isEmpty;

                                  if (!isSelected) {
                                    newSet.add(governorate.name);
                                  } else {
                                    newSet.remove(governorate.name);
                                    final centersToRemove =
                                        Set<String>.from(governorate.centers);
                                    selectedCenters.value = selectedCenters
                                        .value
                                        .difference(centersToRemove);
                                  }
                                  selectedGovernorates.value = newSet;

                                  if (wasEmptyBefore &&
                                      selectedGovernorates.value.isNotEmpty &&
                                      !hasShownHintOnce.value) {
                                    hasShownHintOnce.value = true;
                                    showHintArrow.value = true;

                                    await Future.delayed(
                                        const Duration(milliseconds: 80));
                                    if (scrollController.hasClients) {
                                      final current = scrollController.offset;
                                      final target = (current + 250).clamp(
                                          0.0,
                                          scrollController
                                              .position.maxScrollExtent);
                                      scrollController.animateTo(
                                        target,
                                        duration:
                                            const Duration(milliseconds: 400),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                    await Future.delayed(
                                        const Duration(seconds: 3));
                                    showHintArrow.value = false;
                                  }
                                },
                                bg: chipBg(isSelected),
                                fg: chipFg(isSelected),
                                border: chipBorder(isSelected),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // ===== Centers Card (appears when a governorate is selected) =====
                    if (orderedSelectedGovs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _StyledCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderWithBadge(
                              title: 'Centers'.tr(),
                              badge: '${selectedCenters.value.length}',
                            ),
                            const SizedBox(height: 12),
                            for (int i = 0;
                                i < orderedSelectedGovs.length;
                                i++) ...[
                              if (i > 0)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Divider(height: 1),
                                )
                              else
                                const SizedBox(height: 4),
                              Text(
                                orderedSelectedGovs[i],
                                style: textTheme.titleMedium?.copyWith(
                                  color: kTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    (centersByGov[orderedSelectedGovs[i]] ?? [])
                                        .map((center) {
                                  final isSelected =
                                      selectedCenters.value.contains(center);
                                  return _ChipPill(
                                    label: center,
                                    selected: isSelected,
                                    onTap: () {
                                      // Same logic, no changes
                                      final newSet = Set<String>.from(
                                          selectedCenters.value);
                                      if (!isSelected) {
                                        newSet.add(center);
                                      } else {
                                        newSet.remove(center);
                                      }
                                      selectedCenters.value = newSet;
                                    },
                                    bg: chipBg(isSelected),
                                    fg: chipFg(isSelected),
                                    border: chipBorder(isSelected),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(
                        height: 100), // Space for the floating button
                  ],
                ),
              ),
          ],
        ),
      ),
      // Floating Action Button for continuation
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ElevatedButton(
          onPressed: isContinueEnabled ? _onContinuePressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 41, 152, 186),
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.grey.shade500,
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            shadowColor: kPrimaryColor.withOpacity(0.4),
          ),
          child: Text(
            'continue'.tr(),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isContinueEnabled ? Colors.white : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}

/* ======================= Helper Widgets (UI Only) - Redesigned ======================= */

class _StyledCard extends StatelessWidget {
  final Widget child;
  const _StyledCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 246, 246, 254),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeaderWithBadge extends StatelessWidget {
  final String title;
  final String badge;

  const _HeaderWithBadge({required this.title, required this.badge});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          title,
          style: t.titleLarge?.copyWith(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        if (badge != '0')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 170, 255).withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: t.bodyMedium?.copyWith(
                color: const Color.fromARGB(255, 9, 43, 180),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? bg;
  final Color? fg;
  final Color? border;

  const _ChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.bg,
    this.fg,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: border ?? const Color.fromARGB(2, 64, 42, 92)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

// Your other helper widgets (_BounceArrow, MediaPoint extension) remain the same
// if you choose to use them, although they are not used in this redesigned version.
class _BounceArrow extends StatefulWidget {
  @override
  State<_BounceArrow> createState() => _BounceArrowState();
}

class _BounceArrowState extends State<_BounceArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _a.value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.15),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF0F172A), size: 22),
                SizedBox(width: 6),
                Text(
                  'المراكز موجودة تحت',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension MediaPoint on BuildContext {
  static EdgeInsets _paddingOf(BuildContext context) =>
      MediaQuery.of(context).padding;
  double get bottomPadding => _paddingOf(this).bottom;
}
