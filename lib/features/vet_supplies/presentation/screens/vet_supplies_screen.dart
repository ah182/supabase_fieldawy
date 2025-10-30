import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/vet_supplies/application/vet_supplies_provider.dart';
import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
import 'package:fieldawy_store/features/vet_supplies/presentation/screens/add_vet_supply_screen.dart';
import 'package:fieldawy_store/features/vet_supplies/presentation/screens/edit_vet_supply_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class VetSuppliesScreen extends ConsumerStatefulWidget {
  const VetSuppliesScreen({super.key});

  @override
  ConsumerState<VetSuppliesScreen> createState() => _VetSuppliesScreenState();
}

class _VetSuppliesScreenState extends ConsumerState<VetSuppliesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _ghostText = '';
  String _fullSuggestion = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // إضافة listener لإخفاء الكيبورد عند تغيير التاب
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _hideKeyboard();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // دالة مساعدة لإخفاء الكيبورد
  void _hideKeyboard() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      HapticFeedback.lightImpact();
      setState(() {
        if (_searchController.text.isEmpty) {
          _ghostText = '';
          _fullSuggestion = '';
        }
      });
    }
  }

  // دالة لتحديث الاقتراحات
  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _ghostText = '';
        _fullSuggestion = '';
      });
      return;
    }

    // جمع جميع المستلزمات من كلا المصدرين
    final allSuppliesState = ref.read(allVetSuppliesNotifierProvider);
    final mySuppliesState = ref.read(myVetSuppliesNotifierProvider);
    
    List<VetSupply> allSupplies = [];
    
    allSuppliesState.whenData((supplies) => allSupplies.addAll(supplies));
    mySuppliesState.whenData((supplies) => allSupplies.addAll(supplies));

    // البحث عن أفضل اقتراح
    String bestMatch = '';
    for (final supply in allSupplies) {
      final name = supply.name.toLowerCase();
      final description = supply.description.toLowerCase();
      final queryLower = query.toLowerCase();
      
      if (name.startsWith(queryLower) && name.length > query.length) {
        bestMatch = supply.name;
        break;
      } else if (description.contains(queryLower)) {
        // العثور على الكلمة التي تبدأ بالاستعلام
        final words = description.split(' ');
        for (final word in words) {
          if (word.startsWith(queryLower) && word.length > query.length) {
            bestMatch = word;
            break;
          }
        }
        if (bestMatch.isNotEmpty) break;
      }
    }

    setState(() {
      if (bestMatch.isNotEmpty && bestMatch.toLowerCase().startsWith(query.toLowerCase())) {
        _ghostText = query + bestMatch.substring(query.length);
        _fullSuggestion = bestMatch;
      } else {
        _ghostText = '';
        _fullSuggestion = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _hideKeyboard(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المستلزمات البيطرية'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'جميع المستلزمات',
              ),
              Tab(
                icon: Icon(Icons.store_outlined),
                text: 'مستلزماتي',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // شريط البحث
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: [
                  // النص الشبحي
                  if (_ghostText.isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 48, right: 12),
                        child: Text(
                          _ghostText,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  // حقل البحث الفعلي
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'البحث في المستلزمات...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_fullSuggestion.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_tab, color: Colors.blue),
                                    onPressed: () {
                                      _searchController.text = _fullSuggestion;
                                      _searchController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: _fullSuggestion.length),
                                      );
                                      setState(() {
                                        _searchQuery = _fullSuggestion;
                                        _ghostText = '';
                                        _fullSuggestion = '';
                                      });
                                    },
                                    tooltip: 'قبول الاقتراح',
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _ghostText = '';
                                      _fullSuggestion = '';
                                    });
                                  },
                                ),
                              ],
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      
                      // تحديث الاقتراحات مع debounce
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        _updateSuggestions(value);
                      });
                    },
                    onTap: () {
                      // إظهار الاقتراحات عند النقر
                      if (_searchController.text.isNotEmpty) {
                        _updateSuggestions(_searchController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
            // محتوى التابات
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AllSuppliesTab(searchQuery: _searchQuery),
                  _MySuppliesTab(searchQuery: _searchQuery),
                ],
              ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddVetSupplyScreen(),
            ),
          );
          
          if (result == true && mounted) {
            ref.read(allVetSuppliesNotifierProvider.notifier).refreshAllSupplies();
            ref.read(myVetSuppliesNotifierProvider.notifier).refreshMySupplies();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة مستلزم'),
        elevation: 4,
      ),
      ),
    );
  }
}

