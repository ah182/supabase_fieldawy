import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class ProductSelectionDialog extends StatefulWidget {
  const ProductSelectionDialog({super.key});

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // Categorized products
  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _tools = [];
  List<Map<String, dynamic>> _supplies = [];
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _offers = [];

  // Filtered lists
  List<Map<String, dynamic>> _filteredMedicines = [];
  List<Map<String, dynamic>> _filteredTools = [];
  List<Map<String, dynamic>> _filteredSupplies = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  List<Map<String, dynamic>> _filteredOffers = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchAllProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllProducts() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      debugPrint('🔍 Fetching products for User ID: $userId');
      
      if (userId == null) return;
      final supabase = Supabase.instance.client;

      // TEST QUERY: Check if table has any data at all
      final testCount = await supabase.from('distributor_products').select('id').limit(1);
      debugPrint('🧪 Test Query (distributor_products): found ${testCount.length} items (unfiltered)');

      // 1. Medicines (Regular & OCR)
      final regFuture = supabase.from('distributor_products')
          .select('id, price, products(name, image_url)')
          .eq('distributor_id', userId);
      final ocrFuture = supabase.from('distributor_ocr_products')
          .select('id, price, ocr_products(product_name, image_url)')
          .eq('distributor_id', userId);

      // 2. Surgical Tools (Joined)
      final toolsFuture = supabase.from('distributor_surgical_tools')
          .select('id, price, surgical_tools(tool_name, image_url)')
          .eq('distributor_id', userId);

      // 3. Vet Supplies
      final suppliesFuture = supabase.from('vet_supplies')
          .select('id, price, name, image_url')
          .eq('user_id', userId); 

      // 4. Books
      final booksFuture = supabase.from('vet_books')
          .select('id, price, name, image_url') 
          .eq('user_id', userId);

      // 5. Courses
      final coursesFuture = supabase.from('vet_courses')
          .select('id, price, title, image_url')
          .eq('user_id', userId);

      // 6. Offers (Fetch IDs first to avoid Join error)
      final offersFuture = supabase.from('offers')
          .select('id, price, is_ocr, product_id')
          .eq('user_id', userId);

      final results = await Future.wait([
        regFuture, 
        ocrFuture, 
        toolsFuture, 
        suppliesFuture, 
        booksFuture, 
        coursesFuture,
        offersFuture
      ]);

      debugPrint('🔍 Debug Data Counts for User: $userId');
      debugPrint(' - Reg Meds: ${(results[0] as List).length}');
      debugPrint(' - OCR Meds: ${(results[1] as List).length}');
      debugPrint(' - Tools: ${(results[2] as List).length}');
      debugPrint(' - Supplies: ${(results[3] as List).length}');
      debugPrint(' - Books: ${(results[4] as List).length}');
      debugPrint(' - Courses: ${(results[5] as List).length}');
      debugPrint(' - Offers: ${(results[6] as List).length}');

      // Process Medicines
      final regData = results[0] as List;
      final ocrData = results[1] as List;
      for (var item in regData) {
        final p = item['products'] as Map<String, dynamic>?;
        if (p != null) {
          _medicines.add({
            'id': item['id'],
            'name': p['name'],
            'price': item['price'],
            'image_url': p['image_url'],
            'prefix': 'reg_'
          });
        }
      }
      for (var item in ocrData) {
        final p = item['ocr_products'] as Map<String, dynamic>?;
        if (p != null) {
          _medicines.add({
            'id': item['id'],
            'name': p['product_name'],
            'price': item['price'],
            'image_url': p['image_url'],
            'prefix': 'ocr_'
          });
        }
      }

      // Process Tools
      for (var item in results[2] as List) {
        final toolInfo = item['surgical_tools'] as Map<String, dynamic>?;
        if (toolInfo != null) {
          _tools.add({
            'id': item['id'],
            'name': toolInfo['tool_name'],
            'price': item['price'],
            'image_url': toolInfo['image_url'],
            'prefix': 'tool_'
          });
        }
      }

      // Process Supplies
      for (var item in results[3] as List) {
        _supplies.add({
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'image_url': item['image_url'],
          'prefix': 'supply_'
        });
      }

      // Process Books
      for (var item in results[4] as List) {
        _books.add({
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'image_url': item['image_url'],
          'prefix': 'book_'
        });
      }

      // Process Courses
      for (var item in results[5] as List) {
        _courses.add({
          'id': item['id'],
          'name': item['title'],
          'price': item['price'],
          'image_url': item['image_url'],
          'prefix': 'course_'
        });
      }

      // Process Offers (Manual Join)
      final offersData = results[6] as List;
      for (var item in offersData) {
        final isOcr = item['is_ocr'] as bool? ?? false;
        final productId = item['product_id'];
        String? name;
        String? imageUrl;

        try {
          if (isOcr) {
            final p = await supabase.from('ocr_products').select('product_name, image_url').eq('id', productId).maybeSingle();
            name = p?['product_name'];
            imageUrl = p?['image_url'];
          } else {
            final p = await supabase.from('products').select('name, image_url').eq('id', productId).maybeSingle();
            name = p?['name'];
            imageUrl = p?['image_url'];
          }
        } catch (e) {
          debugPrint('Error fetching offer details for $productId: $e');
        }

        if (name != null) {
          _offers.add({
            'id': item['id'],
            'name': name,
            'price': item['price'],
            'image_url': imageUrl,
            'prefix': 'offer_'
          });
        }
      }

      if (mounted) {
        setState(() {
          _filteredMedicines = _medicines;
          _filteredTools = _tools;
          _filteredSupplies = _supplies;
          _filteredBooks = _books;
          _filteredCourses = _courses;
          _filteredOffers = _offers;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('❌ Error fetching products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMedicines = _medicines;
        _filteredTools = _tools;
        _filteredSupplies = _supplies;
        _filteredBooks = _books;
        _filteredCourses = _courses;
        _filteredOffers = _offers;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredMedicines = _medicines.where((p) => p['name'].toString().toLowerCase().contains(lowerQuery)).toList();
        _filteredTools = _tools.where((p) => p['name'].toString().toLowerCase().contains(lowerQuery)).toList();
        _filteredSupplies = _supplies.where((p) => p['name'].toString().toLowerCase().contains(lowerQuery)).toList();
        _filteredBooks = _books.where((p) => p['name'].toString().toLowerCase().contains(lowerQuery)).toList();
        _filteredCourses = _courses.where((p) => p['name'].toString().toLowerCase().contains(lowerQuery)).toList();
        _filteredOffers = _offers.where((p) => p['name'].toString().toLowerCase().contains(lowerQuery)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = context.locale.languageCode == 'ar';

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr ? 'اختر منتجاً لربطه' : 'Select a Product to Link',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterProducts,
                decoration: InputDecoration(
                  hintText: isAr ? 'بحث...' : 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.colorScheme.primary,
              tabs: [
                Tab(text: isAr ? 'أدوية' : 'Medicines'),
                Tab(text: isAr ? 'أدوات' : 'Tools'),
                Tab(text: isAr ? 'مستلزمات' : 'Supplies'),
                Tab(text: isAr ? 'كتب' : 'Books'),
                Tab(text: isAr ? 'كورسات' : 'Courses'),
                Tab(text: isAr ? 'عروض' : 'Offers'),
              ],
            ),
            
            const SizedBox(height: 10),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProductList(_filteredMedicines),
                        _buildProductList(_filteredTools),
                        _buildProductList(_filteredSupplies),
                        _buildProductList(_filteredBooks),
                        _buildProductList(_filteredCourses),
                        _buildProductList(_filteredOffers),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'لا توجد عناصر',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = products[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: item['image_url'] != null && item['image_url'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item['image_url'],
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  )
                : const Icon(Icons.image, color: Colors.grey),
          ),
          title: Text(
            item['name'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item['price'] ?? 0} EGP',
            style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(8),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.pop(context, '${item['prefix']}${item['id']}');
            },
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        );
      },
    );
  }
}
