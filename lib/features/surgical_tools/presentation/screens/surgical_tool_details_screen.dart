import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../comments/data/comments_repository.dart';
import '../../../comments/domain/comment_model.dart';
import '../../../products/domain/product_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributor_products_screen.dart';
import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:fieldawy_store/features/reviews/review_system.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:easy_localization/easy_localization.dart';


class SurgicalToolDetailsScreen extends ConsumerStatefulWidget {
  final ProductModel tool;

  const SurgicalToolDetailsScreen({
    super.key,
    required this.tool,
  });

  @override
  ConsumerState<SurgicalToolDetailsScreen> createState() =>
      _SurgicalToolDetailsScreenState();
}

class _SurgicalToolDetailsScreenState
    extends ConsumerState<SurgicalToolDetailsScreen> {
  final _commentsRepository = CommentsRepository();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAddingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isAddingComment = true);

    final comment = await _commentsRepository.addComment(
      itemId: widget.tool.id,
      commentText: _commentController.text,
      type: CommentType.surgicalTool,
    );

    setState(() => _isAddingComment = false);

    if (comment != null) {
      _commentController.clear();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('surgical_tools_feature.comments.add_success'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('surgical_tools_feature.comments.add_error'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('surgical_tools_feature.comments.delete_title'.tr()),
        content: Text('surgical_tools_feature.comments.delete_confirm'.tr()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('surgical_tools_feature.actions.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('surgical_tools_feature.actions.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _commentsRepository.deleteComment(
        commentId: commentId,
        type: CommentType.surgicalTool,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('surgical_tools_feature.comments.delete_success'.tr()),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showUserDetails(BuildContext context, WidgetRef ref, String userId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userModel = await ref.read(userRepositoryProvider).getUser(userId);
      
      if (context.mounted) {
        Navigator.pop(context);
        if (userModel != null) {
          _showUserBottomSheet(context, userModel);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('surgical_tools_feature.messages.user_load_error'.tr())),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('surgical_tools_feature.messages.generic_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    }
  }

  void _showUserBottomSheet(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    // ignore: unused_local_variable
    final isDoctor = user.role == 'doctor';
    final isDistributor = user.role == 'distributor' || user.role == 'company';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: user.photoUrl != null
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName ?? 'surgical_tools_feature.comments.user'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleLabel(user.role),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.2)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isDistributor && user.distributionMethod != null)
                    _buildDetailTile(
                      theme,
                      Icons.local_shipping,
                      'surgical_tools_feature.distributor.distribution_method'.tr(),
                      _getDistributionMethodLabel(user.distributionMethod!),
                    ),
                  if (user.governorates != null && user.governorates!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                isDistributor ? 'surgical_tools_feature.distributor.coverage_areas'.tr() : 'surgical_tools_feature.distributor.location'.tr(),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.governorates!.map((gov) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                              ),
                              child: Text(
                                gov,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )).toList(),
                          ),
                          if (user.centers != null && user.centers!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: user.centers!.map((center) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
                                ),
                                child: Text(
                                  center,
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (user.whatsappNumber != null && user.whatsappNumber!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(user.whatsappNumber!),
                        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                        label: Text('surgical_tools_feature.actions.contact_whatsapp'.tr(), style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (isDistributor) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          final distributor = DistributorModel(
                            id: user.id,
                            displayName: user.displayName ?? '',
                            photoURL: user.photoUrl,
                            email: user.email,
                            distributorType: user.role,
                            whatsappNumber: user.whatsappNumber,
                            governorates: user.governorates,
                            centers: user.centers,
                            distributionMethod: user.distributionMethod,
                          );
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DistributorProductsScreen(
                                distributor: distributor,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.inventory_2),
                        label: Text('surgical_tools_feature.actions.view_products'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(ThemeData theme, IconData icon, String title, String value) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
      title: Text(title, style: theme.textTheme.bodySmall),
      subtitle: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'doctor': return 'auth.role_veterinarian'.tr();
      case 'distributor': return 'auth.role_distributor'.tr();
      case 'company': return 'auth.role_company'.tr();
      default: return role;
    }
  }

  String _getDistributionMethodLabel(String method) {
    switch (method) {
      case 'direct_distribution': return 'auth.profile.distribution.direct_distribution'.tr();
      case 'order_delivery': return 'auth.profile.distribution.order_delivery'.tr();
      case 'both': return 'auth.profile.distribution.both_methods'.tr();
      default: return method;
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'https://wa.me/20$cleanPhone';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('surgical_tools_feature.messages.whatsapp_error'.tr())),
          );
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _showReportDialog(BuildContext context, WidgetRef ref, String reviewId) {
    final reasons = [
      'surgical_tools_feature.report.reasons.inappropriate'.tr(),
      'surgical_tools_feature.report.reasons.spam'.tr(),
      'surgical_tools_feature.report.reasons.misleading'.tr(),
      'surgical_tools_feature.report.reasons.harassment'.tr(),
      'surgical_tools_feature.report.reasons.other'.tr(),
    ];
    String selectedReason = reasons[0];
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag_rounded, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'surgical_tools_feature.report.title'.tr(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'surgical_tools_feature.report.subtitle'.tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reasons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final reason = reasons[index];
                    final isSelected = selectedReason == reason;
                    return RadioListTile<String>(
                      title: Text(
                        reason,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (value) => setState(() => selectedReason = value!),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'surgical_tools_feature.report.details_hint'.tr(),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('surgical_tools_feature.actions.cancel'.tr(), style: const TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('surgical_tools_feature.report.sending'.tr())),
                          );

                          final service = ref.read(reviewServiceProvider);
                          final result = await service.reportReview(
                            reviewId: reviewId,
                            reason: selectedReason,
                            description: descriptionController.text.trim().isEmpty 
                                ? null 
                                : descriptionController.text.trim(),
                          );

                          if (context.mounted) {
                             if (result['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('surgical_tools_feature.report.success'.tr()),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'surgical_tools_feature.report.error'.tr()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text('surgical_tools_feature.report.submit'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'جديد':
        return Colors.green;
      case 'مستعمل':
        return Colors.orange;
      case 'كسر زيرو':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'جديد':
        return Icons.new_releases_rounded;
      case 'مستعمل':
        return Icons.history_rounded;
      case 'كسر زيرو':
        return Icons.star_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.tool.activePrinciple;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          // ===== Header مع صورة الأداة =====
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // الصورة
                  CachedNetworkImage(
                    imageUrl: widget.tool.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(
                        Icons.medical_services_outlined,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // عنوان الأداة
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tool.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.tool.company != null &&
                            widget.tool.company!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.business_outlined,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.tool.company!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== المحتوى الرئيسي =====
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بطاقات الإحصائيات
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.attach_money,
                          label: 'surgical_tools_feature.fields.price'.tr(),
                          value:
                              '${widget.tool.price?.toStringAsFixed(0) ?? '0'} ${"EGP".tr()}',
                          color: Colors.green,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.visibility_outlined,
                          label: 'surgical_tools_feature.fields.views'.tr(),
                          value: '${widget.tool.views}',
                          color: Colors.blue,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<int>(
                          future: _commentsRepository.getCommentsCount(
                            itemId: widget.tool.id,
                            type: CommentType.surgicalTool,
                          ),
                          builder: (context, snapshot) {
                            return _buildStatCard(
                              icon: Icons.comment_outlined,
                              label: 'surgical_tools_feature.fields.comments'.tr(),
                              value: '${snapshot.data ?? 0}',
                              color: Colors.orange,
                              theme: theme,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // الحالة (إذا وجدت)
                if (status != null && status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'surgical_tools_feature.fields.status'.tr(namedArgs: {'status': status}),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // معلومات الأداة
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الشركة
                        if (widget.tool.company != null &&
                            widget.tool.company!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.business_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'surgical_tools_feature.fields.manufacturer'.tr(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.tool.company!,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Divider(height: 24),
                        ],

                        // الموزع
                        if (widget.tool.distributorId != null &&
                            widget.tool.distributorId!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.store_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'surgical_tools_feature.fields.distributor'.tr(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.tool.distributorId!,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Divider(height: 24),
                        ],

                        // الوصف
                        if (widget.tool.description != null &&
                            widget.tool.description!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'surgical_tools_feature.fields.description'.tr(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.tool.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'surgical_tools_feature.fields.additional_info'.tr(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'surgical_tools_feature.fields.default_description'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // قسم التعليقات
                _buildCommentsSection(theme),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header التعليقات
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.comment_bank_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'surgical_tools_feature.comments.title'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Input لإضافة تعليق
          _buildCommentInput(theme),

          const SizedBox(height: 16),

          // قائمة التعليقات (محددة بـ 5 تعليقات)
          StreamBuilder<List<Comment>>(
            stream: _commentsRepository.watchComments(
              itemId: widget.tool.id,
              type: CommentType.surgicalTool,
              limit: 5, // تحديد 5 تعليقات فقط
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'حدث خطأ في تحميل التعليقات',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'surgical_tools_feature.comments.no_comments'.tr(),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'surgical_tools_feature.comments.be_first'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return _buildCommentItem(comment, theme);
                },
              );
            },
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCommentInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar المستخدم
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Icon(
              Icons.person,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Input التعليق
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'surgical_tools_feature.comments.hint'.tr(),
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          // زر الإرسال
          _isAddingComment
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: _addComment,
                  icon: Icon(
                    Icons.send_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, ThemeData theme) {
    final currentUserId = _commentsRepository.currentUserId;
    final isOwner = currentUserId == comment.userId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        InkWell(
          onTap: () => _showUserDetails(context, ref, comment.userId),
          borderRadius: BorderRadius.circular(20),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            backgroundImage: comment.userPhotoUrl != null
                ? CachedNetworkImageProvider(comment.userPhotoUrl!)
                : null,
            child: comment.userPhotoUrl == null
                ? Text(
                    comment.userName?.substring(0, 1).toUpperCase() ?? '؟',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        // محتوى التعليق
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الاسم والوقت
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showUserDetails(context, ref, comment.userId),
                            child: Text(
                              comment.userName ?? 'مستخدم',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          comment.timeAgo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // نص التعليق
                    Text(
                      comment.commentText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOwner)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showReportDialog(context, ref, comment.id),
                    icon: Icon(Icons.flag_outlined, size: 14, color: Colors.grey[500]),
                    label: Text(
                      'surgical_tools_feature.actions.report'.tr(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // زر الحذف (للمستخدم فقط)
        if (isOwner)
          IconButton(
            onPressed: () => _deleteComment(comment.id),
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.red.withOpacity(0.7),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}
