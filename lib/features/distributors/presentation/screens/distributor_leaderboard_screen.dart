// ignore_for_file: unused_import

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/services/distributor_analytics_service.dart';
import 'package:fieldawy_store/widgets/distributor_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DistributorLeaderboardScreen extends StatefulWidget {
  const DistributorLeaderboardScreen({super.key});

  @override
  State<DistributorLeaderboardScreen> createState() =>
      _DistributorLeaderboardScreenState();
}

class _DistributorLeaderboardScreenState
    extends State<DistributorLeaderboardScreen> {
  bool _isLoading = true;
  List<DistributorModel> _distributors = [];
  List<DistributorModel> _filteredDistributors = [];
  String? _errorMessage;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterDistributors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDistributors = List.from(_distributors);
      } else {
        _filteredDistributors = _distributors
            .where((d) =>
                d.displayName.toLowerCase().contains(query.toLowerCase()) ||
                (d.companyName?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select()
          .or('role.eq.distributor,role.eq.company')
          .order('whatsapp_clicks', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _distributors = (response as List)
              .map((data) => DistributorModel.fromMap(data))
              .toList();
          _filteredDistributors = List.from(_distributors); // Initialize filtered list
          _isLoading = false;
        });
        
        // Apply current filter if any
        if (_searchController.text.isNotEmpty) {
          _filterDistributors(_searchController.text);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final isAr = context.locale.languageCode == 'ar';
    return Scaffold( 
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: NestedScrollView(
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
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              automaticallyImplyLeading: false, 
              title: Text(
                isAr ? 'ترتيب الموزعين' : 'Distributor Leaderboard',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: _fetchLeaderboard,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(110), 
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) {
                          setState(() {
                             _isSearching = value.isNotEmpty;
                          });
                          _filterDistributors(value);
                        },
                        decoration: InputDecoration(
                          hintText: isAr ? 'بحث عن موزع...' : 'Search for distributor...',
                          hintStyle: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _isSearching = false;
                                    });
                                    _filterDistributors('');
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
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isAr ? 'حدث خطأ في التحميل' : 'Error loading leaderboard',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _fetchLeaderboard,
                          child: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredDistributors.isEmpty
                    ? Center(child: Text(_isSearching 
                        ? (isAr ? 'لا توجد نتائج' : 'No results found') 
                        : (isAr ? 'لا يوجد موزعين' : 'No distributors found')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredDistributors.length,
                        itemBuilder: (context, index) {
                          final distributor = _filteredDistributors[index];
                          final rank = index + 1;
                          
                          return _buildDistributorListItem(context, distributor, rank, isAr);
                        },
      ),
      ),
      ),
    );
  }

  Widget _buildDistributorListItem(BuildContext context, DistributorModel distributor, int rank, bool isAr) {
    final theme = Theme.of(context);
    
    // Determine border color based on rank
    Color? borderColor;
    if (rank == 1) {
      borderColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      borderColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      borderColor = const Color(0xFFCD7F32); // Bronze
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: (borderColor ?? Colors.black).withOpacity(borderColor != null ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#$rank',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: borderColor ?? theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 16),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: distributor.photoURL != null
                      ? CachedNetworkImageProvider(distributor.photoURL!)
                      : null,
                  child: distributor.photoURL == null
                      ? Icon(Icons.person, size: 20, color: theme.colorScheme.onSurfaceVariant)
                      : null,
                ),
                if (rank <= 3)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Icon(
                      FontAwesomeIcons.crown,
                      color: borderColor,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ],
        ),
        title: Text(
          distributor.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             if (distributor.companyName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  distributor.companyName!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (distributor.role != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: distributor.role == 'company' 
                          ? Colors.purple.withOpacity(0.1) 
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      distributor.role == 'company' ? (isAr ? 'شركة' : 'Company') : (isAr ? 'موزع' : 'Distributor'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: distributor.role == 'company' ? Colors.purple : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.whatsapp, size: 10, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${distributor.whatsappClicks} ${isAr ? 'طلب او محادثة' : 'requests'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded, 
          size: 16, 
          color: theme.colorScheme.onSurface.withOpacity(0.3)
        ),
        onTap: () => DistributorDetailsSheet.showWithModel(context, distributor),
      ),
    );
  }
} // End of class

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
    
    // Draw simple arrow pointing left
    path.moveTo(size.width * 0.6, size.height * 0.2); // Top right start
    path.lineTo(size.width * 0.3, size.height * 0.5); // Middle left point
    path.lineTo(size.width * 0.6, size.height * 0.8); // Bottom right end

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowBackPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
