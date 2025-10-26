import 'dart:async';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/leaderboard/application/leaderboard_provider.dart';
import 'package:fieldawy_store/features/leaderboard/data/leaderboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FortuneWheelScreen extends ConsumerStatefulWidget {
  final int rank;
  const FortuneWheelScreen({super.key, required this.rank});

  @override
  ConsumerState<FortuneWheelScreen> createState() => _FortuneWheelScreenState();
}

class _FortuneWheelScreenState extends ConsumerState<FortuneWheelScreen>
    with SingleTickerProviderStateMixin {
  final selected = StreamController<int>.broadcast();
  String _selectedPrize = '';
  final _isSpinning = ValueNotifier<bool>(false);
  final _hasSpun =
      ValueNotifier<bool>(false); // إضافة متغير جديد لتتبع هل تم الدوران
  late AnimationController _glowController;

  late List<String> items;

  @override
  void initState() {
    super.initState();
    items = _getItemsForRank(widget.rank);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  List<String> _getItemsForRank(int rank) {
    if (rank == 1) {
      return [
        '1000 EGP',
        'Book 1',
        'Course 1',
        'Golden Box',
        'Book 2',
        'Course 2',
        'Book 3',
      ];
    } else if (rank == 2) {
      return [
        '500 EGP',
        'Book 1',
        'Course 1',
        'Silver Box',
        'Book 2',
        'Course 2',
      ];
    } else if (rank == 3) {
      return ['250 EGP', 'Book 1', 'Course 1', 'Bronze Box'];
    } else if (rank == 4 || rank == 5) {
      return ['100 EGP', '1 Book', '1 Course'];
    } else {
      return ['No prizes for this rank'];
    }
  }

  @override
  void dispose() {
    selected.close();
    _glowController.dispose();
    _isSpinning.dispose();
    _hasSpun.dispose(); // dispose للمتغير الجديد
    super.dispose();
  }

  void _handleSpin() {
    if (_isSpinning.value || _hasSpun.value) return; // إضافة شرط _hasSpun

    final randomIndex = Fortune.randomInt(0, items.length);
    _selectedPrize = items[randomIndex];
    _isSpinning.value = true;
    _hasSpun.value = true; // تعيين أنه تم الدوران
    selected.add(randomIndex);
  }

  Future<void> _onSpinEnd() async {
    _isSpinning.value = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Congratulations! You won $_selectedPrize',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final userId = ref.read(authStateChangesProvider).asData?.value?.id;
    if (userId == null) return;

    try {
      await ref
          .read(leaderboardRepositoryProvider)
          .claimPrize(userId, _selectedPrize);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save prize: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankColor = _getRankColor(widget.rank);
    final claimedPrizeAsync = ref.watch(claimedPrizeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Spin for your Prize!',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: claimedPrizeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (claimedPrize) {
          if (claimedPrize != null) {
            return _buildAlreadyClaimedUI(context, claimedPrize);
          }
          return _buildFortuneWheelUI(context, theme, rankColor);
        },
      ),
    );
  }

  Widget _buildFortuneWheelUI(
      BuildContext context, ThemeData theme, Color rankColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rankColor.withOpacity(0.8),
                  rankColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: rankColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Rank: #${widget.rank}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<bool>(
            valueListenable: _hasSpun, // استخدام _hasSpun بدل _isSpinning
            builder: (context, hasSpun, child) {
              if (!hasSpun && _selectedPrize.isEmpty) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Tap the wheel to spin',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green[400]!,
                      Colors.green[600]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🎉 Congratulations! 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You won: $_selectedPrize',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ValueListenableBuilder<bool>(
                valueListenable: _isSpinning,
                builder: (context, isSpinning, child) {
                  return AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isSpinning
                                  ? rankColor.withOpacity(
                                      (_glowController.value * 0.3),
                                    )
                                  : Colors.transparent,
                              blurRadius: 15 + (_glowController.value * 10),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: ValueListenableBuilder<bool>(
                      // إضافة ValueListenableBuilder لـ _hasSpun
                      valueListenable: _hasSpun,
                      builder: (context, hasSpun, child) {
                        return GestureDetector(
                          onTap: (isSpinning || hasSpun)
                              ? null
                              : _handleSpin, // تعطيل عند الدوران أو بعد الدوران
                          child: AbsorbPointer(
                            absorbing: isSpinning ||
                                hasSpun, // منع التفاعل بعد الدوران
                            child: Opacity(
                              opacity: hasSpun
                                  ? 0.6
                                  : 1.0, // تقليل الشفافية بعد الدوران
                              child: FortuneWheel(
                                selected: selected.stream,
                                animateFirst: false,
                                duration: const Duration(seconds: 3),
                                onAnimationEnd: _onSpinEnd,
                                indicators: [
                                  FortuneIndicator(
                                    alignment: Alignment.topCenter,
                                    child: Transform.translate(
                                      offset: const Offset(0, 25.0),
                                      child: Container(
                                        width: 0,
                                        height: 0,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: const BorderSide(
                                              color: Colors.transparent,
                                              width: 20,
                                            ),
                                            right: const BorderSide(
                                              color: Colors.transparent,
                                              width: 20,
                                            ),
                                            bottom: BorderSide(
                                              color: rankColor,
                                              width: 30,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                items: [
                                  for (var i = 0; i < items.length; i++)
                                    FortuneItem(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          items[i],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black54,
                                                offset: Offset(1, 1),
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      style: FortuneItemStyle(
                                        color:
                                            _getWheelColors(widget.rank)[i % 2],
                                        borderColor: Colors.white,
                                        borderWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: ValueListenableBuilder<bool>(
              valueListenable: _hasSpun, // استخدام _hasSpun
              builder: (context, hasSpun, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isSpinning,
                  builder: (context, isSpinning, child) {
                    final isDisabled = isSpinning ||
                        hasSpun; // تعطيل الزر إذا كان يدور أو تم الدوران
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDisabled
                              ? [Colors.grey[400]!, Colors.grey[600]!]
                              : [rankColor.withOpacity(0.8), rankColor],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDisabled
                                ? Colors.grey.withOpacity(0.3)
                                : rankColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isDisabled ? null : _handleSpin, // تعطيل الزر
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isSpinning)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                else
                                  Icon(
                                    hasSpun
                                        ? Icons.check_circle
                                        : Icons
                                            .casino, // تغيير الأيقونة بعد الدوران
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                const SizedBox(width: 12),
                                Text(
                                  isSpinning
                                      ? 'SPINNING...'
                                      : hasSpun
                                          ? 'ALREADY SPUN'
                                          : 'SPIN THE WHEEL',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAlreadyClaimedUI(BuildContext context, String prize) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.redeem, size: 100, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'You have already claimed your prize!',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You won:',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Chip(
            backgroundColor: theme.colorScheme.primaryContainer,
            label: Text(
              prize,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber[600]!;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return const Color(0xFFCD7F32);
      case 4:
      case 5:
        return Colors.blue[600]!;
      default:
        return Colors.grey;
    }
  }

  List<Color> _getWheelColors(int rank) {
    switch (rank) {
      case 1:
        return [
          Colors.amber[700]!,
          Colors.amber[300]!,
        ];
      case 2:
        return [
          Colors.grey[600]!,
          Colors.grey[300]!,
        ];
      case 3:
        return [
          const Color(0xFF8B4513),
          const Color(0xFFD2691E),
        ];
      case 4:
      case 5:
        return [
          const Color.fromARGB(255, 42, 141, 216),
          const Color.fromARGB(255, 6, 95, 196),
        ];
      default:
        return [Colors.grey[700]!, Colors.grey[300]!];
    }
  }
}
