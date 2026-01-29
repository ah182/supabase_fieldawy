import 'package:fieldawy_store/features/distributors/domain/distributor_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class DistributorAnalyticsService {
  DistributorAnalyticsService._();
  static final DistributorAnalyticsService instance = DistributorAnalyticsService._();

  Future<void> openWhatsApp(BuildContext context, DistributorModel distributor, {String? message}) async {
    final phoneNumber = distributor.whatsappNumber;

    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('distributors_feature.phone_not_available'.tr()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // Track the click in the background
    _trackWhatsAppClick(distributor.id);

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final msg = Uri.encodeComponent(message ?? 'distributors_feature.whatsapp_inquiry'.tr());
    final whatsappUrl = 'https://wa.me/20$cleanPhone?text=$msg';

    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('distributors_feature.whatsapp_error'.tr()),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(label: 'distributors_feature.ok'.tr(), onPressed: () {}),
          ),
        );
      }
    }
  }

  Future<void> _trackWhatsAppClick(String distributorId) async {
    try {
      await Supabase.instance.client.rpc(
        'increment_distributor_whatsapp_clicks',
        params: {'distributor_id': distributorId},
      );
    } catch (e) {
      debugPrint('Error tracking WhatsApp click: $e');
    }
  }
}
