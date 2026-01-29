import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/core/caching/image_cache_manager.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/services/distributor_analytics_service.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:collection/collection.dart'; 

class DistributorDetailsSheet {
  static Future<void> show(BuildContext context, String distributorId) async {
    // ignore: unused_local_variable
    final theme = Theme.of(context);
    DistributorModel? distributor;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      distributor = await _fetchDistributorDetails(distributorId);
    } catch (e) {
      debugPrint('Error fetching distributor details: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading

    if (distributor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('distributors_feature.products_screen.load_error'.tr())),
      );
      return;
    }

    showWithModel(context, distributor);
  }

  static void showWithModel(BuildContext context, DistributorModel distributor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DistributorDetailsContent(distributor: distributor),
    );
  }

  static Future<DistributorModel?> _fetchDistributorDetails(String id) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke('get-distributors');
      
      if (response.data != null) {
        final List<dynamic> data = response.data;
        final distributorData = data.firstWhereOrNull((d) => d['id'] == id);
        
        if (distributorData != null) {
          return DistributorModel.fromMap(Map<String, dynamic>.from(distributorData));
        }
      }
    } catch (e) {
      debugPrint('Error fetching distributor details: $e');
    }
    return null;
  }
}

class DistributorDetailsContent extends StatefulWidget {
  final DistributorModel distributor;

  const DistributorDetailsContent({Key? key, required this.distributor}) : super(key: key);

  @override
  State<DistributorDetailsContent> createState() => _DistributorDetailsContentState();
}

class _DistributorDetailsContentState extends State<DistributorDetailsContent> {
  late int _recommendationCount;

  late int _reportCount;
  late int _whatsappClicks;
  bool _hasRecommended = false;
  bool _hasReported = false;

  @override
  void initState() {
    super.initState();
    _recommendationCount = widget.distributor.recommendationCount;
    _reportCount = widget.distributor.reportCount;
    _whatsappClicks = widget.distributor.whatsappClicks;
    _checkInteractionStatus();
    _fetchFreshCounts(); 
  }

