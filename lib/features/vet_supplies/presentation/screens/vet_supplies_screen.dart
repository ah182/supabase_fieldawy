import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/utils/number_formatter.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/vet_supplies/application/vet_supplies_provider.dart';
import 'package:fieldawy_store/features/vet_supplies/domain/vet_supply_model.dart';
// ignore: unused_import
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';

import 'package:fieldawy_store/features/vet_supplies/presentation/screens/add_vet_supply_screen.dart';
import 'package:fieldawy_store/features/vet_supplies/presentation/screens/edit_vet_supply_screen.dart';
import 'package:flutter/material.dart';
import 'package:fieldawy_store/features/home/presentation/mixins/search_tracking_mixin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Added Imports
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/search_history_view.dart';
import 'package:fieldawy_store/features/home/application/search_history_provider.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/quick_filters_bar.dart';
import 'package:fieldawy_store/features/vet_supplies/application/vet_supplies_filters_provider.dart';
import 'package:fieldawy_store/widgets/refreshable_error_widget.dart';
import 'package:fieldawy_store/core/providers/governorates_provider.dart';
import 'package:fieldawy_store/core/models/governorate_model.dart';


class VetSuppliesScreen extends ConsumerStatefulWidget {
  const VetSuppliesScreen({super.key});

  @override
  ConsumerState<VetSuppliesScreen> createState() => _VetSuppliesScreenState();
}

