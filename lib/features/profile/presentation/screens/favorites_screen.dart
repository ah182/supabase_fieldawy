// ignore_for_file: unused_import

import 'package:collection/collection.dart';
import 'package:fieldawy_store/widgets/refreshable_error_widget.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:fieldawy_store/features/products/application/favorites_provider.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';
import 'package:fieldawy_store/widgets/product_card.dart';
import 'package:fieldawy_store/widgets/user_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/main.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/widgets/unified_search_bar.dart';
import 'package:fieldawy_store/core/utils/network_guard.dart'; // Add NetworkGuard import
// ignore: unnecessary_import
import 'package:intl/intl.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/product_dialogs.dart';

class FavoritesScreen extends HookConsumerWidget {
  const FavoritesScreen({super.key});

  int _calculateSearchScore(ProductModel product, String query) {
    int score = 0;

    final productName = product.name.toLowerCase();
    final activePrinciple = (product.activePrinciple ?? '').toLowerCase();
    final distributorName = (product.distributorId ?? '').toLowerCase();
    final company = (product.company ?? '').toLowerCase();
    final packageSize = (product.selectedPackage ?? '').toLowerCase();
    final description = (product.description ?? '').toLowerCase();

    if (productName.contains(query)) score += 10;
    if (activePrinciple.contains(query)) score += 8;
    if (distributorName.contains(query)) score += 6;

    if (company.contains(query)) score += 4;
    if (packageSize.contains(query)) score += 2;
    if (description.contains(query)) score += 2;

    if (productName.startsWith(query)) score += 5;
    if (activePrinciple.startsWith(query)) score += 3;
    if (distributorName.startsWith(query)) score += 3;

    return score;
  }

