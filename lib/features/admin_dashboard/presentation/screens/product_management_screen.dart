import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/core/localization/language_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/books/application/books_provider.dart';
import 'package:fieldawy_store/features/books/data/books_repository.dart'; // للـ booksRepositoryProvider
import 'package:fieldawy_store/features/books/domain/book_model.dart';
import 'package:fieldawy_store/features/courses/application/courses_provider.dart';
import 'package:fieldawy_store/features/courses/data/courses_repository.dart'; // للـ coursesRepositoryProvider
import 'package:fieldawy_store/features/courses/domain/course_model.dart';
import 'package:fieldawy_store/features/jobs/application/job_offers_provider.dart';
import 'package:fieldawy_store/features/jobs/data/job_offers_repository.dart'; // للـ jobOffersRepositoryProvider
import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:fieldawy_store/features/vet_supplies/application/vet_supplies_provider.dart';
import 'package:fieldawy_store/features/vet_supplies/data/vet_supplies_repository.dart';
import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:fieldawy_store/features/offers/application/offers_provider.dart';
import 'package:fieldawy_store/features/offers/data/offers_repository.dart'; // للـ offersRepositoryProvider
import 'package:fieldawy_store/features/offers/domain/offer_model.dart';
import 'package:fieldawy_store/features/surgical_tools/application/surgical_tools_provider.dart';
import 'package:fieldawy_store/features/surgical_tools/data/surgical_tools_repository.dart'; // للـ surgicalToolsRepositoryProvider
import 'package:fieldawy_store/features/surgical_tools/domain/surgical_tool_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProductManagementScreen extends ConsumerStatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  ConsumerState<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends ConsumerState<ProductManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isArabic = locale.languageCode == 'ar';
    final direction = isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr;
    
    return Directionality(
      textDirection: direction,
      child: Column(
        children: [
          // TabBar only (no AppBar - AdminScaffold has it)
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 4,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.inventory), text: 'Catalog'),
                Tab(icon: Icon(Icons.local_shipping), text: 'Distributor'),
                Tab(icon: Icon(Icons.menu_book), text: 'Books'),
                Tab(icon: Icon(Icons.school), text: 'Courses'),
                Tab(icon: Icon(Icons.work), text: 'Jobs'),
                Tab(icon: Icon(Icons.medical_services), text: 'Vet Supplies'),
                Tab(icon: Icon(Icons.local_offer), text: 'Offers'),
                Tab(icon: Icon(Icons.healing), text: 'Surgical Tools'),
                Tab(icon: Icon(Icons.qr_code_scanner), text: 'OCR Products'),
              ],
            ),
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
          controller: _tabController,
          children: const [
            _CatalogProductsTab(),
            _DistributorProductsTab(),
            _BooksTab(),
            _CoursesTab(),
            _JobsTab(),
            _VetSuppliesTab(),
            _OffersTab(),
            _SurgicalToolsTab(),
            _OcrProductsTab(),
          ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Catalog Products Tab (products without distributor_id)
// ===================================================================
class _CatalogProductsTab extends ConsumerStatefulWidget {
  const _CatalogProductsTab();

  @override
  ConsumerState<_CatalogProductsTab> createState() => _CatalogProductsTabState();
}

class _CatalogProductsTabState extends ConsumerState<_CatalogProductsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(adminAllProductsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (products) {
        // Filter catalog products (no distributor_id)
        var catalogProducts = products.where((p) => 
          p.distributorId == null || p.distributorId!.isEmpty
        ).toList();

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          catalogProducts = catalogProducts.where((p) {
            final query = _searchQuery.toLowerCase();
            return p.name.toLowerCase().contains(query) ||
                   (p.company?.toLowerCase().contains(query) ?? false) ||
                   (p.activePrinciple?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, company, or active principle...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            if (catalogProducts.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No products found' : 'No catalog products found'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      header: Text('Catalog Products (${catalogProducts.length})'),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('Company')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _CatalogProductDataSource(catalogProducts, context, ref),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===================================================================
// Distributor Products Tab (products with distributor_id - excluding OCR)
// ===================================================================
class _DistributorProductsTab extends ConsumerStatefulWidget {
  const _DistributorProductsTab();

  @override
  ConsumerState<_DistributorProductsTab> createState() => _DistributorProductsTabState();
}

class _DistributorProductsTabState extends ConsumerState<_DistributorProductsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(adminOnlyDistributorProductsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (products) {
        var distributorProducts = products;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          distributorProducts = distributorProducts.where((p) {
            final query = _searchQuery.toLowerCase();
            return p.name.toLowerCase().contains(query) ||
                   (p.distributorId?.toLowerCase().contains(query) ?? false) ||
                   (p.company?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, distributor, or company...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (distributorProducts.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.local_shipping, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No products found' : 'No distributor products found'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      header: Text('Distributor Products (${distributorProducts.length})'),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Distributor')),
                        DataColumn(label: Text('Package')),
                        DataColumn(label: Text('Price (EGP)')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _DistributorProductDataSource(distributorProducts, context, ref),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===================================================================
// Catalog Product Data Source
// ===================================================================
class _CatalogProductDataSource extends DataTableSource {
  _CatalogProductDataSource(this.products, this.context, this.ref);

  final List<ProductModel> products;
  final BuildContext context;
  final WidgetRef ref;

  @override
  DataRow? getRow(int index) {
    if (index >= products.length) return null;
    
    final product = products[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        // Image
        DataCell(_buildProductImage(product.imageUrl, product)),
        // Name
        DataCell(
          SizedBox(
            width: 250,
            child: Text(
              product.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),
        // Category
        DataCell(Text(product.action ?? 'N/A')),
        // Company
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              product.company ?? 'N/A',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'View Details',
                onPressed: () => _showProductDetails(product),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                tooltip: 'Edit',
                onPressed: () => _showCatalogEditDialog(product),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => _confirmCatalogDelete(product),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _showCatalogEditDialog(ProductModel product) {
    final nameController = TextEditingController(text: product.name);
    final companyController = TextEditingController(text: product.company);
    final activePrincipleController = TextEditingController(text: product.activePrinciple ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Catalog Product'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: activePrincipleController,
                  decoration: const InputDecoration(labelText: 'Active Principle (Optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final company = companyController.text.trim();
              final activePrinciple = activePrincipleController.text.trim();

              if (name.isEmpty || company.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill Name and Company')),
                );
                return;
              }

              try {
                Navigator.pop(context);
                final success = await ref.read(productRepositoryProvider).adminUpdateProduct(
                  id: product.id,
                  name: name,
                  company: company,
                  activePrinciple: activePrinciple.isEmpty ? null : activePrinciple,
                );

                if (success) {
                  ref.invalidate(adminAllProductsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Product updated successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _confirmCatalogDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?\n\nThis will permanently remove it from the catalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                final success = await ref.read(productRepositoryProvider).adminDeleteProduct(product.id);

                if (success) {
                  ref.invalidate(adminAllProductsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Product deleted successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Delete failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String imageUrl, ProductModel product) {
    final Widget imageWidget = imageUrl.isEmpty
        ? Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.inventory_2, size: 24, color: Colors.grey),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
              ),
            ),
          );
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showProductDetailsDialog(product),
        child: imageWidget,
      ),
    );
  }

  void _showProductDetailsDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.imageUrl.isNotEmpty)
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 16),
                _buildDetailRow('Product ID', product.id),
                _buildDetailRow('Name', product.name),
                _buildDetailRow('Category', product.action ?? 'N/A'),
                _buildDetailRow('Company', product.company ?? 'N/A'),
                _buildDetailRow('Distributor', 'N/A (Catalog Product)'),
                _buildDetailRow(
                  'Available Packages',
                  product.availablePackages.isNotEmpty 
                      ? product.availablePackages.join(', ') 
                      : 'N/A',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.imageUrl.isNotEmpty)
                Center(
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('Name', product.name),
              _buildDetailRow('Category', product.action ?? 'N/A'),
              _buildDetailRow('Company', product.company ?? 'N/A'),
              _buildDetailRow(
                'Packages',
                product.availablePackages.isNotEmpty 
                    ? product.availablePackages.join(', ') 
                    : 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => products.length;

  @override
  int get selectedRowCount => 0;
}

// ===================================================================
// Distributor Product Data Source
// ===================================================================
class _DistributorProductDataSource extends DataTableSource {
  _DistributorProductDataSource(this.products, this.context, this.ref);

  final List<ProductModel> products;
  final BuildContext context;
  final WidgetRef ref;

  @override
  DataRow? getRow(int index) {
    if (index >= products.length) return null;
    
    final product = products[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        // Image
        DataCell(_buildProductImage(product.imageUrl, product)),
        // Name
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              product.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),
        // Distributor ID
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              product.distributorId ?? 'N/A',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        // Package
        DataCell(Text(product.selectedPackage ?? 'N/A')),
        // Price
        DataCell(Text(product.price?.toStringAsFixed(2) ?? 'N/A')),
        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'View Details',
                onPressed: () => _showProductDetails(product),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                tooltip: 'Edit Price',
                onPressed: () => _showEditPriceDialog(product),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => _confirmDistributorDelete(product),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _confirmDistributorDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Distributor Product'),
        content: Text('Are you sure you want to delete "${product.name}" from distributor "${product.distributorId}"?\n\nPackage: ${product.selectedPackage}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                final success = await ref.read(productRepositoryProvider).adminDeleteDistributorProduct(
                  distributorId: product.distributorId!,
                  productId: product.id,
                  package: product.selectedPackage ?? '',
                );

                if (success) {
                  ref.invalidate(adminAllProductsProvider);
                  ref.invalidate(adminOnlyDistributorProductsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Product deleted successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Delete failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String imageUrl, ProductModel product) {
    final Widget imageWidget = imageUrl.isEmpty
        ? Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.inventory_2, size: 24, color: Colors.grey),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
              ),
            ),
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showProductDetailsDialog(product),
        child: imageWidget,
      ),
    );
  }

  void _showProductDetailsDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.imageUrl.isNotEmpty)
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 16),
                _buildDetailRow('Product ID', product.id),
                _buildDetailRow('Name', product.name),
                _buildDetailRow('Distributor', product.distributorId ?? 'N/A'),
                _buildDetailRow('Package', product.selectedPackage ?? 'N/A'),
                _buildDetailRow('Price', '${product.price?.toStringAsFixed(2) ?? 'N/A'} EGP'),
                _buildDetailRow('Category', product.action ?? 'N/A'),
                _buildDetailRow('Company', product.company ?? 'N/A'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.imageUrl.isNotEmpty)
                Center(
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('Name', product.name),
              _buildDetailRow('Distributor', product.distributorId ?? 'N/A'),
              _buildDetailRow('Package', product.selectedPackage ?? 'N/A'),
              _buildDetailRow('Price', '${product.price?.toStringAsFixed(2) ?? 'N/A'} EGP'),
              _buildDetailRow('Category', product.action ?? 'N/A'),
              _buildDetailRow('Company', product.company ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditPriceDialog(ProductModel product) {
    final priceController = TextEditingController(
      text: product.price?.toStringAsFixed(2) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${product.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price (EGP)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement price update
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Price update coming soon')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => products.length;

  @override
  int get selectedRowCount => 0;
}
// ===================================================================
// Books Tab
// ===================================================================
class _BooksTab extends ConsumerStatefulWidget {
  const _BooksTab();
  @override
  ConsumerState<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends ConsumerState<_BooksTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(adminAllBooksProvider);
    return booksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allBooks) {
        var books = allBooks;
        if (_searchQuery.isNotEmpty) {
          books = books.where((b) {
            final q = _searchQuery.toLowerCase();
            return b.name.toLowerCase().contains(q) ||
                   b.author.toLowerCase().contains(q) ||
                   b.phone.toLowerCase().contains(q);
          }).toList();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, author, or phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (books.isEmpty)
              Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.menu_book, size: 64, color: Colors.grey), const SizedBox(height: 16), Text(_searchQuery.isNotEmpty ? 'No books found' : 'No books found')])))
            else
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: SizedBox(width: double.infinity, child: PaginatedDataTable(header: Text('Books (${books.length})'), rowsPerPage: 10, columns: const [DataColumn(label: Text('Image')), DataColumn(label: Text('Name')), DataColumn(label: Text('Author')), DataColumn(label: Text('Price')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Actions'))], source: _BooksDataSource(books, context, ref))))),
          ],
        );
      },
    );
  }
}

class _BooksDataSource extends DataTableSource {
  _BooksDataSource(this.books, this.context, this.ref);
  final List<Book> books;
  final BuildContext context;
  final WidgetRef ref;
  @override
  DataRow? getRow(int index) {
    if (index >= books.length) return null;
    final book = books[index];
    return DataRow.byIndex(index: index, cells: [DataCell(_buildImage(book.imageUrl, book)), DataCell(SizedBox(width: 200, child: Text(book.name, overflow: TextOverflow.ellipsis, maxLines: 2))), DataCell(Text(book.author)), DataCell(Text(book.price.toStringAsFixed(2))), DataCell(Text(book.phone)), DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(book)), IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(book)), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(book))]))]);
  }
  
  void _showEditDialog(Book book) {
    final nameController = TextEditingController(text: book.name);
    final authorController = TextEditingController(text: book.author);
    final priceController = TextEditingController(text: book.price.toString());
    final phoneController = TextEditingController(text: book.phone);
    final descController = TextEditingController(text: book.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Book'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: authorController, decoration: const InputDecoration(labelText: 'Author')),
                const SizedBox(height: 8),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (EGP)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final author = authorController.text.trim();
              final priceText = priceController.text.trim();
              final phone = phoneController.text.trim();
              final desc = descController.text.trim();
              
              if (name.isEmpty || author.isEmpty || priceText.isEmpty || phone.isEmpty || desc.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                return;
              }
              
              final price = double.tryParse(priceText);
              if (price == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid price')));
                return;
              }
              
              try {
                Navigator.pop(context);
                final success = await ref.read(booksRepositoryProvider).adminUpdateBook(
                  bookId: book.id,
                  name: name,
                  author: author,
                  price: price,
                  phone: phone,
                  description: desc,
                );
                
                if (success) {
                  ref.invalidate(adminAllBooksProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Updated successfully'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImage(String url, Book book) {
    final Widget imageWidget = url.isEmpty
        ? Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.menu_book, size: 24))
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
            ),
          );
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDetailsDialog(book),
        child: imageWidget,
      ),
    );
  }

  void _showDetailsDialog(Book book) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Book Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (book.imageUrl.isNotEmpty)
                  Center(child: CachedNetworkImage(imageUrl: book.imageUrl, width: 250, height: 250, fit: BoxFit.contain)),
                const SizedBox(height: 16),
                _buildDetailRow('Book ID', book.id),
                _buildDetailRow('Name', book.name),
                _buildDetailRow('Author', book.author),
                _buildDetailRow('Price', '${book.price.toStringAsFixed(2)} EGP'),
                _buildDetailRow('Phone', book.phone),
                _buildDetailRow('Distributor', 'N/A'),
                const SizedBox(height: 8),
                Text('Description:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(book.description),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showDetails(Book book) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Book Details'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [if (book.imageUrl.isNotEmpty) Center(child: CachedNetworkImage(imageUrl: book.imageUrl, width: 200, height: 200)), const SizedBox(height: 16), Text('Name: ${book.name}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('Author: ${book.author}'), Text('Price: ${book.price.toStringAsFixed(2)} EGP'), Text('Phone: ${book.phone}'), Text('Description: ${book.description}')])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
  }
  void _confirmDelete(Book book) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Delete Book'), content: Text('Are you sure you want to delete "${book.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () async { Navigator.pop(context); await ref.read(booksRepositoryProvider).adminDeleteBook(book.id); ref.invalidate(adminAllBooksProvider); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
  }
  @override bool get isRowCountApproximate => false;
  @override int get rowCount => books.length;
  @override int get selectedRowCount => 0;
}

// ===================================================================
// Courses Tab  
// ===================================================================
class _CoursesTab extends ConsumerStatefulWidget {
  const _CoursesTab();
  @override
  ConsumerState<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends ConsumerState<_CoursesTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(adminAllCoursesProvider);
    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allCourses) {
        var courses = allCourses;
        if (_searchQuery.isNotEmpty) {
          courses = courses.where((c) {
            final q = _searchQuery.toLowerCase();
            return c.title.toLowerCase().contains(q) ||
                   c.phone.toLowerCase().contains(q) ||
                   c.description.toLowerCase().contains(q);
          }).toList();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by title, phone, or description...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (courses.isEmpty)
              Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.school, size: 64, color: Colors.grey), const SizedBox(height: 16), Text(_searchQuery.isNotEmpty ? 'No courses found' : 'No courses found')])))
            else
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: SizedBox(width: double.infinity, child: PaginatedDataTable(header: Text('Courses (${courses.length})'), rowsPerPage: 10, columns: const [DataColumn(label: Text('Image')), DataColumn(label: Text('Title')), DataColumn(label: Text('Price')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Actions'))], source: _CoursesDataSource(courses, context, ref))))),
          ],
        );
      },
    );
  }
}

