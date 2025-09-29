import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductManagementScreen extends ConsumerWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminAllProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement Add Product functionality
            },
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
        data: (products) {
          return SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: PaginatedDataTable(
                header: const Text('All Products'),
                rowsPerPage: 10,
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Distributor')),
                  DataColumn(label: Text('Package')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Actions')),
                ],
                source: _ProductDataSource(products, context),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductDataSource extends DataTableSource {
  _ProductDataSource(this.products, this.context);

  final List<ProductModel> products;
  final BuildContext context;

  @override
  DataRow? getRow(int index) {
    if (index >= products.length) {
      return null;
    }
    final product = products[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(product.name)),
        DataCell(Text(product.distributorId ?? 'N/A')),
        DataCell(Text(product.selectedPackage ?? 'N/A')),
        DataCell(Text(product.price?.toStringAsFixed(2) ?? 'N/A')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () {
                  // TODO: Implement edit functionality
                },
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                onPressed: () {
                  // TODO: Implement delete functionality
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => products.length;

  @override
  int get selectedRowCount => 0;
}