  Future<void> _fetchFreshCounts() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('recommendation_count, report_count, whatsapp_clicks')
          .eq('id', widget.distributor.id)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          _recommendationCount = response['recommendation_count'] ?? 0;
          _reportCount = response['report_count'] ?? 0;
          _whatsappClicks = response['whatsapp_clicks'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching fresh counts: $e');
    }
  }

  Future<void> _checkInteractionStatus() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'check_distributor_interaction',
        params: {'p_distributor_id': widget.distributor.id},
      );
      
      if (mounted && response != null) {
        setState(() {
          _hasRecommended = response['has_recommended'] ?? false;
          _hasReported = response['has_reported'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error checking interaction status: $e');
    }
  }

  Future<void> _toggleRecommendation() async {
    final wasRecommended = _hasRecommended;
    final wasReported = _hasReported;
    
    setState(() {
      if (wasRecommended) {
        _hasRecommended = false;
        _recommendationCount = (_recommendationCount > 0) ? _recommendationCount - 1 : 0;
      } else {
        _hasRecommended = true;
        _recommendationCount++;
        if (wasReported) {
          _hasReported = false;
          _reportCount = (_reportCount > 0) ? _reportCount - 1 : 0;
        }
      }
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'toggle_distributor_recommendation',
        params: {'p_distributor_id': widget.distributor.id},
      );
      
      if (response['success'] != true) throw Exception('Operation failed');
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasRecommended = wasRecommended;
          _hasReported = wasReported;
          if (wasRecommended) {
             _recommendationCount++; 
          } else {
             _recommendationCount--;
             if (wasReported) _reportCount++;
          }
        });
      }
    }
  }

  Future<void> _toggleReport() async {
    final wasRecommended = _hasRecommended;
    final wasReported = _hasReported;
    
    setState(() {
      if (wasReported) {
        _hasReported = false;
        _reportCount = (_reportCount > 0) ? _reportCount - 1 : 0;
      } else {
        _hasReported = true;
        _reportCount++;
        if (wasRecommended) {
          _hasRecommended = false;
          _recommendationCount = (_recommendationCount > 0) ? _recommendationCount - 1 : 0;
        }
      }
    });

    try {
       final response = await Supabase.instance.client.rpc(
        'toggle_distributor_report',
        params: {'p_distributor_id': widget.distributor.id},
      );
      
      if (response['success'] != true) throw Exception('Operation failed');
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasRecommended = wasRecommended;
          _hasReported = wasReported;
          if (wasReported) {
             _reportCount++; 
          } else {
             _reportCount--;
             if (wasRecommended) _recommendationCount++;
          }
        });
      }
    }
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final buttonColor = isActive ? color : theme.colorScheme.surfaceVariant;
    final iconColor = isActive ? Colors.white : theme.colorScheme.onSurfaceVariant;
    final textColor = isActive ? Colors.white : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? null : Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          boxShadow: isActive
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.2) : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailListTile(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distributor = widget.distributor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: distributor.photoURL != null && distributor.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: distributor.photoURL!,
                            cacheManager: CustomImageCacheManager(),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(child: ImageLoadingIndicator(size: 32)),
                            errorWidget: (context, url, error) => Icon(Icons.person_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
                          )
                        : Icon(Icons.person_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(FontAwesomeIcons.whatsapp, size: 12, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        '$_whatsappClicks ${context.locale.languageCode == 'ar' ? 'طلب او محادثة' : 'requests'}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  distributor.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (distributor.companyName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      distributor.companyName!,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                const SizedBox(height: 16),
                // === Interaction Buttons ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInteractionButton(
                      icon: Icons.thumb_up_rounded,
                      label: 'ترشيح',
                      count: _recommendationCount,
                      color: Colors.green,
                      isActive: _hasRecommended,
                      onTap: _toggleRecommendation,
                    ),
                    const SizedBox(width: 16),
                    _buildInteractionButton(
                      icon: Icons.report_problem_rounded,
                      label: 'إبلاغ',
                      count: _reportCount,
                      color: Colors.red,
                      isActive: _hasReported,
                      onTap: _toggleReport,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.2)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDetailListTile(Icons.inventory_2_rounded, 'distributors_feature.products_count'.tr(), 'distributors_feature.product_count_value'.tr(namedArgs: {'count': distributor.productCount.toString()})),
                _buildDetailListTile(Icons.business_rounded, 'distributors_feature.type'.tr(), distributor.distributorType == 'company' ? 'distributors_feature.company'.tr() : 'distributors_feature.individual'.tr()),
                if (distributor.distributionMethod != null)
                  _buildDetailListTile(
                    Icons.local_shipping_rounded,
                    'distributors_feature.distribution_method'.tr(),
                    distributor.distributionMethod == 'direct_distribution' ? 'distributors_feature.direct'.tr() : distributor.distributionMethod == 'order_delivery' ? 'distributors_feature.delivery'.tr() : 'distributors_feature.both'.tr(),
                  ),
                if (distributor.governorates != null && distributor.governorates!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.map_rounded, color: theme.colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Text('distributors_feature.coverage_areas'.tr(), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0, left: 56.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: distributor.governorates!.map((gov) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3))),
                                  child: Text(gov, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                )).toList(),
                              ),
                              if (distributor.centers != null && distributor.centers!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: distributor.centers!.map((center) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: theme.colorScheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3))),
                                    child: Text(center, style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (distributor.whatsappNumber != null && distributor.whatsappNumber!.isNotEmpty)
                  _buildDetailListTile(FontAwesomeIcons.whatsapp, 'distributors_feature.whatsapp'.tr(), distributor.whatsappNumber!),
              ],
            ),
          ),
          // Actions (View Products & WhatsApp)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => DistributorProductsScreen(distributor: distributor)));
                    },
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: Text('distributors_feature.view_products'.tr()),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await DistributorAnalyticsService.instance.openWhatsApp(context, distributor);
                    },
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}