class _CoursesDataSource extends DataTableSource {
  _CoursesDataSource(this.courses, this.context, this.ref);
  final List<Course> courses;
  final BuildContext context;
  final WidgetRef ref;
  @override
  DataRow? getRow(int index) {
    if (index >= courses.length) return null;
    final course = courses[index];
    return DataRow.byIndex(index: index, cells: [DataCell(_buildImage(course.imageUrl, course)), DataCell(SizedBox(width: 250, child: Text(course.title, overflow: TextOverflow.ellipsis, maxLines: 2))), DataCell(Text(course.price.toStringAsFixed(2))), DataCell(Text(course.phone)), DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(course)), IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(course)), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(course))]))]);
  }
  
  void _showEditDialog(Course course) {
    final titleController = TextEditingController(text: course.title);
    final priceController = TextEditingController(text: course.price.toString());
    final phoneController = TextEditingController(text: course.phone);
    final descController = TextEditingController(text: course.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Course'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (EGP)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final priceText = priceController.text.trim();
              final phone = phoneController.text.trim();
              final desc = descController.text.trim();
              
              if (title.isEmpty || priceText.isEmpty || phone.isEmpty || desc.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                return;
              }
              
              final price = double.tryParse(priceText);
              if (price == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid price')));
                return;
              }
              
              try {
                Navigator.pop(context);
                final success = await ref.read(coursesRepositoryProvider).adminUpdateCourse(
                  courseId: course.id,
                  title: title,
                  price: price,
                  phone: phone,
                  description: desc,
                );
                
                if (success) {
                  ref.invalidate(adminAllCoursesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Updated successfully'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImage(String url, Course course) {
    final Widget imageWidget = url.isEmpty
        ? Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.school, size: 24))
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
            ),
          );
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDetailsDialog(course),
        child: imageWidget,
      ),
    );
  }

  void _showDetailsDialog(Course course) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Course Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (course.imageUrl.isNotEmpty)
                  Center(child: CachedNetworkImage(imageUrl: course.imageUrl, width: 250, height: 250, fit: BoxFit.contain)),
                const SizedBox(height: 16),
                _buildDetailRow('Course ID', course.id),
                _buildDetailRow('Title', course.title),
                _buildDetailRow('Price', '${course.price.toStringAsFixed(2)} EGP'),
                _buildDetailRow('Phone', course.phone),
                _buildDetailRow('Distributor', 'N/A'),
                const SizedBox(height: 8),
                Text('Description:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(course.description),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showDetails(Course course) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Course Details'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [if (course.imageUrl.isNotEmpty) Center(child: CachedNetworkImage(imageUrl: course.imageUrl, width: 200, height: 200)), const SizedBox(height: 16), Text('Title: ${course.title}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('Price: ${course.price.toStringAsFixed(2)} EGP'), Text('Phone: ${course.phone}'), Text('Description: ${course.description}')])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
  }
  void _confirmDelete(Course course) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Delete Course'), content: Text('Are you sure you want to delete "${course.title}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () async { Navigator.pop(context); await ref.read(coursesRepositoryProvider).adminDeleteCourse(course.id); ref.invalidate(adminAllCoursesProvider); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
  }
  @override bool get isRowCountApproximate => false;
  @override int get rowCount => courses.length;
  @override int get selectedRowCount => 0;
}