  void _showProductDetailDialog(
      BuildContext context, WidgetRef ref, ProductModel product) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Material(
              type: MaterialType.transparency,
              child: _buildProductDetailDialog(context, ref, product),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation1,
            curve: Curves.elasticOut,
          ),
          child: FadeTransition(
            opacity: animation1,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildProductDetailDialog(
      BuildContext context, WidgetRef ref, ProductModel product) {
    String? role;
    bool isLoadingRole = true;

    return StatefulBuilder(
      builder: (context, setState) {
        // دالة لجلب بيانات المستخدم (الدور والاسم الأحدث) إذا لم تكن متوفرة في الـ provider
        Future<void> loadUserRole() async {
          if (product.distributorUuid == null || !isLoadingRole) return;
          try {
            final response = await NetworkGuard.execute(() async {
              return await Supabase.instance.client
                  .from('users')
                  .select('role, display_name')
                  .eq('id', product.distributorUuid!)
                  .maybeSingle();
            });
            if (context.mounted) {
              setState(() {
                role = response?['role']?.toString();
                isLoadingRole = false;
              });
            }
          } catch (e) {
            if (context.mounted) setState(() => isLoadingRole = false);
          }
        }

        // تشغيل الجلب
        loadUserRole();

        final size = MediaQuery.of(context).size;
        final isSmallScreen = size.width < 600;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Consumer(
          builder: (context, ref, child) {
            // جلب أحدث اسم للموزع ديناميكياً
            final distributorsAsync = ref.watch(distributorsProvider);
            final currentDistributorName = distributorsAsync.maybeWhen(
              data: (distributors) {
                final dist = distributors.firstWhereOrNull((d) => d.id == product.distributorUuid);
                return dist?.displayName ?? product.distributorId;
              },
              orElse: () => product.distributorId,
            );

            String formatPackageText(String package) {
              final currentLocale = Localizations.localeOf(context).languageCode;
              if (currentLocale == 'ar' &&
                  package.toLowerCase().contains(' ml') &&
                  package.toLowerCase().contains('vial')) {
                final parts = package.split(' ');
                if (parts.length >= 3) {
                  final number = parts.firstWhere(
                      (part) => RegExp(r'^\d+').hasMatch(part),
                      orElse: () => '');
                  final unit = parts.firstWhere(
                      (part) => part.toLowerCase().contains(' ml'),
                      orElse: () => '');
                  final container = parts.firstWhere(
                      (part) => part.toLowerCase().contains('vial'),
                      orElse: () => '');
                  if (number.isNotEmpty && unit.isNotEmpty && container.isNotEmpty) {
                    return '$number$unit $container';
                  }
                }
              }
              return package;
            }

            final containerColor = isDark
                ? Colors.grey.shade800.withOpacity(0.5)
                : Colors.white.withOpacity(0.8);
            final iconColor = isDark ? Colors.white70 : theme.colorScheme.primary;
            final priceColor =
                isDark ? Colors.lightGreenAccent.shade200 : Colors.green.shade700;
            final favoriteColor =
                isDark ? Colors.redAccent.shade100 : Colors.red.shade400;
            final packageBgColor = isDark
                ? const Color.fromARGB(255, 216, 222, 249).withOpacity(0.1)
                : Colors.blue.shade50.withOpacity(0.8);
            final packageBorderColor = isDark
                ? const Color.fromARGB(255, 102, 126, 162)
                : Colors.blue.shade200;
            final imageBgColor = isDark
                ? const Color.fromARGB(255, 21, 15, 15).withOpacity(0.3)
                : Colors.white.withOpacity(0.7);
            final backgroundColor =
                isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE3F2FD);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: isSmallScreen ? size.width * 0.95 : 400,
                height: size.height * 0.85,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.grey.shade600.withOpacity(0.3)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: containerColor,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.arrow_back, color: iconColor),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              Row(
                                children: [
                                  if (product.distributorUuid != null) ...[
                                    GestureDetector(
                                      onTap: () {
                                        if (role == 'doctor') {
                                          UserDetailsSheet.show(context, ref, product.distributorUuid!);
                                        } else {
                                          DistributorDetailsSheet.show(
                                              context, product.distributorUuid!);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          role == 'doctor' ? Icons.person : Icons.location_on,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  GestureDetector(
                                    onTap: () async {
                                      if (role == 'doctor') {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('تنبيه'),
                                            content: const Text('هذا المنتج تمت إضافته بواسطة طبيب، والأطباء ليس لديهم كتالوج منتجات خاص بهم.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('حسناً'),
                                              ),
                                            ],
                                          ),
                                        );
                                        return;
                                      }
                                      if (currentDistributorName != null) {
                                        // Show loading indicator
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(child: CircularProgressIndicator()),
                                        );

                                        // Small delay for UX
                                        await Future.delayed(const Duration(milliseconds: 400));

                                        if (!context.mounted) return;
                                        Navigator.of(context).pop(); // Close loading
                                        Navigator.of(context).pop(); // Close the original dialog
                                        
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (context) => DrawerWrapper(
                                              distributorId:
                                                  currentDistributorName,
                                            ),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        currentDistributorName ??
                                            'home.product_dialog.unknown_distributor'.tr(),
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (product.company != null && product.company!.isNotEmpty)
                            Text(
                              product.company!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (product.activePrinciple != null &&
                              product.activePrinciple!.isNotEmpty)
                            Text(
                              product.activePrinciple!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Text(
                                  '${product.price?.toStringAsFixed(0) ?? '0'} ${'EGP'.tr()}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: priceColor,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Consumer(
                                builder: (context, ref, child) {
                                  final favoritesMap = ref.watch(favoritesProvider);
                                  final isFavorite = favoritesMap.containsKey(
                                      '${product.id}_${product.distributorId}_${product.selectedPackage}');
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: containerColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFavorite ? Colors.red : favoriteColor,
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(favoritesProvider.notifier)
                                            .toggleFavorite(product);
                                        scaffoldMessengerKey.currentState?.showSnackBar(
                                          SnackBar(
                                            elevation: 0,
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: Colors.transparent,
                                            content: AwesomeSnackbarContent(
                                              title: 'Favorite Status',
                                              key: ValueKey(
                                                  'favorite_snackbar_${DateTime.now().millisecondsSinceEpoch}'),
                                              message: isFavorite
                                                  ? 'تمت إزالة ${product.name} من المفضلة'
                                                  : 'تمت إضافة ${product.name} للمفضلة',
                                              contentType: isFavorite
                                                  ? ContentType.failure
                                                  : ContentType.success,
                                            ),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: RepaintBoundary(
                              child: Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: imageBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.contain,
                                  memCacheWidth: 800,
                                  memCacheHeight: 800,
                                  placeholder: (context, url) => const Center(
                                    child: ImageLoadingIndicator(size: 50),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 60,
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'home.product_dialog.active_principle'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: '',
                                  style: TextStyle(
                                    color: Colors.transparent,
                                  ),
                                ),
                                TextSpan(
                                  text: product.activePrinciple ?? 'غير محدد',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (product.selectedPackage != null &&
                              product.selectedPackage!.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: packageBgColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: packageBorderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                      color: isDark
                                          ? const Color.fromARGB(255, 6, 149, 245)
                                          : const Color.fromARGB(255, 4, 90, 160),
                                    ),
                                    const SizedBox(width: 8),
                                    Directionality(
                                      textDirection: ui.TextDirection.ltr,
                                      child: Text(
                                        formatPackageText(product.selectedPackage!),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 30),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primaryContainer.withOpacity(0.3),
                                    theme.colorScheme.secondaryContainer
                                        .withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'home.product_dialog.medical_info_note'.tr(),
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontSize: 16,
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
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
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final debouncedSearchQuery = useState<String>('');

    // Get user role to determine the correct index for the Profile tab
    final userRole = ref.watch(userDataProvider).asData?.value?.role ?? '';
    final isDoctor = userRole == 'doctor';
    final profileIndex = isDoctor ? 3 : 2;

    useEffect(() {
      final timer = Timer(const Duration(milliseconds: 500), () {
        debouncedSearchQuery.value = searchQuery.value;
      });
      return timer.cancel;
    }, [searchQuery.value]);

    return GestureDetector(
      onTap: () {
        searchFocusNode.unfocus();
      },
      child: MainScaffold(
        selectedIndex: profileIndex, // Use the dynamic index here
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(favoriteProductsProvider);
            await Future.delayed(const Duration(milliseconds: 150));
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text('profile_feature.favorites.title'.tr()),
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                scrolledUnderElevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: UnifiedSearchBar(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: (value) {
                        searchQuery.value = value;
                      },
                      onClear: () {
                        searchQuery.value = '';
                      },
                      hintText: 'profile_feature.favorites.search_hint'.tr(),
                    ),
                  ),
                ),
              ),
              switch (favoritesAsync) {
                AsyncData(:final value) => () {
                    // While revalidating, if there's no data, show a loader.
                    // This prevents the "No Favorites" message from flashing.
                    if (favoritesAsync.isLoading && value.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final filteredFavorites = debouncedSearchQuery.value.isEmpty
                        ? value
                        : value.where((favoriteItem) {
                            final product = favoriteItem.product;
                            final query =
                                debouncedSearchQuery.value.toLowerCase().trim();
                            final productName = product.name.toLowerCase();
                            final activePrinciple =
                                (product.activePrinciple ?? '').toLowerCase();
                            final distributorName =
                                (product.distributorId ?? '').toLowerCase();
                            final company = (product.company ?? '').toLowerCase();
                            final packageSize =
                                (product.selectedPackage ?? '').toLowerCase();
                            final description =
                                (product.description ?? '').toLowerCase();
                            final action = (product.action ?? '').toLowerCase();

                            bool highPriorityMatch =
                                productName.contains(query) ||
                                    activePrinciple.contains(query) ||
                                    distributorName.contains(query);

                            bool mediumPriorityMatch = company.contains(query) ||
                                packageSize.contains(query) ||
                                description.contains(query);

                            bool lowPriorityMatch = action.contains(query);

                            return highPriorityMatch ||
                                mediumPriorityMatch ||
                                lowPriorityMatch;
                          }).toList()
                      ..sort((a, b) {
                        final query =
                            debouncedSearchQuery.value.toLowerCase().trim();
                        int scoreA = _calculateSearchScore(a.product, query);
                        int scoreB = _calculateSearchScore(b.product, query);
                        return scoreB.compareTo(scoreA);
                      });

                    if (filteredFavorites.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.favorite_border,
                                size: 80,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                debouncedSearchQuery.value.isEmpty
                                    ? 'profile_feature.favorites.no_favorites'.tr()
                                    : 'profile_feature.favorites.no_results'.tr(namedArgs: {'query': debouncedSearchQuery.value}),
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () => ref.refresh(favoriteProductsProvider),
                                icon: const Icon(Icons.refresh),
                                label: Text('retry'.tr()),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.all(8.0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                          childAspectRatio: 0.68, // زيادة الارتفاع للـ surgical badge
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final favoriteItem = filteredFavorites[index];
                            final product = favoriteItem.product;
                            
                            // Build the appropriate widget based on type
                            Widget? overlayBadge;
                            Widget? statusBadge;
                            bool showPriceChange = false;
                            
                            switch (favoriteItem.type) {
                              case 'expire_soon':
                                if (favoriteItem.expirationDate != null) {
                                  overlayBadge = _buildExpirationBadge(context, favoriteItem.expirationDate!);
                                }
                                break;
                              case 'surgical':
                                if (favoriteItem.status != null) {
                                  statusBadge = _buildStatusBadge(context, favoriteItem.status!);
                                }
                                break;
                              case 'offers':
                                overlayBadge = _buildOfferBadge(context);
                                break;
                              case 'price_action':
                                showPriceChange = favoriteItem.showPriceChange;
                                break;
                            }
                            
                            return ProductCard(
                              product: product,
                              searchQuery: debouncedSearchQuery.value,
                              productType: favoriteItem.type,
                              expirationDate: favoriteItem.expirationDate,
                              status: favoriteItem.status,
                              showPriceChange: showPriceChange,
                              onTap: () {
                                // Show the appropriate dialog based on product type
                                switch (favoriteItem.type) {
                                  case 'expire_soon':
                                    showProductDialog(
                                      context,
                                      product,
                                      expirationDate: favoriteItem.expirationDate,
                                    );
                                    break;
                                  case 'surgical':
                                    showSurgicalToolDialog(context, product);
                                    break;
                                  case 'offers':
                                    showOfferProductDialog(
                                      context,
                                      product,
                                      expirationDate: favoriteItem.expirationDate,
                                    );
                                    break;
                                  case 'price_action':
                                  case 'home':
                                  default:
                                    _showProductDetailDialog(context, ref, product);
                                    break;
                                }
                              },
                              overlayBadge: overlayBadge,
                              statusBadge: statusBadge,
                            );
                          },
                          childCount: filteredFavorites.length,
                        ),
                      ),
                    );
                  }(),
                AsyncError(:final error) => SliverFillRemaining(
                    child: RefreshableErrorWidget(
                      message: 'حدث خطأ: $error',
                      onRetry: () => ref.refresh(favoriteProductsProvider),
                    ),
                  ),
                _ => const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              }
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for building badges
  Widget _buildExpirationBadge(BuildContext context, DateTime expirationDate) {
    final now = DateTime.now();
    final isExpired = expirationDate.isBefore(DateTime(now.year, now.month + 1));

    return Positioned(
      bottom: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isExpired ? Colors.red.shade700 : Colors.orange.shade700,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpired ? Icons.warning_rounded : Icons.schedule_rounded,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('MM/yyyy').format(expirationDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color getBadgeColor() {
      switch (status) {
        case 'جديد':
          return Colors.green;
        case 'مستعمل':
          return Colors.orange;
        case 'كسر زيرو':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    IconData getBadgeIcon() {
      switch (status) {
        case 'جديد':
          return Icons.new_releases_rounded;
        case 'مستعمل':
          return Icons.history_rounded;
        case 'كسر زيرو':
          return Icons.star_rounded;
        default:
          return Icons.info_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getBadgeColor(),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getBadgeIcon(),
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferBadge(BuildContext context) {
    return Positioned(
      top: 6,
      left: -40,
      child: Transform.rotate(
        angle: -0.785398, // -45 degrees
        child: Container(
          width: 120,
          height: 25,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE53935), // Red dark
                Color(0xFFEF5350), // Red light
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'Offer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
