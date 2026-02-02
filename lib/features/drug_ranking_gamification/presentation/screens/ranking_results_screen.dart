import 'package:fieldawy_store/core/theme/app_colors.dart';
import 'package:fieldawy_store/features/drug_ranking_gamification/data/drug_ranking_service.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RankingResultsScreen extends ConsumerStatefulWidget {
  final DrugRankingService rankingService;

  const RankingResultsScreen({Key? key, required this.rankingService})
      : super(key: key);

  @override
  ConsumerState<RankingResultsScreen> createState() =>
      _RankingResultsScreenState();
}

class _RankingResultsScreenState extends ConsumerState<RankingResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rankings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRankings();
  }

  Future<void> _loadRankings([String? query]) async {
    setState(() => _isLoading = true);
    try {
      // Logic to fetch rankings from service
      // Since we don't have the backend implementation yet, we will mock/simulate specific logic
      // or fetch all products and group them locally for demonstration.

      final products = await widget.rankingService
          .getAllProductsForRankingDebug(); // Need to expose this or similar

      // Group by Active Principle
      final Map<String, List<ProductModel>> byActivePrinciple = {};

      for (var p in products) {
        if (p.activePrinciple != null) {
          final key = p.activePrinciple!;
          if (!byActivePrinciple.containsKey(key)) {
            byActivePrinciple[key] = [];
          }
          byActivePrinciple[key]!.add(p);
        }
      }

      List<Map<String, dynamic>> results = [];
      byActivePrinciple.forEach((principle, list) {
        if (list.length >= 2) {
          // Only show groups with competition
          // Sort by efficiencyScore (descending)
          list.sort((a, b) =>
              (b.efficiencyScore ?? 0).compareTo(a.efficiencyScore ?? 0));
          results.add({
            'activePrinciple': principle,
            'products': list,
            'topProduct': list.first,
          });
        }
      });

      // Filter by query
      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        results = results.where((group) {
          final principle = (group['activePrinciple'] as String).toLowerCase();
          final products = (group['products'] as List<ProductModel>);
          final hasMatchingProduct =
              products.any((p) => p.name.toLowerCase().contains(lowerQuery));
          return principle.contains(lowerQuery) || hasMatchingProduct;
        }).toList();
      }

      setState(() {
        _rankings = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error loading rankings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("ترتيب كفاءة الأدوية",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                // Debounce could be added here
                _loadRankings(val);
              },
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "ابحث عن مادة فعالة أو اسم دواء...",
                hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search,
                    color: theme.iconTheme.color?.withOpacity(0.5)),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rankings.isEmpty
                    ? Center(
                        child: Text("لا توجد نتائج",
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _rankings.length,
                        itemBuilder: (context, index) {
                          final group = _rankings[index];
                          final activePrinciple =
                              group['activePrinciple'] as String;
                          final products =
                              group['products'] as List<ProductModel>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.05),
                            color: theme.cardColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Theme(
                              data: theme.copyWith(
                                  dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                collapsedShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: theme.cardColor,
                                collapsedBackgroundColor: theme.cardColor,
                                title: Text(
                                  activePrinciple,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                subtitle: Text(
                                  "${products.length} منتجات في المنافسة",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6)),
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.science,
                                      color: AppColors.primaryColor, size: 20),
                                ),
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: Column(
                                      children:
                                          products.asMap().entries.map((entry) {
                                        final i = entry.key;
                                        final p = entry.value;
                                        final isTop = i == 0;

                                        return ListTile(
                                          leading: Stack(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: Colors.grey
                                                          .withOpacity(0.2)),
                                                  color: Colors.grey
                                                      .withOpacity(0.05),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: CachedNetworkImage(
                                                    imageUrl: p.imageUrl,
                                                    fit: BoxFit.contain,
                                                    placeholder: (context,
                                                            url) =>
                                                        const Icon(
                                                            Icons.medication,
                                                            size: 20,
                                                            color: Colors.grey),
                                                    errorWidget: (context, url,
                                                            error) =>
                                                        const Icon(Icons.error,
                                                            size: 20,
                                                            color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                              if (isTop)
                                                Positioned(
                                                  top: -4,
                                                  right: -4,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(2),
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.amber,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons.star,
                                                        color: Colors.white,
                                                        size: 10),
                                                  ),
                                                )
                                            ],
                                          ),
                                          title: Text(p.name,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                      fontWeight: isTop
                                                          ? FontWeight.bold
                                                          : FontWeight.normal)),
                                          subtitle: Row(
                                            children: [
                                              if (isTop)
                                                Text("الأكثر كفاءة • ",
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors.amber[700],
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              Expanded(
                                                child: Text(p.company ?? '',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: theme.colorScheme
                                                            .onSurface
                                                            .withOpacity(0.6)),
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                            ],
                                          ),
                                          trailing: Container(
                                              width: 24,
                                              height: 24,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                  color: isTop
                                                      ? Colors.amber
                                                      : Colors.grey
                                                          .withOpacity(0.2),
                                                  shape: BoxShape.circle),
                                              child: Text("${i + 1}",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isTop
                                                          ? Colors.white
                                                          : theme.colorScheme
                                                              .onSurface,
                                                      fontSize: 12))),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
