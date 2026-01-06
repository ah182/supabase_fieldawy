import 'package:fieldawy_store/widgets/refreshable_error_widget.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/home/presentation/widgets/product_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
// ignore: unnecessary_import
import 'package:intl/intl.dart';

class DistributorSurgicalToolsScreen extends ConsumerStatefulWidget {
  final String distributorId;
  final String distributorName;

  const DistributorSurgicalToolsScreen({
    super.key,
    required this.distributorId,
    required this.distributorName,
  });

  @override
  ConsumerState<DistributorSurgicalToolsScreen> createState() => _DistributorSurgicalToolsScreenState();
}

class _DistributorSurgicalToolsScreenState extends ConsumerState<DistributorSurgicalToolsScreen> {
  late Future<List<Map<String, dynamic>>> _toolsFuture;

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  void _loadTools() {
    _toolsFuture = ref.read(productRepositoryProvider).getMySurgicalTools(widget.distributorId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'surgical_tools_feature.title'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.distributorName,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _toolsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return RefreshableErrorWidget(
              message: 'Error: ${snapshot.error}',
              onRetry: () {
                setState(() {
                  _loadTools();
                });
              },
            );
          }

          final tools = snapshot.data ?? [];

          if (tools.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined, size: 80, color: colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('surgical_tools_feature.empty.no_tools'.tr(), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadTools();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text('retry'.tr()),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _loadTools();
              });
              await _toolsFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                final surgicalTool = tool['surgical_tools'] as Map<String, dynamic>?;

                final id = tool['id'] ?? '';
                final toolName = surgicalTool?['tool_name'] ?? 'Unknown';
                final company = surgicalTool?['company'];
                final imageUrl = surgicalTool?['image_url'];
                final description = tool['description'] ?? '';
                final price = (tool['price'] as num?)?.toDouble() ?? 0.0;
                final status = tool['status'] ?? 'جديد';

                // Translate status for display
                String displayStatus = status;
                if (status == 'جديد') displayStatus = 'surgical_tools_feature.status.new'.tr();
                else if (status == 'مستعمل') displayStatus = 'surgical_tools_feature.status.used'.tr();
                else if (status == 'كسر زيرو') displayStatus = 'surgical_tools_feature.status.like_new'.tr();

                return _ModernToolCard(
                  id: id,
                  toolName: toolName,
                  company: company,
                  imageUrl: imageUrl,
                  description: description,
                  price: price,
                  status: status,
                  displayStatus: displayStatus,
                  index: index,
                  onTap: () {
                    // تحويل البيانات لنموذج ProductModel لعرض الديالوج
                    final toolModel = ProductModel(
                      id: id,
                      name: toolName,
                      imageUrl: imageUrl ?? '',
                      company: company,
                      description: description,
                      price: price,
                      distributorId: widget.distributorName,
                      distributorUuid: widget.distributorId,
                      availablePackages: [],
                      activePrinciple: status, // نستخدمه لحمل الحالة في هذا الديالوج
                    );
                    showSurgicalToolDialog(context, toolModel);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ModernToolCard extends StatelessWidget {
  final String id;
  final String toolName;
  final String? company;
  final String? imageUrl;
  final String description;
  final double price;
  final String status;
  final String displayStatus;
  final int index;
  final VoidCallback onTap;

  const _ModernToolCard({
    required this.id,
    required this.toolName,
    required this.company,
    required this.imageUrl,
    required this.description,
    required this.price,
    required this.status,
    required this.displayStatus,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.cardColor,
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.15),
        ),
        boxShadow: theme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const ShimmerLoader(width: 72, height: 72),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceVariant,
                            child: Icon(Icons.medical_services_outlined, color: colorScheme.onSurfaceVariant, size: 32),
                          ),
                        )
                      : Container(
                          color: colorScheme.surfaceVariant,
                          child: Icon(Icons.medical_services_outlined, color: colorScheme.onSurfaceVariant, size: 32),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toolName,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (company != null && company!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_rounded, size: 12, color: colorScheme.onTertiaryContainer),
                            const SizedBox(width: 4),
                            Text(
                              company!,
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(status), size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            displayStatus,
                            style: textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sell_outlined, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            '${NumberFormat('#,##0', 'en_US').format(price)} EGP',
                            style: textTheme.labelMedium?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (description.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline.withOpacity(0.1), width: 1),
                        ),
                        child: Text(
                          description,
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7), height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'جديد': return Colors.green;
      case 'مستعمل': return Colors.orange;
      case 'كسر زيرو': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'جديد': return Icons.new_releases_rounded;
      case 'مستعمل': return Icons.history_rounded;
      case 'كسر زيرو': return Icons.star_rounded;
      default: return Icons.info_rounded;
    }
  }
}