class _VetSuppliesScreenState extends ConsumerState<VetSuppliesScreen>
    with SingleTickerProviderStateMixin, SearchTrackingMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  String? _currentSearchId; // ID البحث الحالي لتتبع النقرات
  String _ghostText = '';
  String _fullSuggestion = '';
  Timer? _searchDebounce;
  Timer? _debounce;
  
  static const String _historyTabId = 'vet_supplies';

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

    _searchFocusNode.addListener(() {
      setState(() {});
      if (_searchFocusNode.hasFocus) {
        HapticFeedback.selectionClick();
      } else {
        // إذا فقد التركيز وكان فارغاً، مسح الحالة
        if (_searchController.text.isEmpty) {
          setState(() {
            _searchQuery = '';
            _ghostText = '';
            _fullSuggestion = '';
          });
        }
      }
    });

    // تشغيل تحسين أسماء المنتجات في الخلفية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _improveExistingSearchTerms();
    });
  }

  /// تحسين مصطلحات البحث الموجودة في الخلفية
  /// Improve existing search terms in background
  Future<void> _improveExistingSearchTerms() async {
    try {
      // التحقق من أن الـ widget لا يزال موجوداً قبل استخدام ref
      if (!mounted) return;
      
      print('🔄 Starting vet supplies search terms improvement...');
      await improveAllVetSupplySearchTerms(ref);
      
      // التحقق مرة أخرى بعد العملية غير المتزامنة
      if (!mounted) return;
      
      print('✅ Vet supplies search terms improvement completed');
    } catch (e) {
      print('❌ Error improving vet supplies search terms: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _searchDebounce?.cancel();
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

  // --- Helper Methods for Dialogs ---

  void _showSearchHistoryDialog(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final history = ref.read(searchHistoryProvider)[_historyTabId] ?? [];
    
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'لا يوجد سجل بحث حالياً' : 'No search history available')),
      );
      return;
    }

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      alignment: const Alignment(0, -0.5),
      body: SearchHistoryView(
        tabId: _historyTabId,
        onClose: () => Navigator.pop(context),
        onTermSelected: (term) {
          _searchController.text = term;
          setState(() {
            _searchQuery = term;
            _debouncedSearchQuery = term;
          });
          ref.read(searchHistoryProvider.notifier).addSearchTerm(term, _historyTabId);
          Navigator.pop(context);
          _searchFocusNode.unfocus();
        },
      ),
    ).show();
  }

  void _showSearchFiltersDialog(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      alignment: const Alignment(0, -0.5),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAr ? 'الفلاتر السريعة' : 'Quick Filters',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Consumer(
                      builder: (context, ref, child) {
                        final filters = ref.watch(vetSuppliesFiltersProvider);
                        final hasActiveFilters = filters.isNearest || filters.selectedGovernorate != null;
                        
                        if (!hasActiveFilters) return const SizedBox.shrink();
                        
                        return InkWell(
                          onTap: () {
                            ref.read(vetSuppliesFiltersProvider.notifier).resetFilters();
                          },
                          child: Text(
                            isAr ? 'مسح الكل' : 'Clear All',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 16),
            const QuickFiltersBar(showCheapest: true, useVetSuppliesFilters: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).show();
  }

  Widget _buildSearchActionButton({
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    List<Color>? gradientColors,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: (isActive && gradientColors != null)
              ? LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive 
              ? (gradientColors == null ? color : null) 
              : (isDark ? Colors.white.withOpacity(0.08) : color.withOpacity(0.05)),
          boxShadow: isActive ? [
            BoxShadow(
              color: (gradientColors?.last ?? color).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ] : [],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive 
              ? Colors.white 
              : (isDark ? Colors.white70 : color.withOpacity(0.6)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider);
    final user = userDataAsync.asData?.value;
    final isDoctor = user?.role == 'doctor';
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _hideKeyboard(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                elevation: 0,
                centerTitle: true,
                backgroundColor: theme.colorScheme.surface,
                leading: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // زيادة الهامش الأفقي للداخل
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(20, 20),
                        painter: _ArrowBackPainter(color: Colors.black),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  'vet_supplies_feature.title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(isDoctor ? 105 : 170),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            // Search Bar
                            Expanded(
                              child: Stack(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        ref.read(searchHistoryProvider.notifier).addSearchTerm(value, _historyTabId);
                                      }
                                      _searchFocusNode.unfocus();
                                    },
                                    onTap: () {
                                      if (!_searchFocusNode.hasFocus) {
                                        HapticFeedback.selectionClick();
                                      }
                                      if (_searchController.text.isNotEmpty) {
                                        _updateSuggestions(_searchController.text);
                                      }
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                      
                                      _debounce?.cancel();
                                      _debounce = Timer(const Duration(milliseconds: 300), () {
                                        setState(() {
                                          _debouncedSearchQuery = value;
                                        });
                                        _updateSuggestions(value);
                                        
                                        // تتبع البحث فقط في تاب "جميع المستلزمات" (التاب الأول)
                                        if (!isDoctor && _tabController.index == 0) {
                                          _trackVetSuppliesSearch();
                                        } else if (isDoctor) {
                                          _trackVetSuppliesSearch();
                                        }
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'vet_supplies_feature.search.hint'.tr(),
                                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: _searchFocusNode.hasFocus 
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface.withOpacity(0.6),
                                        size: 22,
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                  _debouncedSearchQuery = '';
                                                  _ghostText = '';
                                                  _fullSuggestion = '';
                                                });
                                                HapticFeedback.lightImpact();
                                              },
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: theme.brightness == Brightness.dark
                                          ? theme.colorScheme.surface.withOpacity(0.8)
                                          : theme.colorScheme.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                  // Ghost Text
                                  if (_ghostText.isNotEmpty && _searchFocusNode.hasFocus)
                                    Positioned(
                                      top: 12,
                                      right: 37,
                                      child: AnimatedOpacity(
                                        opacity: _searchQuery.isNotEmpty ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: GestureDetector(
                                          onTap: () {
                                            if (_fullSuggestion.isNotEmpty) {
                                              _searchController.text = _fullSuggestion;
                                              setState(() {
                                                _searchQuery = _fullSuggestion;
                                                _debouncedSearchQuery = _fullSuggestion;
                                                _ghostText = '';
                                                _fullSuggestion = '';
                                              });
                                              ref.read(searchHistoryProvider.notifier).addSearchTerm(_searchController.text, _historyTabId);
                                              HapticFeedback.selectionClick();
                                              _searchFocusNode.requestFocus();
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.primary),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    _ghostText,
                                                    style: TextStyle(
                                                      color: theme.colorScheme.primary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Action Buttons (History & Filter)
                            const SizedBox(width: 8),
                            Consumer(
                              builder: (context, ref, child) {
                                final filters = ref.watch(vetSuppliesFiltersProvider);
                                final history = ref.watch(searchHistoryProvider)[_historyTabId] ?? [];
                                final isFilterActive = filters.isNearest || filters.selectedGovernorate != null || filters.isCheapest;
                                final isHistoryActive = history.contains(_searchQuery) && _searchQuery.isNotEmpty;

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSearchActionButton(
                                      icon: Icons.history_rounded,
                                      color: Colors.indigo,
                                      isActive: isHistoryActive,
                                      gradientColors: [Colors.indigo, Colors.blueAccent],
                                      onTap: () => _showSearchHistoryDialog(context),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildSearchActionButton(
                                      icon: Icons.tune_rounded,
                                      color: Colors.teal,
                                      isActive: isFilterActive,
                                      gradientColors: [Colors.teal, Colors.cyan.shade600],
                                      onTap: () => _showSearchFiltersDialog(context),
                                    ),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                      
                      // Tabs (Only if not doctor)
                      if (!isDoctor)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withOpacity(0.8),
                                  theme.colorScheme.primary.withOpacity(0.8),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                            labelColor: Colors.white,
                            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 18),
                                    const SizedBox(width: 6),
                                    Text('vet_supplies_feature.tabs.all_supplies'.tr()),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.store_outlined, size: 18),
                                    const SizedBox(width: 6),
                                    Text('vet_supplies_feature.tabs.my_supplies'.tr()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: isDoctor 
            ? _AllSuppliesTab(
                searchQuery: _debouncedSearchQuery,
                searchId: _currentSearchId,
                onItemTap: _handleItemTap,
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _AllSuppliesTab(
                    searchQuery: _debouncedSearchQuery,
                    searchId: _currentSearchId,
                    onItemTap: _handleItemTap,
                  ),
                  _MySuppliesTab(searchQuery: _debouncedSearchQuery),
                ],
              ),
        ),
      floatingActionButton: isDoctor 
        ? null 
        : FloatingActionButton.extended(
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
            label: Text('vet_supplies_feature.actions.add_supply'.tr()),
            elevation: 4,
          ),
      ),
    );
  }

  /// تتبع البحث في المستلزمات البيطرية (فقط في تاب جميع المستلزمات)
  /// Track vet supplies search (only in All Supplies tab)
  Future<void> _trackVetSuppliesSearch() async {
    if (_debouncedSearchQuery.trim().length < 3) { // تتبع البحث فقط إذا كان النص 3 حروف أو أكثر
      _currentSearchId = null;
      return;
    }

    try {
      // التحقق من أن الـ widget لا يزال موجوداً
      if (!mounted) return;
      
      // الحصول على النتائج المفلترة لحساب العدد
      final filteredResults = _getFilteredVetSupplies();
      
      print('🔍 Tracking vet supplies search: "$_debouncedSearchQuery" (Results: ${filteredResults.length})');
      
      // تحسين اسم المنتج قبل التتبع
      String improvedSearchTerm = await improveVetSupplyName(ref, _debouncedSearchQuery);
      
      // التحقق مرة أخرى بعد العملية غير المتزامنة
      if (!mounted) return;
      
      // تتبع البحث باستخدام الاسم المحسن
      _currentSearchId = await trackVetSuppliesSearch(
        ref: ref,
        searchTerm: improvedSearchTerm,
        results: filteredResults,
      );
      
      // التحقق الأخير قبل طباعة النتائج
      if (!mounted) return;
      
      if (_currentSearchId != null) {
        print('✅ Vet supplies search tracked with ID: $_currentSearchId');
        if (improvedSearchTerm != _debouncedSearchQuery) {
          print('🎯 Search term improved: "$_debouncedSearchQuery" → "$improvedSearchTerm"');
        }
      } else {
        print('❌ Failed to track vet supplies search: no ID returned');
      }
    } catch (e) {
      print('❌ Error tracking vet supplies search: $e');
    }
  }

  /// الحصول على المستلزمات المفلترة
  /// Get filtered vet supplies
  List _getFilteredVetSupplies() {
    final suppliesAsync = ref.read(allVetSuppliesNotifierProvider);
    final supplies = suppliesAsync.asData?.value ?? [];
    
    if (_debouncedSearchQuery.isEmpty) return supplies;

    return supplies.where((supply) =>
        supply.name.toLowerCase().contains(_debouncedSearchQuery.toLowerCase()) ||
        supply.description.toLowerCase().contains(_debouncedSearchQuery.toLowerCase()) ||
        (supply.userName != null && supply.userName!.toLowerCase().contains(_debouncedSearchQuery.toLowerCase()))
    ).toList();
  }

  /// معالجة النقر على العنصر (فقط في تاب جميع المستلزمات)
  /// Handle item tap for click tracking (only in All Supplies tab)
  void _handleItemTap(String itemId) {
    if (_currentSearchId != null && _debouncedSearchQuery.length >= 3 && _tabController.index == 0) {
      print('👆 Tracking vet supply click: Item ID: $itemId, Search ID: $_currentSearchId');
      trackSearchClick(
        ref: ref,
        searchId: _currentSearchId,
        clickedItemId: itemId,
        itemType: 'vet_supply',
      );
    } else {
      print('⚠️ No vet supply search tracking - Search ID: $_currentSearchId, Query length: ${_debouncedSearchQuery.length}, Tab: ${_tabController.index}');
    }
  }
}

// ===================================================================
// All Supplies Tab
// ===================================================================
class _AllSuppliesTab extends ConsumerWidget {
  const _AllSuppliesTab({
    this.searchQuery = '',
    this.searchId,
    this.onItemTap,
  });

  final String searchQuery;
  final String? searchId;
  final void Function(String)? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(allVetSuppliesNotifierProvider);
    final filters = ref.watch(vetSuppliesFiltersProvider);
    final governoratesAsync = ref.watch(governoratesProvider);
    
    // جلب بيانات الموزعين لتحديد الموقع
    final distributorsAsync = ref.watch(distributorsProvider);
    final distributorsMap = <String, dynamic>{};
    distributorsAsync.whenData((distributors) {
      for (final distributor in distributors) {
        distributorsMap[distributor.id] = distributor;
      }
    });

    return suppliesAsync.when(
      data: (supplies) {
        // 1. فلترة المستلزمات حسب البحث النصي
        var filteredSupplies = searchQuery.isEmpty
            ? supplies.toList() // Create a copy to avoid mutating state
            : supplies.where((supply) =>
                supply.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                supply.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (supply.userName != null && supply.userName!.toLowerCase().contains(searchQuery.toLowerCase()))
              ).toList();

        // 2. فلترة حسب المحافظة (شامل المراكز)
        if (filters.selectedGovernorate != null) {
          final governorates = governoratesAsync.asData?.value ?? [];
          final selectedGovModel = governorates.firstWhere(
            (g) => g.name == filters.selectedGovernorate,
            orElse: () => GovernorateModel(id: -1, name: '', centers: []),
          );
          
          filteredSupplies = filteredSupplies.where((supply) {
             final distributor = distributorsMap[supply.userId];
             if (distributor != null) {
               // إذا كان لدينا بيانات الموزع، نتحقق من مناطق التغطية
               if (distributor.governorates != null && 
                   (distributor.governorates as List).contains(filters.selectedGovernorate)) {
                 return true;
               }
               // التحقق من المراكز أيضاً
               if (distributor.centers != null) {
                  for (final center in (distributor.centers as List)) {
                    if (selectedGovModel.centers.contains(center)) return true;
                  }
               }
             }
             
             // محاولة البحث في العنوان النصي للموزع إذا وجد (أو أي حقل موقع آخر في VetSupply)
             // حالياً لا يوجد حقل عنوان صريح في VetSupply، نعتمد على بيانات الموزع
             return false;
          }).toList();
        }

        // 3. الترتيب حسب السعر (الأرخص)
        if (filters.isCheapest) {
          filteredSupplies.sort((a, b) => a.price.compareTo(b.price));
        }

        if (filteredSupplies.isEmpty) {
          if (searchQuery.isNotEmpty || filters.selectedGovernorate != null) {
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
                      'vet_supplies_feature.search.no_results'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'vet_supplies_feature.search.try_other_terms'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (filters.selectedGovernorate != null || filters.isNearest)
                      TextButton(
                        onPressed: () => ref.read(vetSuppliesFiltersProvider.notifier).resetFilters(),
                        child: Text('إعادة تعيين الفلاتر'),
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
                    'vet_supplies_feature.empty.no_supplies'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                                      Text(
                                        'vet_supplies_feature.empty.be_first'.tr(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      TextButton.icon(
                                        onPressed: () => ref.read(allVetSuppliesNotifierProvider.notifier).refreshAllSupplies(),
                                        icon: const Icon(Icons.refresh),
                                        label: Text('retry'.tr()),
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
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 0.60,
            ),
            itemCount: filteredSupplies.length,
            itemBuilder: (context, index) {
              final supply = filteredSupplies[index];
              return _SupplyCard(
                supply: supply,
                showActions: false,
                onTap: () {
                  onItemTap?.call(supply.id);
                  _showSupplyDetailsDialog(context, ref, supply);
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => RefreshableErrorWidget(
                      message: 'vet_supplies_feature.messages.generic_error'.tr(),
                      onRetry: () => ref.read(allVetSuppliesNotifierProvider.notifier).refreshAllSupplies(),
                    ),    );
  }

  void _showSupplyDetailsDialog(BuildContext context, WidgetRef ref, VetSupply supply) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // جلب بيانات الموزعين للبحث عن صاحب المستلزم
    final distributorsAsync = ref.read(distributorsProvider);
    final distributor = distributorsAsync.asData?.value.firstWhereOrNull((d) => d.id == supply.userId);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                      Row(
                        children: [
                          Icon(Icons.store_outlined, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              if (distributor == null) return;
                              
                              // إظهار مؤشر تحميل بسيط
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator()),
                              );
                              
                              await Future.delayed(const Duration(milliseconds: 300));
                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // إغلاق التحميل
                              Navigator.of(context).pop(); // إغلاق الديالوج الحالي
                              
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DistributorProductsScreen(
                                    distributor: distributor,
                                    initialTabIndex: 1, // فتح تاب المستلزمات (Index 1)
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  distributor?.displayName ?? supply.userName ?? 'distributors_feature.unknown_distributor'.tr(),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.touch_app_rounded, size: 14, color: theme.colorScheme.primary.withOpacity(0.7)),
                              ],
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
                      // Info Grid: Price, Views, and Package
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildStatChip(
                            context: context,
                            icon: Icons.price_change,
                            label: 'vet_supplies_feature.fields.price'.tr(),
                            value: '${NumberFormatter.formatCompact(supply.price)} ${"EGP".tr()}',
                            color: Colors.green,
                          ),
                          _buildStatChip(
                            context: context,
                            icon: Icons.inventory_2_outlined,
                            label: 'vet_supplies_feature.fields.package_label'.tr().replaceAll(' *', ''),
                            value: supply.package,
                            color: Colors.blue,
                          ),
                          _buildStatChip(
                            context: context,
                            icon: Icons.visibility,
                            label: 'vet_supplies_feature.fields.views'.tr(),
                            value: NumberFormatter.formatCompact(supply.viewsCount),
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Coverage Areas Section
                      if (distributor != null && distributor.governorates != null && distributor.governorates!.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.map_outlined, color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'distributors_feature.coverage_areas'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // عرض المحافظات
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: distributor.governorates!.map((gov) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              gov,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
                        // عرض المراكز
                        if (distributor.centers != null && distributor.centers!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: distributor.centers!.map((center) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Text(
                                center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],

                      const SizedBox(height: 8),
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
                          label: Text(
                            'vet_supplies_feature.actions.contact_seller'.tr(),
                            style: const TextStyle(
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
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
          SnackBar(
            content: Text('vet_supplies_feature.messages.whatsapp_error'.tr()),
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
                      'vet_supplies_feature.search.no_results'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'vet_supplies_feature.search.try_other_terms'.tr(),
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
                    'vet_supplies_feature.empty.no_my_supplies'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                                      Text(
                                        'vet_supplies_feature.empty.add_first'.tr(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      TextButton.icon(
                                        onPressed: () => ref.read(myVetSuppliesNotifierProvider.notifier).refreshMySupplies(),
                                        icon: const Icon(Icons.refresh),
                                        label: Text('retry'.tr()),
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
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 0.60,
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
      error: (error, stack) => RefreshableErrorWidget(
        message: 'vet_supplies_feature.messages.generic_error'.tr(),
        onRetry: () => ref.read(myVetSuppliesNotifierProvider.notifier).refreshMySupplies(),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, VetSupply supply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('vet_supplies_feature.dialogs.delete_confirm_title'.tr()),
        content: Text('vet_supplies_feature.dialogs.delete_confirm_message'.tr(namedArgs: {'name': supply.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('vet_supplies_feature.actions.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('vet_supplies_feature.actions.delete'.tr()),
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
            content: Text(success ? 'vet_supplies_feature.messages.delete_success'.tr() : 'vet_supplies_feature.messages.delete_error'.tr()),
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
    
    // جلب بيانات الموزعين للبحث عن صاحب المستلزم
    final distributorsAsync = ref.read(distributorsProvider);
    final distributor = distributorsAsync.asData?.value.firstWhereOrNull((d) => d.id == supply.userId);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                      Row(
                        children: [
                          Icon(Icons.store_outlined, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              if (distributor == null) return;
                              
                              // إظهار مؤشر تحميل بسيط
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator()),
                              );
                              
                              await Future.delayed(const Duration(milliseconds: 300));
                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // إغلاق التحميل
                              Navigator.of(context).pop(); // إغلاق الديالوج الحالي
                              
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DistributorProductsScreen(
                                    distributor: distributor,
                                    initialTabIndex: 1, // فتح تاب المستلزمات (Index 1)
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  distributor?.displayName ?? supply.userName ?? 'distributors_feature.unknown_distributor'.tr(),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.touch_app_rounded, size: 14, color: theme.colorScheme.primary.withOpacity(0.7)),
                              ],
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
                      // Info Grid: Price, Views, and Package
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildStatChip(
                            context: context,
                            icon: Icons.price_change,
                            label: 'vet_supplies_feature.fields.price'.tr(),
                            value: '${NumberFormatter.formatCompact(supply.price)} ${"EGP".tr()}',
                            color: Colors.green,
                          ),
                          _buildStatChip(
                            context: context,
                            icon: Icons.inventory_2_outlined,
                            label: 'vet_supplies_feature.fields.package_label'.tr().replaceAll(' *', ''),
                            value: supply.package,
                            color: Colors.blue,
                          ),
                          _buildStatChip(
                            context: context,
                            icon: Icons.visibility,
                            label: 'vet_supplies_feature.fields.views'.tr(),
                            value: NumberFormatter.formatCompact(supply.viewsCount),
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Coverage Areas Section
                      if (distributor != null && distributor.governorates != null && distributor.governorates!.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.map_outlined, color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'distributors_feature.coverage_areas'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // عرض المحافظات
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: distributor.governorates!.map((gov) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              gov,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
                        // عرض المراكز
                        if (distributor.centers != null && distributor.centers!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: distributor.centers!.map((center) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Text(
                                center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],

                      const SizedBox(height: 8),
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
                          label: Text(
                            'vet_supplies_feature.actions.contact_seller'.tr(),
                            style: const TextStyle(
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
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
          SnackBar(
            content: Text('vet_supplies_feature.messages.whatsapp_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ===================================================================
// Supply Card Widget
// ===================================================================
class _SupplyCard extends ConsumerStatefulWidget {
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
  ConsumerState<_SupplyCard> createState() => _SupplyCardState();
}

class _ArrowBackPainter extends CustomPainter {
  final Color color;
  _ArrowBackPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Start from right (shaft)
    path.moveTo(size.width * 0.8, size.height / 2);
    // Draw to left
    path.lineTo(size.width * 0.2, size.height / 2);
    // Draw upper wing
    path.moveTo(size.width * 0.45, size.height * 0.25);
    path.lineTo(size.width * 0.2, size.height / 2);
    // Draw lower wing
    path.moveTo(size.width * 0.45, size.height * 0.75);
    path.lineTo(size.width * 0.2, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SupplyCardState extends ConsumerState<_SupplyCard> {
  bool _hasBeenViewed = false; // لمنع العد المتكرر
  
  void _handleVisibilityChanged(VisibilityInfo info) {
    // إذا كان الكارت مرئي أكثر من 50% ولم يتم عده مسبقاً
    if (info.visibleFraction > 0.5 && !_hasBeenViewed) {
      _hasBeenViewed = true; // منع العد المتكرر
      
      // زيادة المشاهدات
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(allVetSuppliesNotifierProvider.notifier).incrementViews(widget.supply.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return VisibilityDetector(
      key: Key('supply_card_${widget.supply.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: widget.supply.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          color: Colors.transparent,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.transparent,
                          child: Icon(Icons.inventory_2, size: 50, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                    if (widget.showActions)
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
                              widget.onEdit?.call();
                            } else if (value == 'delete') {
                              widget.onDelete?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('vet_supplies_feature.actions.edit'.tr(), style: TextStyle(color: theme.colorScheme.onSurface)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                const Icon(Icons.delete_outline, color: Colors.red),
                                const SizedBox(width: 8),
                                Text('vet_supplies_feature.actions.delete'.tr()),
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
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Name
                      Text(
                        widget.supply.name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // User/Distributor Name
                      if (widget.supply.userName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.store_outlined, size: 10, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  widget.supply.userName!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 9,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 4),

                      // Price and Views
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Price Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${NumberFormatter.formatCompact(widget.supply.price)} ${"EGP".tr()}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          // Views Badge
                          if (widget.supply.viewsCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.secondary.withOpacity(0.1),
                                    theme.colorScheme.secondary.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.secondary.withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility,
                                    size: 8,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    NumberFormatter.formatCompact(widget.supply.viewsCount),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Package Size (Matching ProductCard style)
                      if (widget.supply.package.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.supply.package,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
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
    );
  }
}