// ignore_for_file: unused_import

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/favorites_screen.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:fieldawy_store/features/settings/presentation/screens/settings_screen.dart';
import 'package:fieldawy_store/features/notifications/notification_preferences_screen.dart';
import 'package:fieldawy_store/features/clinics/presentation/screens/clinics_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';

import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart'; // Required for temporary path
import 'package:fieldawy_store/features/authentication/data/storage_service.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/core/caching/image_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'doctor':
        return 'profile_feature.roles.doctor'.tr();
      case 'company':
        return 'profile_feature.roles.company'.tr();
      case 'distributor':
        return 'profile_feature.roles.distributor'.tr();
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
      title: Text('profile_feature.title'.tr()),
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
                      return Center(child: Text('profile_feature.user_data_not_found'.tr()));
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
                                          cacheManager: CustomImageCacheManager(), // Use custom cache manager
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
                                  onTap: () => _pickAndUploadImage(context, ref, userModel.id, userModel.photoUrl),
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
                                      Icons.camera_alt_rounded,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // ignore: unnecessary_null_comparison
                          if (userModel.role != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                      Flexible(
                                        child: Text(
                                          _getRoleDisplayName(userModel.role),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (userModel.role == 'doctor' && userModel.clinicCode != null) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: userModel.clinicCode!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم نسخ كود العيادة'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.qr_code_2_rounded, size: 14, color: Colors.black54),
                                          const SizedBox(width: 6),
                                          Text(
                                            userModel.clinicCode!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.copy_rounded, size: 12, color: Colors.blue),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // أيقونة مشاركة الموقع
                                  if (userModel.lastLatitude != null && userModel.lastLongitude != null)
                                    GestureDetector(
                                      onTap: () {
                                        final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${userModel.lastLatitude},${userModel.lastLongitude}';
                                        final String message = 'موقع عيادة: ${userModel.displayName}\nالرابط: $googleMapsUrl';
                                        Share.share(message);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: const Icon(
                                          Icons.share_location_rounded,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (userModel.distributionMethod != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_shipping_rounded,
                                        size: 14,
                                        color: colorScheme.onTertiaryContainer,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          userModel.distributionMethod == 'direct_distribution'
                                              ? 'profile_feature.distribution.direct'.tr()
                                              : userModel.distributionMethod == 'order_delivery'
                                                  ? 'profile_feature.distribution.delivery'.tr()
                                                  : userModel.distributionMethod == 'both' 
                                                      ? 'profile_feature.distribution.both'.tr()
                                                      : userModel.distributionMethod!,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onTertiaryContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              if (userModel.subscribersCount != null && userModel.subscribersCount! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_alt_rounded,
                                        size: 14,
                                        color: Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '${userModel.subscribersCount} ${'profile_feature.subscribers'.tr()}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (userModel.distributionMethod == null && userModel.email != null)
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
                                      Flexible(
                                        child: Text(
                                          userModel.email!,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
                                  title: 'profile_feature.edit_profile'.tr(),
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
                                  title: 'profile_feature.notifications'.tr(),
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
                                  title: 'profile_feature.favorites.title'.tr(),
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
                                  title: 'profile_feature.settings'.tr(),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SettingsScreen()),
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
                                  icon: Icons.privacy_tip_rounded,
                                  title: 'profile_feature.privacy_policy'.tr(),
                                  onTap: () async {
                                    final Uri url = Uri.parse('https://www.termsfeed.com/live/5b611a00-fddd-44ac-84c8-65d9c552c042'); 
                                    if (!await launchUrl(url)) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('profile_feature.privacy_policy_launch_error'.tr())),
                                        );
                                      }
                                    }
                                  },
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                                _buildProfileOption(
                                  icon: Icons.delete_forever_rounded,
                                  title: 'profile_feature.delete_account'.tr(),
                                  isDestructive: true,
                                  onTap: () => _confirmDeleteAccount(context, ref),
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

  Future<void> _pickAndUploadImage(
      BuildContext context, WidgetRef ref, String userId, String? currentPhotoUrl) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        // imageQuality: 70, // تمت إزالتها لتسريع الاستجابة، سيتم الرفع كما هي
      );

      if (pickedFile != null) {
        // إظهار مؤشر التحميل فوراً
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // تأخير بسيط جداً للسماح للـ Dialog بالظهور ورسمه قبل بدء العمليات الثقيلة
        await Future.delayed(const Duration(milliseconds: 100));

        final storageService = ref.read(storageServiceProvider);

        // محاولة حذف الصورة القديمة
        if (currentPhotoUrl != null) {
          final oldPublicId = storageService.extractPublicId(currentPhotoUrl);
          if (oldPublicId != null) {
             storageService.deleteImage(oldPublicId).then((success) {
               if (!success) print('⚠️ Failed to delete old profile image');
             });
          }
        }

        // ضغط الصورة قبل الرفع
        File fileToUpload = File(pickedFile.path);
        try {
          final tempDir = await getTemporaryDirectory();
          final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            pickedFile.path,
            targetPath,
            quality: 70, // جودة الضغط
            minWidth: 1024, // تقليل الأبعاد إذا كانت كبيرة جداً
            minHeight: 1024,
          );

          if (compressedFile != null) {
            fileToUpload = File(compressedFile.path);
          }
        } catch (e) {
          print('Error compressing image: $e');
          // في حال فشل الضغط، نستمر بالصورة الأصلية
        }

        // رفع الصورة (المضغوطة أو الأصلية)
        final downloadUrl = await storageService.uploadDocument(fileToUpload, 'profile_images');

        if (downloadUrl != null) {
          // تحديث رابط الصورة في قاعدة البيانات
          final userRepository = ref.read(userRepositoryProvider);
          await userRepository.updateProfileImage(userId, downloadUrl);
          
          // تحديث البيانات في الواجهة
          // ignore: unused_result
          ref.refresh(userDataProvider);

          if (context.mounted) {
            Navigator.of(context).pop(); // إغلاق مؤشر التحميل
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('profile_feature.profile_updated'.tr())),
            );
          }
        } else {
          if (context.mounted) {
             Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('profile_feature.image_upload_failed'.tr())),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
         // التأكد من إغلاق الـ Dialog إذا كان مفتوحاً
        if (Navigator.canPop(context)) {
             Navigator.of(context).pop(); 
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_feature.image_upload_error_generic'.tr())),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile_feature.delete_account'.tr()),
        content: Text('profile_feature.delete_account_confirmation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('profile_feature.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text('profile_feature.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final authService = ref.read(authServiceProvider);
        await authService.deleteAccount(); // Assuming this method exists

        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          // Navigate to login screen and clear stack
           Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('profile_feature.account_deletion_error_generic'.tr())),
          );
        }
      }
    }
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