// ===================================================================
// All Supplies Tab
// ===================================================================
class _AllSuppliesTab extends ConsumerWidget {
  const _AllSuppliesTab({this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(allVetSuppliesNotifierProvider);

    return suppliesAsync.when(
      data: (supplies) {
        // فلترة المستلزمات حسب البحث
        final filteredSupplies = searchQuery.isEmpty
            ? supplies
            : supplies.where((supply) =>
                supply.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                supply.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (supply.userName != null && supply.userName!.toLowerCase().contains(searchQuery.toLowerCase()))
              ).toList();

        if (filteredSupplies.isEmpty) {
          if (searchQuery.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 100,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'لم يتم العثور على مستلزمات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'جرب كلمات بحث أخرى',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'لا توجد مستلزمات متاحة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'كن أول من يضيف مستلزمات بيطرية',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(allVetSuppliesNotifierProvider.notifier).refreshAllSupplies();
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: filteredSupplies.length,
            itemBuilder: (context, index) {
              final supply = filteredSupplies[index];
              return _SupplyCard(
                supply: supply,
                showActions: false,
                onTap: () => _showSupplyDetailsDialog(context, ref, supply),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ: ${error.toString()}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(allVetSuppliesNotifierProvider.notifier).refreshAllSupplies();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplyDetailsDialog(BuildContext context, WidgetRef ref, VetSupply supply) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: supply.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supply.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (supply.userName != null)
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 18, color: theme.textTheme.bodySmall?.color),
                            const SizedBox(width: 8),
                            Text(
                              supply.userName!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        supply.description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildStatChip(
                            context: context,
                            icon: Icons.price_change,
                            label: 'السعر',
                            value: '${supply.price.toStringAsFixed(0)} ج.م',
                            color: Colors.green,
                            
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            context: context,
                            icon: Icons.visibility,
                            label: 'مشاهدات',
                            value: '${supply.viewsCount}',
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(allVetSuppliesNotifierProvider.notifier)
                                .incrementViews(supply.id);
                            Navigator.pop(context);
                            _openWhatsApp(context, supply.phone);
                          },
                          icon: const Icon(Icons.phone_in_talk_outlined,
                              color: Colors.white),
                          label: const Text(
                            'تواصل مع البائع',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ===================================================================
// My Supplies Tab
// ===================================================================
class _MySuppliesTab extends ConsumerWidget {
  const _MySuppliesTab({this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(myVetSuppliesNotifierProvider);

    return suppliesAsync.when(
      data: (supplies) {
        // فلترة المستلزمات حسب البحث
        final filteredSupplies = searchQuery.isEmpty
            ? supplies
            : supplies.where((supply) =>
                supply.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                supply.description.toLowerCase().contains(searchQuery.toLowerCase())
              ).toList();

        if (filteredSupplies.isEmpty) {
          if (searchQuery.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 100,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'لم يتم العثور على مستلزمات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'جرب كلمات بحث أخرى',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'لم تضف أي مستلزمات بعد',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اضغط على زر + لإضافة أول مستلزم لك',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(myVetSuppliesNotifierProvider.notifier).refreshMySupplies();
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: filteredSupplies.length,
            itemBuilder: (context, index) {
              final supply = filteredSupplies[index];
              return _SupplyCard(
                supply: supply,
                showActions: true,
                onTap: () => _showSupplyDetailsDialog(context, ref, supply),
                onEdit: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditVetSupplyScreen(supply: supply),
                    ),
                  );
                  
                  if (result == true && context.mounted) {
                    ref.read(myVetSuppliesNotifierProvider.notifier).refreshMySupplies();
                    ref.read(allVetSuppliesNotifierProvider.notifier).refreshAllSupplies();
                  }
                },
                onDelete: () => _confirmDelete(context, ref, supply),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ: ${error.toString()}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(myVetSuppliesNotifierProvider.notifier).refreshMySupplies();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, VetSupply supply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "${supply.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(myVetSuppliesNotifierProvider.notifier)
          .deleteSupply(supply.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'تم الحذف بنجاح' : 'فشل الحذف'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }

      // Refresh all supplies tab as well
      if (success) {
        ref.read(allVetSuppliesNotifierProvider.notifier).refreshAllSupplies();
      }
    }
  }

  void _showSupplyDetailsDialog(BuildContext context, WidgetRef ref, VetSupply supply) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: supply.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supply.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (supply.userName != null)
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 18, color: theme.textTheme.bodySmall?.color),
                            const SizedBox(width: 8),
                            Text(
                              supply.userName!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        supply.description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildStatChip(
                            context: context,
                            icon: Icons.price_change,
                            label: 'السعر',
                            value: '${supply.price.toStringAsFixed(0)} ج.م',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            context: context,
                            icon: Icons.visibility,
                            label: 'مشاهدات',
                            value: '${supply.viewsCount}',
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(allVetSuppliesNotifierProvider.notifier)
                                .incrementViews(supply.id);
                            Navigator.pop(context);
                            _openWhatsApp(context, supply.phone);
                          },
                          icon: const Icon(Icons.phone_in_talk_outlined,
                              color: Colors.white),
                          label: const Text(
                            'تواصل مع البائع',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWhatsApp(BuildContext context, String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح WhatsApp')),
        );
      }
    }
  }
}

// ===================================================================
// Supply Card Widget
// ===================================================================
class _SupplyCard extends StatelessWidget {
  final VetSupply supply;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SupplyCard({
    required this.supply,
    required this.showActions,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: supply.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.inventory_2, size: 50, color: Colors.grey[400]),
                    ),
                  ),
                  if (showActions)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.onSurface),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit?.call();
                          } else if (value == 'delete') {
                            onDelete?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('تعديل', style: TextStyle(color: theme.colorScheme.onSurface)),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف'),
                            ]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      supply.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (supply.userName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              supply.userName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${supply.price.toStringAsFixed(0)} ُEGP',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${supply.viewsCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
