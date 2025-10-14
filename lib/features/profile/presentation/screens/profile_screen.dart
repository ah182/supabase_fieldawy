// ignore_for_file: unused_import

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/favorites_screen.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:fieldawy_store/features/settings/presentation/screens/settings_screen.dart';
import 'package:fieldawy_store/features/notifications/notification_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';

import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'doctor':
        return 'Veterinarian';
      case 'company':
        return 'Distribution company';
      case 'distributor':
        return 'Individual distributor';
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'doctor':
        return Icons.local_hospital_rounded;
      case 'company':
        return Icons.business_rounded;
      case 'distributor':
        return Icons.storefront_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final userRole = userDataAsync.asData?.value?.role ?? '';
    final isDoctor = userRole == 'doctor';
    final selectedIndex = isDoctor ? 3 : 3; // Profile is at index 3 for both

    final sliverAppBar = SliverAppBar(
      title: Text('profile'.tr()),
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: colorScheme.onSurface,
      pinned: true,
      floating: false,
    );

    return MainScaffold(
      selectedIndex: selectedIndex,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(userDataProvider.future),
        child: CustomScrollView(
          slivers: [
            sliverAppBar,
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: userDataAsync.when(
                  data: (userModel) {
                    if (userModel == null) {
                      return Center(child: Text('userDataNotFound'.tr()));
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        children: [
                          // --- User Info Header مع صورة دائرية ---
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              // صورة البروفايل الدائرية
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  shape: BoxShape.circle, // دائرية
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  // قص دائري
                                  child: userModel.photoUrl != null &&
                                          userModel.photoUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: userModel.photoUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                            decoration: BoxDecoration(
                                              color: colorScheme.surfaceVariant,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: ImageLoadingIndicator(
                                                  size: 32),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            decoration: BoxDecoration(
                                              color: colorScheme.surfaceVariant,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.person_rounded,
                                              size: 48,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.person_rounded,
                                          size: 48,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                ),
                              ),
                              // زر التعديل
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(
                                            userModel: userModel),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle, // دائري أيضاً
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            userModel.displayName ?? 'N/A',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // ignore: unnecessary_null_comparison
                          if (userModel.role != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getRoleIcon(userModel.role),
                                    size: 16,
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getRoleDisplayName(userModel.role),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (userModel.email != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.email_rounded,
                                    size: 14,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    userModel.email!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),

                          // --- Options List محسنة ---
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _buildProfileOption(
                                  icon: Icons.edit_rounded,
                                  title: 'editProfile'.tr(),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(
                                            userModel: userModel),
                                      ),
                                    );
                                  },
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                                _buildProfileOption(
                                  icon: Icons.notifications_rounded,
                                  title: 'notifications'.tr(),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NotificationPreferencesScreen(),
                                      ),
                                    );
                                  },
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                                _buildProfileOption(
                                  icon: Icons.favorite_rounded,
                                  title: 'favorites'.tr(),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const FavoritesScreen(),
                                      ),
                                    );
                                  },
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                                _buildProfileOption(
                                  icon: Icons.settings_rounded,
                                  title: 'settings'.tr(),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SettingsScreen()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const ProfileHeaderShimmer(),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final titleColor =
            isDestructive ? colorScheme.error : colorScheme.onSurface;
        final iconColor =
            isDestructive ? colorScheme.error : colorScheme.primary;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (!isDestructive)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
