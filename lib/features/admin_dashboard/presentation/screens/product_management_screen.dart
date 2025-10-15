import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/books/application/books_provider.dart';
import 'package:fieldawy_store/features/books/domain/book_model.dart';
import 'package:fieldawy_store/features/courses/application/courses_provider.dart';
import 'package:fieldawy_store/features/courses/domain/course_model.dart';
import 'package:fieldawy_store/features/jobs/application/job_offers_provider.dart';
import 'package:fieldawy_store/features/jobs/domain/job_offer_model.dart';
import 'package:fieldawy_store/features/vet_supplies/application/vet_supplies_provider.dart';
import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:fieldawy_store/features/offers/application/offers_provider.dart';
import 'package:fieldawy_store/features/offers/domain/offer_model.dart';
import 'package:fieldawy_store/features/surgical_tools/application/surgical_tools_provider.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        bottom: TabBar(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(adminAllProductsProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
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
    );
  }
}

// ===================================================================
// Catalog Products Tab (products without distributor_id)
// ===================================================================
class _CatalogProductsTab extends ConsumerWidget {
  const _CatalogProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminAllProductsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (products) {
        // Filter catalog products (no distributor_id)
        final catalogProducts = products.where((p) => 
          p.distributorId == null || p.distributorId!.isEmpty
        ).toList();

        if (catalogProducts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No catalog products found'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
        );
      },
    );
  }
}

// ===================================================================
// Distributor Products Tab (products with distributor_id)
// ===================================================================
class _DistributorProductsTab extends ConsumerWidget {
  const _DistributorProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminAllProductsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      data: (products) {
        // Filter distributor products (has distributor_id)
        final distributorProducts = products.where((p) => 
          p.distributorId != null && p.distributorId!.isNotEmpty
        ).toList();

        if (distributorProducts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No distributor products found'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
        DataCell(_buildProductImage(product.imageUrl)),
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
          IconButton(
            icon: const Icon(Icons.visibility, size: 20),
            tooltip: 'View Details',
            onPressed: () => _showProductDetails(product),
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.inventory_2, size: 24, color: Colors.grey),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
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
        DataCell(_buildProductImage(product.imageUrl)),
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
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Edit Price',
                onPressed: () => _showEditPriceDialog(product),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.inventory_2, size: 24, color: Colors.grey),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
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
class _BooksTab extends ConsumerWidget {
  const _BooksTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(adminAllBooksProvider);
    return booksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (books) {
        if (books.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book, size: 64, color: Colors.grey), SizedBox(height: 16), Text('No books found')]));
        }
        return SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: PaginatedDataTable(header: Text('Books (${books.length})'), rowsPerPage: 10, columns: const [DataColumn(label: Text('Image')), DataColumn(label: Text('Name')), DataColumn(label: Text('Author')), DataColumn(label: Text('Price')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Actions'))], source: _BooksDataSource(books, context, ref))));
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
    return DataRow.byIndex(index: index, cells: [DataCell(_buildImage(book.imageUrl)), DataCell(SizedBox(width: 200, child: Text(book.name, overflow: TextOverflow.ellipsis, maxLines: 2))), DataCell(Text(book.author)), DataCell(Text(book.price.toStringAsFixed(2))), DataCell(Text(book.phone)), DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(book)), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(book))]))]);
  }
  Widget _buildImage(String url) {
    if (url.isEmpty) return Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.menu_book, size: 24));
    return ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: url, width: 50, height: 50, fit: BoxFit.cover, placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]), errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image))));
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
class _CoursesTab extends ConsumerWidget {
  const _CoursesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(adminAllCoursesProvider);
    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (courses) {
        if (courses.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.school, size: 64, color: Colors.grey), SizedBox(height: 16), Text('No courses found')]));
        }
        return SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: PaginatedDataTable(header: Text('Courses (${courses.length})'), rowsPerPage: 10, columns: const [DataColumn(label: Text('Image')), DataColumn(label: Text('Title')), DataColumn(label: Text('Price')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Actions'))], source: _CoursesDataSource(courses, context, ref))));
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
    return DataRow.byIndex(index: index, cells: [DataCell(_buildImage(course.imageUrl)), DataCell(SizedBox(width: 250, child: Text(course.title, overflow: TextOverflow.ellipsis, maxLines: 2))), DataCell(Text(course.price.toStringAsFixed(2))), DataCell(Text(course.phone)), DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(course)), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(course))]))]);
  }
  Widget _buildImage(String url) {
    if (url.isEmpty) return Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.school, size: 24));
    return ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: url, width: 50, height: 50, fit: BoxFit.cover, placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]), errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image))));
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
class _JobsTab extends ConsumerWidget {
  const _JobsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(adminAllJobOffersProvider);
    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (jobs) {
        if (jobs.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.work, size: 64, color: Colors.grey), SizedBox(height: 16), Text('No jobs found')]));
        }
        return SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: PaginatedDataTable(header: Text('Job Offers (${jobs.length})'), rowsPerPage: 10, columns: const [DataColumn(label: Text('Title')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Status')), DataColumn(label: Text('Views')), DataColumn(label: Text('Actions'))], source: _JobsDataSource(jobs, context, ref))));
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
    return DataRow.byIndex(index: index, cells: [DataCell(SizedBox(width: 300, child: Text(job.title, overflow: TextOverflow.ellipsis, maxLines: 2))), DataCell(Text(job.phone)), DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (job.status == 'closed' ? Colors.red.shade100 : Colors.green.shade100), borderRadius: BorderRadius.circular(4)), child: Text((job.status == 'closed' ? 'Closed' : 'Open'), style: TextStyle(color: (job.status == 'closed' ? Colors.red.shade900 : Colors.green.shade900), fontWeight: FontWeight.bold)))), DataCell(Text(job.viewsCount.toString())), DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(job)), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(job))]))]);
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
class _VetSuppliesTab extends ConsumerWidget {
  const _VetSuppliesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(adminAllVetSuppliesProvider);

    return suppliesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (supplies) {
        if (supplies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No vet supplies found'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
        DataCell(_buildImage(supply.imageUrl)),
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

  Widget _buildImage(String url) {
    if (url.isEmpty) {
      return Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.medical_services, size: 24));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]),
        errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
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
class _OffersTab extends ConsumerWidget {
  const _OffersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(adminAllOffersProvider);

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (offers) {
        if (offers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_offer, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No offers found'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: PaginatedDataTable(
              header: Text('Offers (${offers.length})'),
              rowsPerPage: 10,
              columns: const [
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
class _SurgicalToolsTab extends ConsumerWidget {
  const _SurgicalToolsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(adminAllDistributorSurgicalToolsProvider);

    return toolsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (tools) {
        if (tools.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.healing, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No surgical tools found'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
        DataCell(_buildImage(tool.imageUrl ?? '')),
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

  Widget _buildImage(String url) {
    if (url.isEmpty) {
      return Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.healing, size: 24));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 50, height: 50, color: Colors.grey[200]),
        errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
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
class _OcrProductsTab extends ConsumerWidget {
  const _OcrProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocrProductsAsync = ref.watch(adminAllDistributorOcrProductsProvider);

    return ocrProductsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (ocrProducts) {
        if (ocrProducts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No OCR products found'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: PaginatedDataTable(
              header: Text('Distributor OCR Products (${ocrProducts.length})'),
              rowsPerPage: 10,
              columns: const [
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
