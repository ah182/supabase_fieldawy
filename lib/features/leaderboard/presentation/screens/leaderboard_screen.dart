import 'package:fieldawy_store/features/leaderboard/application/spin_wheel_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/leaderboard/application/leaderboard_provider.dart';
import 'package:fieldawy_store/features/leaderboard/presentation/screens/fortune_wheel_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class LeaderboardScreen extends HookConsumerWidget {
  const LeaderboardScreen({super.key});

  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: theme.textTheme.bodyLarge),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showRewardsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) =>
            _RewardsInfoSheet(scrollController: scrollController),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(currentSeasonProvider);
    final leaderboardData = ref.watch(leaderboardProvider);
    final theme = Theme.of(context);
    final currentUserId = ref.watch(authStateChangesProvider).asData?.value?.id;
    
    // Search functionality
    final searchQuery = useState<String>('');
    final debouncedSearchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final ghostText = useState<String>('');
    final fullSuggestion = useState<String>('');
    
    useEffect(() {
      Timer? debounce;
      void listener() {
        if (debounce?.isActive ?? false) debounce!.cancel();
        debounce = Timer(const Duration(milliseconds: 500), () {
          debouncedSearchQuery.value = searchController.text;
        });
      }
      
      searchController.addListener(listener);
      return () {
        debounce?.cancel();
        searchController.removeListener(listener);
      };
    }, [searchController]);

    // ignore: unused_local_variable
    int? currentUserRank;
    if (leaderboardData is AsyncData<List<UserModel>>) {
      try {
        final currentUserInLeaderboard = leaderboardData.value.firstWhere(
          (user) => user.id == currentUserId,
        );
        currentUserRank = currentUserInLeaderboard.rank;
      } catch (e) {
        currentUserRank = null;
      }
    }



    // Filter users based on search
    final filteredUsers = useMemoized(() {
      if (leaderboardData is! AsyncData<List<UserModel>>) {
        return <UserModel>[];
      }
      final users = leaderboardData.value;
      if (debouncedSearchQuery.value.isEmpty) {
        return users;
      }
      final query = debouncedSearchQuery.value.toLowerCase();
      return users.where((user) {
        return (user.displayName ?? '').toLowerCase().contains(query) ||
               (user.email ?? '').toLowerCase().contains(query);
      }).toList();
    }, [leaderboardData, debouncedSearchQuery.value]);

    // دالة مساعدة لإخفاء الكيبورد
    void hideKeyboard() {
      if (searchFocusNode.hasFocus) {
        searchFocusNode.unfocus();
        // إعادة تعيين النص الشبحي إذا كان مربع البحث فارغاً
        if (searchController.text.isEmpty) {
          ghostText.value = '';
          fullSuggestion.value = '';
        }
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => hideKeyboard(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'Leaderboard',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.onSurface,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Column(
              children: [
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: (value) {
                          searchQuery.value = value;
                          if (value.isNotEmpty && leaderboardData is AsyncData<List<UserModel>>) {
                            // ignore: unnecessary_cast
                            final users = (leaderboardData as AsyncData<List<UserModel>>).value;
                            final filtered = users.where((user) {
                              final displayName = (user.displayName ?? '').toLowerCase();
                              return displayName.startsWith(value.toLowerCase());
                            }).toList();
                            
                            if (filtered.isNotEmpty) {
                              final suggestion = filtered.first;
                              ghostText.value = suggestion.displayName ?? '';
                              fullSuggestion.value = suggestion.displayName ?? '';
                            } else {
                              ghostText.value = '';
                              fullSuggestion.value = '';
                            }
                          } else {
                            ghostText.value = '';
                            fullSuggestion.value = '';
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search players...',
                          hintStyle: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
                            size: 25,
                          ),
                          suffixIcon: searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    searchController.clear();
                                    searchQuery.value = '';
                                    debouncedSearchQuery.value = '';
                                    ghostText.value = '';
                                    fullSuggestion.value = '';
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    if (ghostText.value.isNotEmpty)
                      Positioned(
                        top: 11,
                        right: 71,
                        child: GestureDetector(
                          onTap: () {
                            if (fullSuggestion.value.isNotEmpty) {
                              searchController.text = fullSuggestion.value;
                              searchQuery.value = fullSuggestion.value;
                              debouncedSearchQuery.value = fullSuggestion.value;
                              ghostText.value = '';
                              fullSuggestion.value = '';
                              searchFocusNode.unfocus();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? theme.colorScheme.secondary.withOpacity(0.1)
                                  : theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ghostText.value,
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            leaderboardData.when(
              skipLoadingOnRefresh: true,
              data: (users) {
                final displayUsers = debouncedSearchQuery.value.isEmpty ? users : filteredUsers;
                
                if (displayUsers.isEmpty && debouncedSearchQuery.value.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No players found for "${debouncedSearchQuery.value}"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 80,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users on the leaderboard yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                edgeOffset: 8,
                displacement: 32,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                onRefresh: () async {
                  ref.invalidate(leaderboardProvider);
                  ref.invalidate(currentSeasonProvider);
                  await ref.read(leaderboardProvider.future);
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: seasonAsync.when(
                        data: (season) => season == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: _CountdownTimer(endDate: season.endDate),
                              ),
                        loading: () => const SizedBox(
                          height: 72,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (e, st) => const SizedBox.shrink(),
                      ),
                    ),
                    // Current User Card
                    SliverToBoxAdapter(
                      child: () {
                        final currentUserInList = displayUsers.where((u) => u.id == currentUserId).firstOrNull;
                        if (currentUserInList == null) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _buildCurrentUserCard(context, currentUserInList),
                        );
                      }(),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0 && displayUsers.length >= 3) {
                              return _buildPodium(context, displayUsers.take(3).toList());
                            }

                            final actualIndex =
                                displayUsers.length >= 3 ? index + 2 : index;
                            if (actualIndex >= displayUsers.length) {
                              return const SizedBox.shrink();
                            }

                            final user = displayUsers[actualIndex];
                            final rank = user.rank ?? (actualIndex + 1);

                            if (rank <= 3 && displayUsers.length < 3) {
                              return _buildTopRankerCard(context, user, rank);
                            } else if (rank == 4 || rank == 5) {
                              return _buildSpecialRankerTile(context, user, rank);
                            } else {
                              return _buildRegularRankerTile(context, user, rank);
                            }
                          },
                          childCount: displayUsers.length >= 3
                              ? displayUsers.length - 3 + 1
                              : displayUsers.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(), // Show nothing on load, handled by the Stack
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oops! Something went wrong',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(leaderboardProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (leaderboardData.isLoading && !leaderboardData.hasValue)
            Container(
              color: theme.scaffoldBackgroundColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple[400]!,
                      Colors.purple[600]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 176, 39, 155).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showRewardsBottomSheet(context),
                    borderRadius: BorderRadius.circular(16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_giftcard,
                            color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Rewards',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final availabilityAsync = ref.watch(spinWheelAvailabilityProvider);
                  return availabilityAsync.when(
                    loading: () => const SizedBox(height: 52),
                    error: (err, stack) => const SizedBox.shrink(), // Or show an error
                    data: (details) {
                      final bool isAvailable = details.availability == SpinWheelAvailability.available;
                      return Opacity(
                        opacity: isAvailable ? 1.0 : 0.6,
                        child: Container(
                          height: 52,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isAvailable
                                  ? [Colors.amber[400]!, Colors.orange[600]!]
                                  : [Colors.grey[500]!, Colors.grey[700]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (isAvailable)
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isAvailable
                                  ? () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const FortuneWheelScreen(),
                                        ),
                                      );
                                      ref.invalidate(spinWheelAvailabilityProvider);
                                    }
                                  : () async {
                                      String title = 'غير متاح';
                                      String message = 'عجلة الحظ غير متاحة حالياً.';
                                      switch (details.availability) {
                                        case SpinWheelAvailability.notWinner:
                                          title = 'غير مؤهل';
                                          message = 'عجلة الحظ متاحة فقط للفائزين في الموسم السابق.';
                                          break;
                                        case SpinWheelAvailability.windowClosed:
                                          title = 'انتهت الفرصة';
                                          message = 'لقد انتهت فترة الـ 30 يوماً للمطالبة بجائزة الموسم السابق.';
                                          break;
                                        case SpinWheelAvailability.alreadyClaimed:
                                          title = 'لقد طالبت بجائزتك';
                                          message = 'لقد طالبت بجائزتك لهذا الموسم بالفعل.\n\nالجائزة: ${details.claimedPrize}\nالمركز: ${details.rank}';
                                          break;
                                        default:
                                          break;
                                      }
                                      await _showInfoDialog(
                                        context,
                                        title: title,
                                        message: message,
                                      );
                                    },
                              borderRadius: BorderRadius.circular(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isAvailable
                                        ? Icons.casino
                                        : Icons.lock_outline,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Spin Wheel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
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
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildPodium(BuildContext context, List<UserModel> topThree) {
    final theme = Theme.of(context);

    if (topThree.length < 3) return const SizedBox.shrink();

    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Colors.amber[700],
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top Champions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildPodiumPosition(
                  context,
                  second,
                  2,
                  Colors.grey[400]!,
                  140,
                ),
              ),
              Expanded(
                child: _buildPodiumPosition(
                  context,
                  first,
                  1,
                  Colors.amber[400]!,
                  180,
                ),
              ),
              Expanded(
                child: _buildPodiumPosition(
                  context,
                  third,
                  3,
                  const Color(0xFFCD7F32),
                  120,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition(
    BuildContext context,
    UserModel user,
    int rank,
    Color color,
    double height,
  ) {
    final theme = Theme.of(context);
    final avatarSize = rank == 1 ? 70.0 : 60.0;
    final iconSize = rank == 1 ? 32.0 : 28.0;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: rank == 1 ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? Icon(Icons.person, size: avatarSize / 2)
                    : null,
              ),
            ),
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Icon(
                Icons.emoji_events,
                color: color,
                size: iconSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            user.displayName ?? 'No Name',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: rank == 1 ? FontWeight.bold : FontWeight.w600,
              fontSize: rank == 1 ? 14 : 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${user.points ?? 0}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.4),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: rank == 1 ? 36 : 28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentUserCard(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final rank = user.rank ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 22, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: Colors.amber[300],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Your Rank',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${user.points ?? 0}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'points',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRankerCard(BuildContext context, UserModel user, int rank) {
    final theme = Theme.of(context);
    final colors = [
      Colors.amber[400]!,
      Colors.grey[400]!,
      const Color(0xFFCD7F32),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[rank - 1].withOpacity(0.15),
            colors[rank - 1].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors[rank - 1].withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors[rank - 1].withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors[rank - 1],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors[rank - 1],
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: colors[rank - 1],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${user.points ?? 0} points',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors[rank - 1].withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${user.points ?? 0}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors[rank - 1],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularRankerTile(
      BuildContext context, UserModel user, int rank) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 22)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${user.points ?? 0} points',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${user.points ?? 0}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialRankerTile(
      BuildContext context, UserModel user, int rank) {
    final theme = Theme.of(context);
    final color = Colors.blue[400]!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 22)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'No Name',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${user.points ?? 0} points',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${user.points ?? 0}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime endDate;
  const _CountdownTimer({required this.endDate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remaining = _computeRemaining();
        });
      }
    });
  }

  Duration _computeRemaining() {
    final now = DateTime.now().toUtc();
    final end = widget.endDate.toUtc();
    final diff = end.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 87, 142, 194),
            const Color.fromARGB(255, 36, 119, 170),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 39, 121, 176).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Season ends in',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _timeBox(context, '$days', 'Days'),
              _timeSeparator(),
              _timeBox(context, _two(hours), 'Hours'),
              _timeSeparator(),
              _timeBox(context, _two(minutes), 'Min'),
              _timeSeparator(),
              _timeBox(context, _two(seconds), 'Sec'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RewardsInfoSheet extends StatelessWidget {
  final ScrollController scrollController;
  const _RewardsInfoSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber[400]!, Colors.orange[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leaderboard Rewards',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Win amazing prizes!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: const [
                _RewardTierCard(
                  rank: '1st Place',
                  rankIcon: '🥇',
                  color: Colors.amber,
                  rewards: [
                    'EGP 1000 Cash Prize',
                    'Book 1, Book 2, Book 3',
                    'Course 1, Course 2',
                    'Golden Blind Box (Medicines)',
                  ],
                ),
                _RewardTierCard(
                  rank: '2nd Place',
                  rankIcon: '🥈',
                  color: Colors.grey,
                  rewards: [
                    'EGP 500 Cash Prize',
                    'Book 1, Book 2',
                    'Course 1, Course 2',
                    'Silver Blind Box',
                  ],
                ),
                _RewardTierCard(
                  rank: '3rd Place',
                  rankIcon: '🥉',
                  color: Color(0xFFCD7F32),
                  rewards: [
                    'EGP 250 Cash Prize',
                    'Book 1',
                    'Course 1',
                    'Bronze Blind Box',
                  ],
                ),
                _RewardTierCard(
                  rank: '4th & 5th Place',
                  rankIcon: '🏅',
                  color: Colors.blue,
                  rewards: [
                    'EGP 100 Cash Prize',
                    '1 Book & 1 Course',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTierCard extends StatelessWidget {
  final String rank;
  final String rankIcon;
  final Color color;
  final List<String> rewards;

  const _RewardTierCard({
    required this.rank,
    required this.rankIcon,
    required this.color,
    required this.rewards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    rankIcon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rank,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...rewards.map((reward) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reward,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