// ===================================================================
// Jobs Tab
// ===================================================================
class _JobsTab extends ConsumerStatefulWidget {
  const _JobsTab();
  @override
  ConsumerState<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends ConsumerState<_JobsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(adminAllJobOffersProvider);
    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allJobs) {
        var jobs = allJobs;
        if (_searchQuery.isNotEmpty) {
          jobs = jobs.where((j) {
            final q = _searchQuery.toLowerCase();
            return j.title.toLowerCase().contains(q) ||
                   j.phone.toLowerCase().contains(q) ||
                   j.description.toLowerCase().contains(q);
          }).toList();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by title, phone, or description...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (jobs.isEmpty)
              Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.work, size: 64, color: Colors.grey), const SizedBox(height: 16), Text(_searchQuery.isNotEmpty ? 'No jobs found' : 'No jobs found')])))
            else
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: SizedBox(width: double.infinity, child: PaginatedDataTable(header: Text('Job Offers (${jobs.length})'), rowsPerPage: 10, columns: const [DataColumn(label: Text('Title')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Status')), DataColumn(label: Text('Views')), DataColumn(label: Text('Actions'))], source: _JobsDataSource(jobs, context, ref))))),
          ],
        );
      },
    );
  }
}

class _JobsDataSource extends DataTableSource {
  _JobsDataSource(this.jobs, this.context, this.ref);
  final List<JobOffer> jobs;
  final BuildContext context;
  final WidgetRef ref;
  @override
  DataRow? getRow(int index) {
    if (index >= jobs.length) return null;
    final job = jobs[index];
    return DataRow.byIndex(index: index, cells: [DataCell(SizedBox(width: 300, child: Text(job.title, overflow: TextOverflow.ellipsis, maxLines: 2))), DataCell(Text(job.phone)), DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (job.status == 'closed' ? Colors.red.shade100 : Colors.green.shade100), borderRadius: BorderRadius.circular(4)), child: Text((job.status == 'closed' ? 'Closed' : 'Open'), style: TextStyle(color: (job.status == 'closed' ? Colors.red.shade900 : Colors.green.shade900), fontWeight: FontWeight.bold)))), DataCell(Text(job.viewsCount.toString())), DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(job)), IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(job)), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(job))]))]);
  }
  
  void _showEditDialog(JobOffer job) {
    final titleController = TextEditingController(text: job.title);
    final phoneController = TextEditingController(text: job.phone);
    final descController = TextEditingController(text: job.description);
    final addressController = TextEditingController(text: job.workplaceAddress);
    String selectedStatus = job.status;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Job Offer'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title'), maxLines: 2),
                  const SizedBox(height: 8),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 8),
                  TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Workplace Address')),
                  const SizedBox(height: 8),
                  TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 4),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Open')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final phone = phoneController.text.trim();
                final desc = descController.text.trim();
                final address = addressController.text.trim();
                
                if (title.isEmpty || phone.isEmpty || desc.isEmpty || address.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                
                try {
                  Navigator.pop(context);
                  final success = await ref.read(jobOffersRepositoryProvider).adminUpdateJobOffer(
                    jobId: job.id,
                    title: title,
                    phone: phone,
                    description: desc,
                    workplaceAddress: address,
                    status: selectedStatus,
                  );
                  
                  if (success) {
                    ref.invalidate(adminAllJobOffersProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Updated successfully'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDetails(JobOffer job) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Job Details'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Title: ${job.title}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Phone: ${job.phone}'), Text('Views: ${0}'), Text('Status: ${(job.status == "closed" ? "Closed" : "Open")}'), const SizedBox(height: 8), Text('Description: ${job.description}')])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
  }
  void _confirmDelete(JobOffer job) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Delete Job'), content: Text('Are you sure you want to delete "${job.title}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () async { Navigator.pop(context); await ref.read(jobOffersRepositoryProvider).adminDeleteJobOffer(job.id); ref.invalidate(adminAllJobOffersProvider); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
  }
  @override bool get isRowCountApproximate => false;
  @override int get rowCount => jobs.length;
  @override int get selectedRowCount => 0;
}

// ===================================================================
// Vet Supplies Tab
// ===================================================================
class _VetSuppliesTab extends ConsumerStatefulWidget {
  const _VetSuppliesTab();

  @override
  ConsumerState<_VetSuppliesTab> createState() => _VetSuppliesTabState();
}

class _VetSuppliesTabState extends ConsumerState<_VetSuppliesTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final suppliesAsync = ref.watch(adminAllVetSuppliesProvider);

    return suppliesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allSupplies) {
        var supplies = allSupplies;
        if (_searchQuery.isNotEmpty) {
          supplies = supplies.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.name.toLowerCase().contains(q) ||
                   s.phone.toLowerCase().contains(q) ||
                   s.description.toLowerCase().contains(q);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, or description...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (supplies.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.medical_services, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No vet supplies found' : 'No vet supplies found'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      header: Text('Vet Supplies (${supplies.length})'),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Price (EGP)')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Views')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _VetSuppliesDataSource(supplies, context, ref),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VetSuppliesDataSource extends DataTableSource {
  _VetSuppliesDataSource(this.supplies, this.context, this.ref);
  final List<VetSupply> supplies;
  final BuildContext context;
  final WidgetRef ref;

  @override
  DataRow? getRow(int index) {
    if (index >= supplies.length) return null;
    final supply = supplies[index];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(_buildImage(supply.imageUrl, supply)),
        DataCell(SizedBox(width: 200, child: Text(supply.name, overflow: TextOverflow.ellipsis, maxLines: 2))),
        DataCell(Text(supply.price.toStringAsFixed(2))),
        DataCell(Text(supply.phone)),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(supply.status),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(supply.status, style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
        DataCell(Text(supply.viewsCount.toString())),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: 'View',
              onPressed: () => _showDetails(supply),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              tooltip: 'Edit',
              onPressed: () => _showEditDialog(supply),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(supply),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildImage(String url, VetSupply supply) {
    final Widget imageWidget = url.isEmpty
        ? Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.medical_services, size: 24))
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
            ),
          );
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDetailsDialog(supply),
        child: imageWidget,
      ),
    );
  }

  void _showDetailsDialog(VetSupply supply) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vet Supply Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (supply.imageUrl.isNotEmpty)
                  Center(child: CachedNetworkImage(imageUrl: supply.imageUrl, width: 250, height: 250, fit: BoxFit.contain)),
                const SizedBox(height: 16),
                _buildDetailRow('Supply ID', supply.id),
                _buildDetailRow('Name', supply.name),
                _buildDetailRow('Price', '${supply.price.toStringAsFixed(2)} EGP'),
                _buildDetailRow('Phone', supply.phone),
                _buildDetailRow('Status', supply.status),
                _buildDetailRow('Views', supply.viewsCount.toString()),
                _buildDetailRow('Distributor', 'N/A'),
                const SizedBox(height: 8),
                Text('Description:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(supply.description),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade100;
      case 'sold':
        return Colors.blue.shade100;
      case 'inactive':
        return Colors.grey.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  void _showDetails(VetSupply supply) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vet Supply Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (supply.imageUrl.isNotEmpty)
                Center(child: CachedNetworkImage(imageUrl: supply.imageUrl, width: 200, height: 200)),
              const SizedBox(height: 16),
              Text('Name: ${supply.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Price: ${supply.price.toStringAsFixed(2)} EGP'),
              Text('Phone: ${supply.phone}'),
              Text('Status: ${supply.status}'),
              Text('Views: ${supply.viewsCount}'),
              const SizedBox(height: 8),
              Text('Description: ${supply.description}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(VetSupply supply) {
    final nameController = TextEditingController(text: supply.name);
    final descController = TextEditingController(text: supply.description);
    final priceController = TextEditingController(text: supply.price.toString());
    final phoneController = TextEditingController(text: supply.phone);
    String selectedStatus = supply.status;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Vet Supply'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (EGP)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'sold', child: Text('Sold')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                final priceText = priceController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty || desc.isEmpty || priceText.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final price = double.tryParse(priceText);
                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid price')),
                  );
                  return;
                }

                try {
                  Navigator.pop(context);
                  final success = await ref.read(vetSuppliesRepositoryProvider).adminUpdateVetSupply(
                    id: supply.id,
                    name: name,
                    description: desc,
                    price: price,
                    phone: phone,
                    status: selectedStatus,
                  );
                  
                  if (success) {
                    ref.invalidate(adminAllVetSuppliesProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Updated successfully'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(VetSupply supply) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Vet Supply'),
        content: Text('Are you sure you want to delete "${supply.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                final success = await ref.read(vetSuppliesRepositoryProvider).adminDeleteVetSupply(supply.id);
                
                if (success) {
                  ref.invalidate(adminAllVetSuppliesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Deleted successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Delete failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => supplies.length;

  @override
  int get selectedRowCount => 0;
}

// ===================================================================
// Offers Tab
// ===================================================================
class _OffersTab extends ConsumerStatefulWidget {
  const _OffersTab();

  @override
  ConsumerState<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends ConsumerState<_OffersTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(adminAllOffersProvider);

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allOffers) {
        var offers = allOffers;
        if (_searchQuery.isNotEmpty) {
          offers = offers.where((o) {
            final q = _searchQuery.toLowerCase();
            return o.productId.toLowerCase().contains(q);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by product ID...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (offers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.local_offer, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No offers found' : 'No offers found'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      header: Text('Offers (${offers.length})'),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Product ID')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Price (EGP)')),
                        DataColumn(label: Text('Package')),
                        DataColumn(label: Text('Expiration')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _OffersDataSource(offers, context, ref),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OffersDataSource extends DataTableSource {
  _OffersDataSource(this.offers, this.context, this.ref);
  final List<Offer> offers;
  final BuildContext context;
  final WidgetRef ref;

  @override
  DataRow? getRow(int index) {
    if (index >= offers.length) return null;
    final offer = offers[index];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(_buildImage(offer.imageUrl ?? '', offer)),
        DataCell(SizedBox(width: 150, child: Text(offer.productId, overflow: TextOverflow.ellipsis))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: offer.isOcr ? Colors.purple.shade100 : Colors.blue.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(offer.isOcr ? 'OCR' : 'Catalog'),
        )),
        DataCell(Text(offer.price.toStringAsFixed(2))),
        DataCell(Text(offer.package ?? 'N/A')),
        DataCell(Text(DateFormat('yyyy-MM-dd').format(offer.expirationDate))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: offer.isExpired ? Colors.red.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(offer.isExpired ? 'Expired' : 'Active', style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: 'View',
              onPressed: () => _showDetails(offer),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              tooltip: 'Edit',
              onPressed: () => _showEditDialog(offer),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(offer),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildImage(String url, Offer offer) {
    final Widget imageWidget = url.isEmpty
        ? Container(
            width: 50,
            height: 50,
            color: Colors.grey[200],
            child: const Icon(Icons.local_offer, size: 24, color: Colors.grey),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
              ),
            ),
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDetailsDialog(offer),
        child: imageWidget,
      ),
    );
  }

  void _showDetailsDialog(Offer offer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Offer Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.imageUrl != null && offer.imageUrl!.isNotEmpty)
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: offer.imageUrl!,
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 16),
                _buildDetailRow('Offer ID', offer.id),
                _buildDetailRow('Product ID', offer.productId),
                _buildDetailRow('Type', offer.isOcr ? 'OCR' : 'Catalog'),
                _buildDetailRow('Price', '${offer.price.toStringAsFixed(2)} EGP'),
                _buildDetailRow('Package', offer.package ?? 'N/A'),
                _buildDetailRow('Expiration', DateFormat('yyyy-MM-dd').format(offer.expirationDate)),
                _buildDetailRow('Status', offer.isExpired ? 'Expired' : 'Active'),
                if (offer.description != null && offer.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Description:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(offer.description!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEditDialog(Offer offer) {
    final priceController = TextEditingController(text: offer.price.toString());
    final descController = TextEditingController(text: offer.description ?? '');
    final packageController = TextEditingController(text: offer.package ?? '');
    DateTime selectedDate = offer.expirationDate;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Offer'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Product ID: ${offer.productId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (EGP)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: packageController,
                    decoration: const InputDecoration(labelText: 'Package'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Expiration Date:'),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final priceText = priceController.text.trim();
                final price = double.tryParse(priceText);
                if (price == null) return;

                Navigator.pop(context);
                await ref.read(offersRepositoryProvider).adminUpdateOffer(
                  id: offer.id,
                  price: price,
                  expirationDate: selectedDate,
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  package: packageController.text.trim().isEmpty ? null : packageController.text.trim(),
                );
                ref.invalidate(adminAllOffersProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(Offer offer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Offer Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product ID: ${offer.productId}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Type: ${offer.isOcr ? "OCR" : "Catalog"}'),
              Text('Price: ${offer.price.toStringAsFixed(2)} EGP'),
              Text('Package: ${offer.package ?? "N/A"}'),
              Text('Expiration: ${DateFormat('yyyy-MM-dd HH:mm').format(offer.expirationDate)}'),
              Text('Status: ${offer.isExpired ? "Expired" : "Active"}'),
              const SizedBox(height: 8),
              if (offer.description != null && offer.description!.isNotEmpty)
                Text('Description: ${offer.description}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Offer offer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Offer'),
        content: Text('Are you sure you want to delete this offer for product "${offer.productId}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(offersRepositoryProvider).adminDeleteOffer(offer.id);
              ref.invalidate(adminAllOffersProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => offers.length;

  @override
  int get selectedRowCount => 0;
}

// ===================================================================
// Surgical Tools Tab
// ===================================================================
class _SurgicalToolsTab extends ConsumerStatefulWidget {
  const _SurgicalToolsTab();

  @override
  ConsumerState<_SurgicalToolsTab> createState() => _SurgicalToolsTabState();
}

class _SurgicalToolsTabState extends ConsumerState<_SurgicalToolsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final toolsAsync = ref.watch(adminAllDistributorSurgicalToolsProvider);

    return toolsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allTools) {
        var tools = allTools;
        if (_searchQuery.isNotEmpty) {
          tools = tools.where((t) {
            final q = _searchQuery.toLowerCase();
            return (t.toolName ?? '').toLowerCase().contains(q) ||
                   (t.company ?? '').toLowerCase().contains(q) ||
                   t.distributorName.toLowerCase().contains(q);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by tool name, company, or distributor...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (tools.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.healing, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No surgical tools found' : 'No surgical tools found'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      header: Text('Distributor Surgical Tools (${tools.length})'),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Tool Name')),
                        DataColumn(label: Text('Company')),
                        DataColumn(label: Text('Distributor')),
                        DataColumn(label: Text('Price (EGP)')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _SurgicalToolsDataSource(tools, context, ref),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SurgicalToolsDataSource extends DataTableSource {
  _SurgicalToolsDataSource(this.tools, this.context, this.ref);
  final List<DistributorSurgicalTool> tools;
  final BuildContext context;
  final WidgetRef ref;

  @override
  DataRow? getRow(int index) {
    if (index >= tools.length) return null;
    final tool = tools[index];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(_buildImage(tool.imageUrl ?? '', tool)),
        DataCell(SizedBox(width: 150, child: Text(tool.toolName ?? 'N/A', overflow: TextOverflow.ellipsis, maxLines: 2))),
        DataCell(Text(tool.company ?? 'N/A')),
        DataCell(SizedBox(width: 120, child: Text(tool.distributorName, overflow: TextOverflow.ellipsis))),
        DataCell(Text(tool.price.toStringAsFixed(2))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: 'View',
              onPressed: () => _showDetails(tool),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              tooltip: 'Edit',
              onPressed: () => _showEditDialog(tool),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(tool),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildImage(String url, DistributorSurgicalTool tool) {
    final Widget imageWidget = url.isEmpty
        ? Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.healing, size: 24))
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
            ),
          );
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDetailsDialog(tool),
        child: imageWidget,
      ),
    );
  }

  void _showDetailsDialog(DistributorSurgicalTool tool) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Surgical Tool Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tool.imageUrl != null && tool.imageUrl!.isNotEmpty)
                  Center(child: CachedNetworkImage(imageUrl: tool.imageUrl!, width: 250, height: 250, fit: BoxFit.contain)),
                const SizedBox(height: 16),
                _buildDetailRow('Tool ID', tool.id),
                _buildDetailRow('Tool Name', tool.toolName ?? 'N/A'),
                _buildDetailRow('Company', tool.company ?? 'N/A'),
                _buildDetailRow('Distributor', tool.distributorName),
                _buildDetailRow('Price', '${tool.price.toStringAsFixed(2)} EGP'),
                const SizedBox(height: 8),
                Text('Description:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(tool.description),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEditDialog(DistributorSurgicalTool tool) {
    final descController = TextEditingController(text: tool.description);
    final priceController = TextEditingController(text: tool.price.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Surgical Tool'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tool: ${tool.toolName ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Company: ${tool.company ?? "N/A"}'),
                Text('Distributor: ${tool.distributorName}'),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price (EGP)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final desc = descController.text.trim();
              final priceText = priceController.text.trim();
              final price = double.tryParse(priceText);
              if (desc.isEmpty || price == null) return;

              Navigator.pop(context);
              await ref.read(surgicalToolsRepositoryProvider).adminUpdateDistributorSurgicalTool(
                id: tool.id,
                description: desc,
                price: price,
              );
              ref.invalidate(adminAllDistributorSurgicalToolsProvider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDetails(DistributorSurgicalTool tool) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Surgical Tool Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tool.imageUrl != null && tool.imageUrl!.isNotEmpty)
                Center(child: CachedNetworkImage(imageUrl: tool.imageUrl!, width: 200, height: 200)),
              const SizedBox(height: 16),
              Text('Tool Name: ${tool.toolName ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Company: ${tool.company ?? "N/A"}'),
              Text('Distributor: ${tool.distributorName}'),
              Text('Price: ${tool.price.toStringAsFixed(2)} EGP'),
              const SizedBox(height: 8),
              Text('Description: ${tool.description}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DistributorSurgicalTool tool) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Surgical Tool'),
        content: Text('Are you sure you want to delete "${tool.toolName ?? "this tool"}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(surgicalToolsRepositoryProvider).adminDeleteDistributorSurgicalTool(tool.id);
              ref.invalidate(adminAllDistributorSurgicalToolsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => tools.length;

  @override
  int get selectedRowCount => 0;
}

// ===================================================================
// OCR Products Tab
// ===================================================================
class _OcrProductsTab extends ConsumerStatefulWidget {
  const _OcrProductsTab();

  @override
  ConsumerState<_OcrProductsTab> createState() => _OcrProductsTabState();
}

class _OcrProductsTabState extends ConsumerState<_OcrProductsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ocrProductsAsync = ref.watch(adminAllDistributorOcrProductsProvider);

    return ocrProductsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allOcrProducts) {
        var ocrProducts = allOcrProducts;
        if (_searchQuery.isNotEmpty) {
          ocrProducts = ocrProducts.where((p) {
            final q = _searchQuery.toLowerCase();
            return (p['ocr_product_id'] ?? '').toString().toLowerCase().contains(q) ||
                   (p['distributor_name'] ?? '').toString().toLowerCase().contains(q);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by OCR product ID or distributor...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (ocrProducts.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.qr_code_scanner, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No OCR products found' : 'No OCR products found'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: PaginatedDataTable(
                      header: Text('Distributor OCR Products (${ocrProducts.length})'),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('OCR Product ID')),
                        DataColumn(label: Text('Distributor')),
                        DataColumn(label: Text('Price (EGP)')),
                        DataColumn(label: Text('Old Price')),
                        DataColumn(label: Text('Expiration')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _OcrProductsDataSource(ocrProducts, context, ref),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OcrProductsDataSource extends DataTableSource {
  _OcrProductsDataSource(this.ocrProducts, this.context, this.ref);
  final List<Map<String, dynamic>> ocrProducts;
  final BuildContext context;
  final WidgetRef ref;

  @override
  DataRow? getRow(int index) {
    if (index >= ocrProducts.length) return null;
    final product = ocrProducts[index];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(_buildImage(product['image_url']?.toString() ?? '', product)),
        DataCell(SizedBox(width: 150, child: Text(product['ocr_product_id'] ?? 'N/A', overflow: TextOverflow.ellipsis))),
        DataCell(SizedBox(width: 120, child: Text(product['distributor_name'] ?? 'N/A', overflow: TextOverflow.ellipsis))),
        DataCell(Text(product['price']?.toStringAsFixed(2) ?? 'N/A')),
        DataCell(Text(product['old_price']?.toStringAsFixed(2) ?? 'N/A')),
        DataCell(Text(
          product['expiration_date'] != null
              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(product['expiration_date']))
              : 'N/A',
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: 'View',
              onPressed: () => _showDetails(product),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              tooltip: 'Edit',
              onPressed: () => _showEditDialog(product),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(product),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildImage(String url, Map<String, dynamic> product) {
    final Widget imageWidget = url.isEmpty
        ? Container(
            width: 50,
            height: 50,
            color: Colors.grey[200],
            child: const Icon(Icons.qr_code_scanner, size: 24, color: Colors.grey),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
              ),
            ),
          );
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDetailsDialog(product),
        child: imageWidget,
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('OCR Product Details'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product['image_url'] != null && product['image_url'].toString().isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: CachedNetworkImage(
                        imageUrl: product['image_url'],
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                _buildDetailRow('Product ID', product['ocr_product_id'] ?? 'N/A'),
                _buildDetailRow('OCR Product ID', product['ocr_product_id'] ?? 'N/A'),
                _buildDetailRow('Distributor', product['distributor_name'] ?? 'N/A'),
                _buildDetailRow('Price', product['price'] != null ? '${product['price'].toStringAsFixed(2)} EGP' : 'N/A'),
                _buildDetailRow('Old Price', product['old_price'] != null ? '${product['old_price'].toStringAsFixed(2)} EGP' : 'N/A'),
                if (product['expiration_date'] != null)
                  _buildDetailRow('Expiration', DateFormat('yyyy-MM-dd').format(DateTime.parse(product['expiration_date']))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> product) {
    final priceController = TextEditingController(text: product['price']?.toString() ?? '');
    DateTime? selectedDate = product['expiration_date'] != null 
        ? DateTime.parse(product['expiration_date']) 
        : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit OCR Product'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OCR Product ID: ${product['ocr_product_id']}', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Distributor: ${product['distributor_name'] ?? "N/A"}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (EGP)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Expiration Date:'),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Text(selectedDate != null 
                            ? DateFormat('yyyy-MM-dd').format(selectedDate!) 
                            : 'Select Date'),
                      ),
                      if (selectedDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            setState(() {
                              selectedDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final priceText = priceController.text.trim();
                final price = double.tryParse(priceText);
                if (price == null) return;

                Navigator.pop(context);
                await ref.read(productRepositoryProvider).adminUpdateDistributorOcrProduct(
                  id: product['id'],
                  price: price,
                  expirationDate: selectedDate,
                );
                ref.invalidate(adminAllDistributorOcrProductsProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('OCR Product Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product['image_url'] != null && product['image_url'].toString().isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: CachedNetworkImage(
                      imageUrl: product['image_url'],
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              Text('OCR Product ID: ${product['ocr_product_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Distributor: ${product['distributor_name'] ?? "N/A"}'),
              Text('Distributor ID: ${product['distributor_id']}'),
              Text('Price: ${product['price']?.toStringAsFixed(2) ?? "N/A"} EGP'),
              Text('Old Price: ${product['old_price']?.toStringAsFixed(2) ?? "N/A"} EGP'),
              if (product['price_updated_at'] != null)
                Text('Price Updated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(product['price_updated_at']))}'),
              if (product['expiration_date'] != null)
                Text('Expiration: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(product['expiration_date']))}'),
              Text('Created: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(product['created_at']))}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete OCR Product'),
        content: Text('Are you sure you want to delete this OCR product "${product['ocr_product_id']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(productRepositoryProvider).adminDeleteDistributorOcrProduct(product['id']);
              ref.invalidate(adminAllDistributorOcrProductsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => ocrProducts.length;

  @override
  int get selectedRowCount => 0;
}


