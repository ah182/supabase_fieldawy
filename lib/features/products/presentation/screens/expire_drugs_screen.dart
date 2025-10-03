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
    return Scaffold(
      appBar: AppBar(
        title: Text('Expire Drugs'),
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final expireDrugsAsync = ref.watch(expireDrugsProvider);
          return expireDrugsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(child: Text('لا توجد أدوية منتهية الصلاحية'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final product = item.product;
                  final expirationDate = item.expirationDate;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {},
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: product.imageUrl.isNotEmpty
                                  ? Image.network(
                                      product.imageUrl,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.contain,
                                    )
                                  : Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.medication, size: 32, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (expirationDate != null)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.year}',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Colors.red[900],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (product.selectedPackage != null && product.selectedPackage!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4, bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        product.selectedPackage!,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${product.price?.toStringAsFixed(2) ?? '0.00'} جنيه',
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                        tooltip: 'تعديل',
                                        onPressed: () async {
                                          final newValues = await showDialog<Map<String, dynamic>>(
                                            context: context,
                                            builder: (context) {
                                              final priceController = TextEditingController(text: product.price?.toString() ?? '');
                                              final expDateController = TextEditingController(
                                                text: expirationDate != null ?
                                                  '${expirationDate.month.toString().padLeft(2, '0')}-${expirationDate.year}' : ''
                                              );
                                              DateTime? pickedDate = expirationDate;
                                              return AlertDialog(
                                                title: const Text('تعديل المنتج'),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller: priceController,
                                                      keyboardType: TextInputType.number,
                                                      decoration: const InputDecoration(labelText: 'السعر'),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    TextField(
                                                      controller: expDateController,
                                                      readOnly: true,
                                                      decoration: const InputDecoration(labelText: 'تاريخ الصلاحية (MM-YYYY)'),
                                                      onTap: () async {
                                                        final now = DateTime.now();
                                                        final picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: pickedDate ?? now,
                                                          firstDate: DateTime(now.year, now.month),
                                                          lastDate: DateTime(2101, 12),
                                                          helpText: 'اختر تاريخ الصلاحية',
                                                          fieldLabelText: 'تاريخ الصلاحية',
                                                          fieldHintText: 'MM-YYYY',
                                                        );
                                                        if (picked != null) {
                                                          pickedDate = picked;
                                                          expDateController.text = '${picked.month.toString().padLeft(2, '0')}-${picked.year}';
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('إلغاء'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      final price = double.tryParse(priceController.text);
                                                      if (price == null) {
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال سعر صحيح')));
                                                        return;
                                                      }
                                                      Navigator.pop(context, {
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
                                            // تحديد نوع المنتج (OCR أو عادي) بناءً على isOcr flag
                                            final userId = ref.read(authServiceProvider).currentUser?.id ?? '';
                                            final supabase = Supabase.instance.client;
                                            if (item.isOcr ?? false) {
                                              // تحديث في distributor_ocr_products
                                              await supabase.from('distributor_ocr_products').update({
                                                'price': newValues['price'],
                                                'expiration_date': newValues['expirationDate']?.toIso8601String(),
                                              }).match({
                                                'distributor_id': userId,
                                                'ocr_product_id': product.id,
                                              });
                                            } else {
                                              // تحديث في distributor_products
                                              await supabase.from('distributor_products').update({
                                                'price': newValues['price'],
                                                'expiration_date': newValues['expirationDate']?.toIso8601String(),
                                              }).match({
                                                'distributor_id': userId,
                                                'product_id': int.parse(product.id),
                                                'package': product.selectedPackage ?? '',
                                              });
                                            }
                                            ref.invalidate(expireDrugsProvider);
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        tooltip: 'حذف',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('تأكيد الحذف'),
                                              content: const Text('هل أنت متأكد أنك تريد حذف هذا المنتج؟'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('إلغاء'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('حذف'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            final userId = ref.read(authServiceProvider).currentUser?.id ?? '';
                                            final repository = ref.read(
                                                productRepositoryProvider);
                                            if (item.isOcr ?? false) {
                                              // حذف من distributor_ocr_products عبر الريبو
                                              await repository
                                                  .removeOcrProductFromDistributorCatalog(
                                                distributorId: userId,
                                                ocrProductId: product.id,
                                              );
                                            } else {
                                              // حذف من distributor_products عبر الريبو
                                              await repository
                                                  .removeProductFromDistributorCatalog(
                                                distributorId: userId,
                                                productId: product.id,
                                                package:
                                                    product.selectedPackage ??
                                                        '',
                                              );
                                            }
                                            ref.invalidate(expireDrugsProvider);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SimpleDialog(
                title: Text('addProduct.expireSoon.title'.tr()),
                children: <Widget>[
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddFromCatalogScreen(showExpirationDate: true)));
                    },
                    child: const Text('Add from Catalog'),
                  ),
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddProductOcrScreen(showExpirationDate: true)));
                    },
                    child: const Text('Add from your Gallery'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
