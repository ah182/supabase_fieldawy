import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/widgets/product_card.dart';
import 'package:fieldawy_store/main.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
// ignore: unused_import
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';

import '../../application/user_data_provider.dart';
import 'package:fieldawy_store/features/profile/presentation/screens/profile_screen.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fieldawy_store/features/products/application/favorites_provider.dart';
// ignore: duplicate_import
import 'package:fieldawy_store/features/products/data/product_repository.dart';

final allDistributorProductsForSearchProvider =
    FutureProvider<List<ProductModel>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getAllDistributorProducts();
});

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  // دالة مساعدة لحساب نقاط الأولوية في البحث
  int _calculateSearchScore(ProductModel product, String query) {
    int score = 0;

    final productName = product.name.toLowerCase();
    final activePrinciple = (product.activePrinciple ?? '').toLowerCase();
    final distributorName = (product.distributorId ?? '').toLowerCase();
    final company = (product.company ?? '').toLowerCase();
    final packageSize = (product.selectedPackage ?? '').toLowerCase();
    final description = (product.description ?? '').toLowerCase();

    // نقاط عالية للمطابقات المهمة
    if (productName.contains(query)) score += 10;
    if (activePrinciple.contains(query)) score += 8;
    if (distributorName.contains(query)) score += 6;

    // نقاط متوسطة للمطابقات الثانوية
    if (company.contains(query)) score += 4;
    if (packageSize.contains(query)) score += 2;
    if (description.contains(query)) score += 2;

    // نقاط إضافية للمطابقة في بداية النص
    if (productName.startsWith(query)) score += 5;
    if (activePrinciple.startsWith(query)) score += 3;
    if (distributorName.startsWith(query)) score += 3;

    return score;
  }

  // دالة لإظهار ديالوج تفاصيل المنتج مع أنيميشن احترافي
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

