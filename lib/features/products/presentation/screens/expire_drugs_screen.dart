import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/features/products/application/expire_drugs_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';

class ExpireDrugsScreen extends StatelessWidget {
  const ExpireDrugsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    void openAddOptions() {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.hintColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'addProduct.expireSoon.title'.tr(),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary.withOpacity(0.12),
                      child: Icon(Icons.inventory_2_outlined,
                          color: colorScheme.primary),
                    ),
                    title: const Text('Add from Catalog'),
                    subtitle: Text('addProduct.expireSoon.subtitle'.tr()),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddFromCatalogScreen(
                              showExpirationDate: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.tertiary.withOpacity(0.12),
                      child: Icon(Icons.photo_library_outlined,
                          color: colorScheme.tertiary),
                    ),
                    title: const Text('Add from your Gallery'),
                    subtitle: Text('addProduct.expireSoon.subtitle'.tr()),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddProductOcrScreen(
                              showExpirationDate: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('addProduct.expireSoon.title'.tr()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final expireDrugsAsync = ref.watch(expireDrugsProvider);

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: expireDrugsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      key: const ValueKey('empty_expire_drugs'),
                      onRefresh: () async {
                        ref.invalidate(expireDrugsProvider);
                        await ref.read(expireDrugsProvider.future);
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              textTheme: textTheme,
                              colorScheme: colorScheme,
                              onAdd: openAddOptions,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    key: ValueKey('list_${items.length}'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'addProduct.expireSoon.subtitle'.tr(),
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${'products'.tr()}: ${items.length}',
                          style: textTheme.bodySmall?.copyWith(
                            color: textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(expireDrugsProvider);
                              await ref.read(expireDrugsProvider.future);
                            },
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.only(bottom: 108),
                              itemCount: items.length,
                              separatorBuilder: (context, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final product = item.product;
                                final expirationDate = item.expirationDate;
                                final now = DateTime.now();
                                final isExpired = expirationDate != null &&
                                    expirationDate.isBefore(
                                        DateTime(now.year, now.month + 1));
                                final expirationLabel = expirationDate != null
                                    ? '${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.year}'
                                    : null;
                                final priceLabel =
                                    '${product.price?.toStringAsFixed(2) ?? '0.00'} ${'EGP'.tr()}';

                                Widget buildInfoChip({
                                  required IconData icon,
                                  required String label,
                                  required Color background,
                                  required Color foreground,
                                }) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: background,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 16, color: foreground),
                                        const SizedBox(width: 6),
                                        Text(
                                          label,
                                          style:
                                              textTheme.labelMedium?.copyWith(
                                            color: foreground,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                Future<void> onEdit() async {
                                  final priceController = TextEditingController(
                                      text: product.price?.toString() ?? '');
                                  final expDateController =
                                      TextEditingController(
                                    text: expirationDate != null
                                        ? '${expirationDate.month.toString().padLeft(2, '0')}-${expirationDate.year}'
                                        : '',
                                  );
                                  DateTime? pickedDate = expirationDate;

                                  final newValues =
                                      await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (dialogContext) {
                                      return AlertDialog(
                                        title: Text('edit'.tr()),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: priceController,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: InputDecoration(
                                                  labelText: 'price'.tr()),
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: expDateController,
                                              readOnly: true,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'تاريخ الصلاحية (MM-YYYY)',
                                                suffixIcon: Icon(Icons
                                                    .calendar_month_outlined),
                                              ),
                                              onTap: () async {
                                                final now = DateTime.now();
                                                final picked =
                                                    await showDatePicker(
                                                  context: dialogContext,
                                                  initialDate:
                                                      pickedDate ?? now,
                                                  firstDate: DateTime(
                                                      now.year, now.month),
                                                  lastDate: DateTime(2101, 12),
                                                  helpText:
                                                      'اختر تاريخ الصلاحية',
                                                  fieldLabelText:
                                                      'تاريخ الصلاحية',
                                                  fieldHintText: 'MM-YYYY',
                                                );
                                                if (picked != null) {
                                                  pickedDate = picked;
                                                  expDateController.text =
                                                      '${picked.month.toString().padLeft(2, '0')}-${picked.year}';
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext),
                                            child: Text('cancel'.tr()),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              final price = double.tryParse(
                                                  priceController.text);
                                              if (price == null) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'يرجى إدخال سعر صحيح')),
                                                );
                                                return;
                                              }
                                              Navigator.pop(dialogContext, {
                                                'price': price,
                                                'expirationDate': pickedDate,
                                              });
                                            },
                                            child: const Text('حفظ'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (newValues != null) {
                                    final userId = ref
                                            .read(authServiceProvider)
                                            .currentUser
                                            ?.id ??
                                        '';
                                    final supabase = Supabase.instance.client;

                                    if (item.isOcr ?? false) {
                                      await supabase
                                          .from('distributor_ocr_products')
                                          .update({
                                        'price': newValues['price'],
                                        'expiration_date':
                                            newValues['expirationDate']
                                                ?.toIso8601String(),
                                      }).match({
                                        'distributor_id': userId,
                                        'ocr_product_id': product.id,
                                      });
                                    } else {
                                      await supabase
                                          .from('distributor_products')
                                          .update({
                                        'price': newValues['price'],
                                        'expiration_date':
                                            newValues['expirationDate']
                                                ?.toIso8601String(),
                                      }).match({
                                        'distributor_id': userId,
                                        'product_id': int.parse(product.id),
                                        'package':
                                            product.selectedPackage ?? '',
                                      });
                                    }
                                    ref.invalidate(expireDrugsProvider);
                                  }
                                }

                                Future<void> onDelete() async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text('delete'.tr()),
                                      content: const Text(
                                          'هل أنت متأكد أنك تريد حذف هذا المنتج؟'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                              dialogContext, false),
                                          child: Text('cancel'.tr()),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.error,
                                            foregroundColor:
                                                theme.colorScheme.onError,
                                          ),
                                          onPressed: () => Navigator.pop(
                                              dialogContext, true),
                                          child: Text('delete'.tr()),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final userId = ref
                                            .read(authServiceProvider)
                                            .currentUser
                                            ?.id ??
                                        '';
                                    final repository =
                                        ref.read(productRepositoryProvider);

                                    if (item.isOcr ?? false) {
                                      await repository
                                          .removeOcrProductFromDistributorCatalog(
                                        distributorId: userId,
                                        ocrProductId: product.id,
                                      );
                                    } else {
                                      await repository
                                          .removeProductFromDistributorCatalog(
                                        distributorId: userId,
                                        productId: product.id,
                                        package: product.selectedPackage ?? '',
                                      );
                                    }
                                    ref.invalidate(expireDrugsProvider);
                                  }
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: theme.cardColor,
                                    border: Border.all(
                                      color:
                                          colorScheme.outline.withOpacity(0.15),
                                    ),
                                    boxShadow:
                                        theme.brightness == Brightness.light
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ]
                                            : [],
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: product
                                                        .imageUrl.isNotEmpty
                                                    ? Image.network(
                                                        product.imageUrl,
                                                        width: 72,
                                                        height: 72,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (_, __, ___) =>
                                                                Container(
                                                          width: 72,
                                                          height: 72,
                                                          color: colorScheme
                                                              .surfaceVariant,
                                                          child: Icon(
                                                              Icons
                                                                  .medication_outlined,
                                                              color: colorScheme
                                                                  .onSurfaceVariant),
                                                        ),
                                                      )
                                                    : Container(
                                                        width: 72,
                                                        height: 72,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: colorScheme
                                                              .surfaceVariant,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        child: Icon(
                                                            Icons
                                                                .medication_outlined,
                                                            color: colorScheme
                                                                .onSurfaceVariant),
                                                      ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      style: textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    if (product.selectedPackage !=
                                                            null &&
                                                        product.selectedPackage!
                                                            .isNotEmpty)
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(bottom: 8),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: colorScheme
                                                              .secondaryContainer,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Text(
                                                          product
                                                              .selectedPackage!,
                                                          style: textTheme
                                                              .labelMedium
                                                              ?.copyWith(
                                                            color: colorScheme
                                                                .onSecondaryContainer,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        buildInfoChip(
                                                          icon: Icons
                                                              .sell_outlined,
                                                          label: priceLabel,
                                                          background: colorScheme
                                                              .primaryContainer,
                                                          foreground: colorScheme
                                                              .onPrimaryContainer,
                                                        ),
                                                        if (expirationLabel !=
                                                            null)
                                                          buildInfoChip(
                                                            icon: Icons
                                                                .schedule_outlined,
                                                            label:
                                                                expirationLabel,
                                                            background: isExpired
                                                                ? colorScheme
                                                                    .errorContainer
                                                                : colorScheme
                                                                    .tertiaryContainer,
                                                            foreground: isExpired
                                                                ? colorScheme
                                                                    .onErrorContainer
                                                                : colorScheme
                                                                    .onTertiaryContainer,
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18),
                                                label: Text('edit'.tr()),
                                                onPressed: onEdit,
                                              ),
                                              const SizedBox(width: 12),
                                              TextButton.icon(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18),
                                                label: Text('delete'.tr()),
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      theme.colorScheme.error,
                                                ),
                                                onPressed: onDelete,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(expireDrugsProvider),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddOptions,
        icon: const Icon(Icons.add),
        label: Text('add'.tr()),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.textTheme,
    required this.colorScheme,
    required this.onAdd,
  });

  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: colorScheme.primary.withOpacity(0.12),
              child: Icon(Icons.inventory_outlined,
                  color: colorScheme.primary, size: 32),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد أدوية منتهية الصلاحية',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'addProduct.expireSoon.subtitle'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('add'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 44),
            const SizedBox(height: 16),
            Text(
              'An error occurred:'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