// بناء ديالوج تفاصيل المنتج - مع دعم الثيم الداكن والفاتح
  Widget _buildProductDetailDialog(
      BuildContext context, WidgetRef ref, ProductModel product) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // دالة لتصحيح ترتيب نص العبوة للغة العربية
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

    // ألوان حسب الثيم
    // ignore: unused_local_variable
    final backgroundGradient = isDark
        ? LinearGradient(
            colors: const [
              Color(0xFF1E1E2E),
              Color(0xFF2A2A3A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: const [
              Color(0xFFE3F2FD),
              Color(0xFFF8FDFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

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
                  // === Header مع badge الموزع ===
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
                      // Badge اسم الموزع
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          product.distributorId ?? 'موزع غير معروف',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // === اسم الشركة ===
                  if (product.company != null && product.company!.isNotEmpty)
                    Text(
                      product.company!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // === اسم المنتج ===
                  Text(
                    product.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // === المادة الفعالة ===
                  if (product.activePrinciple != null &&
                      product.activePrinciple!.isNotEmpty)
                    Text(
                      product.activePrinciple!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // === السعر مع أيقونة القلب ===
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
                          final favoriteIds = ref.watch(favoritesProvider);
                          final isFavorite = favoriteIds.contains(
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
                                          : 'addedToFavorites'
                                              .tr(args: [product.name]),
                                      contentType: isFavorite
                                          ? ContentType.failure
                                          : ContentType.success,
                                    ),
                                    duration: const Duration(seconds: 1),
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

                  // === صورة المنتج ===
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
                          // تخفيف الحمل عند عرض الصورة كبيرة في الديالوج
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

                  // === وصف المنتج ===
                  Text(
                    'Active principle',
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
                        TextSpan(
                          text: '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
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

                  // === حجم العبوة مُصغر بدون كلمة Size ===
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

                  // === رسالة التطبيق - مُكبرة ===
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'لمزيد من المعلومات يرجى تنزيل تطبيق',
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
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse(
                                  'https://apkpure.net/ar/vet-eye/com.fieldawy.veteye/download/7.5.1');
                              try {
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url,
                                      mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                  SnackBar(
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    content: AwesomeSnackbarContent(
                                      key: ValueKey(
                                          'download_snackbar_${DateTime.now().millisecondsSinceEpoch}'),
                                      title: 'تنبيه',
                                      message: 'تعذر فتح الرابط',
                                      contentType: ContentType.warning,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.download_outlined,
                                    color: theme.colorScheme.onPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Vet Eye',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

    @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedProductsProvider);
    final products = paginatedState.products;

    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final focusNode = useFocusNode();
    final debouncedSearchQuery = useState<String>('');
    final scrollController = useScrollController();
    final isRefreshButtonEnabled = useState<bool>(true);
    final refreshButtonCountdown = useState<int>(0);

    final query = debouncedSearchQuery.value.toLowerCase().trim();
    final allDistributorProductsAsync =
        ref.watch(allDistributorProductsForSearchProvider);
    final isLoading = allDistributorProductsAsync.isLoading;
    final prevIsLoading = useState(isLoading);

    useEffect(() {
      if (prevIsLoading.value && !isLoading && query.isNotEmpty) {
        // Loading has just finished, let's give focus back to search bar.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (focusNode.hasPrimaryFocus == false) {
              focusNode.requestFocus();
            }
          });
        });
      }
      prevIsLoading.value = isLoading;
      return null;
    }, [isLoading, focusNode, query]);

    // Throttle/Lock عند الاقتراب من نهاية القائمة
    useEffect(() {
      bool isFetching = false;

      void listener() {
        if (!scrollController.hasClients) return;
        final threshold = scrollController.position.maxScrollExtent - 200;

        final state = ref.read(paginatedProductsProvider);

        if (scrollController.position.pixels >= threshold &&
            !isFetching &&
            state.hasMore &&
            !state.isLoading) {
          isFetching = true;
          ref
              .read(paginatedProductsProvider.notifier)
              .fetchNextPage()
              .whenComplete(() {
            isFetching = false;
          });
        }
      }

      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController, ref]);

    // Countdown timer for refresh button
    useEffect(() {
      if (!isRefreshButtonEnabled.value && refreshButtonCountdown.value > 0) {
        final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          refreshButtonCountdown.value--;
          if (refreshButtonCountdown.value <= 0) {
            isRefreshButtonEnabled.value = true;
            timer.cancel();
          }
        });
        return timer.cancel;
      }
      return () {};
    }, [isRefreshButtonEnabled.value, refreshButtonCountdown.value]);

    useEffect(() {
      final timer = Timer(const Duration(milliseconds: 500), () {
        debouncedSearchQuery.value = searchQuery.value;
      });
      return timer.cancel;
    }, [searchQuery.value]);

    final sliverAppBar = SliverAppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => ZoomDrawer.of(context)!.toggle(),
      ),
      title: Text('homeScreen'.tr()),
      elevation: 0,
      scrolledUnderElevation: 0,
      forceElevated: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          color: isRefreshButtonEnabled.value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          onPressed: isRefreshButtonEnabled.value
              ? () {
                  ref.read(paginatedProductsProvider.notifier).refresh();
                  isRefreshButtonEnabled.value = false;
                  refreshButtonCountdown.value = 30;
                }
              : null,
        ),
        Consumer(
          builder: (context, ref, child) {
            final userDataAsync = ref.watch(userDataProvider);
            return userDataAsync.when(
              data: (user) {
                if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0)
                        .add(const EdgeInsets.only(top: 4.0)),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: user.photoUrl!,
                              width: 29,
                              height: 29,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                width: 29,
                                height: 29,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 15.0),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  focusNode: focusNode,
                  onChanged: (value) {
                    searchQuery.value = value;
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث عن دواء، مادة فعالة...',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.primary,
                      size: 25,
                    ),
                    suffixIcon: searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              searchController.clear();
                              searchQuery.value = '';
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: () {
        focusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(paginatedProductsProvider.notifier).refresh(),
          child: () {
            if (products.isEmpty && !paginatedState.hasMore) {
              return CustomScrollView(
                slivers: [
                  sliverAppBar,
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد منتجات متاحة حاليًا.',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            if (products.isEmpty && paginatedState.isLoading) {
              return CustomScrollView(
                slivers: [
                  sliverAppBar,
                  SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                        child: ProductCardShimmer(),
                      );
                    },
                  ),
                ],
              );
            }

            // === فلترة + ترتيب باستخدام useMemoized لعدم إعادة الحساب كل build ===
            final List<ProductModel> productsToFilter = query.isNotEmpty
                ? (allDistributorProductsAsync.value ?? [])
                : products;

            final filteredProducts = useMemoized(() {
              if (query.isEmpty) return productsToFilter;

              final list = productsToFilter.where((product) {
                final productName = product.name.toLowerCase();
                final distributorName =
                    (product.distributorId ?? '').toLowerCase();
                final activePrinciple =
                    (product.activePrinciple ?? '').toLowerCase();
                final packageSize =
                    (product.selectedPackage ?? '').toLowerCase();
                final company = (product.company ?? '').toLowerCase();
                final description = (product.description ?? '').toLowerCase();
                final action = (product.action ?? '').toLowerCase();

                return productName.contains(query) ||
                    activePrinciple.contains(query) ||
                    distributorName.contains(query) ||
                    company.contains(query) ||
                    packageSize.contains(query) ||
                    description.contains(query) ||
                    action.contains(query);
              }).toList();

              list.sort((a, b) {
                final scoreA = _calculateSearchScore(a, query);
                final scoreB = _calculateSearchScore(b, query);
                return scoreB.compareTo(scoreA);
              });

              return list;
            }, [productsToFilter, query]);

            if (query.isNotEmpty && (allDistributorProductsAsync.isLoading)) {
              return CustomScrollView(
                slivers: [
                  sliverAppBar,
                  SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                        child: ProductCardShimmer(),
                      );
                    },
                  ),
                ],
              );
            }

            return CustomScrollView(
              controller: scrollController,
              slivers: [
                sliverAppBar,
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: debouncedSearchQuery.value.isEmpty
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3)
                          : Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: debouncedSearchQuery.value.isEmpty
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2)
                            : Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          debouncedSearchQuery.value.isEmpty
                              ? Icons.storefront_outlined
                              : Icons.search_outlined,
                          size: 16,
                          color: debouncedSearchQuery.value.isEmpty
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          debouncedSearchQuery.value.isEmpty
                              ? 'عرض ${filteredProducts.length} منتج من أحدث العروض'
                              : 'وُجد ${filteredProducts.length} منتج',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: debouncedSearchQuery.value.isEmpty
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filteredProducts.isEmpty &&
                    debouncedSearchQuery.value.isNotEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد نتائج للبحث عن "${debouncedSearchQuery.value}"',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 1.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = filteredProducts[index];
                          return RepaintBoundary(
                            child: _KeepAlive(
                              child: ProductCard(
                                product: product,
                                searchQuery: debouncedSearchQuery.value,
                                onTap: () {
                                  _showProductDetailDialog(
                                      context, ref, product);
                                },
                              ),
                            ),
                          );
                        },
                        childCount: filteredProducts.length,
                        addAutomaticKeepAlives: true,
                      ),
                    ),
                  ),
                if (paginatedState.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: ProductCardShimmer(),
                      ),
                    ),
                  ),
              ],
            );
          }(),
        ),
      ),
    );
  }
}

// ويدجت KeepAlive خفيفة لتثبيت عناصر الجريد
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
