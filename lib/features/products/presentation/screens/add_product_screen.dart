import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/presentation/screens/expire_drugs_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/limited_offer_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/surgical_tools_screen.dart';
import 'package:flutter/material.dart';

class AddProductScreen extends StatelessWidget {
  const AddProductScreen({super.key});

  static const routeName = '/add-product'; // Optional: for named routes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('addProduct.title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _OptionCard(
            icon: Icons.warning_amber_rounded,
            title: 'addProduct.expireSoon.title'.tr(),
            subtitle: 'addProduct.expireSoon.subtitle'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ExpireDrugsScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.local_offer_rounded,
            title: 'addProduct.limitedOffer.title'.tr(),
            subtitle: 'addProduct.limitedOffer.subtitle'.tr(),
           onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LimitedOfferScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.medical_services_rounded,
            title: 'addProduct.surgical.title'.tr(),
            subtitle: 'addProduct.surgical.subtitle'.tr(),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SurgicalToolsScreen()));
            },
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.campaign_rounded,
            title: 'addProduct.limitedAds.title'.tr(),
            subtitle: 'addProduct.limitedAds.subtitle'.tr(),
            onTap: () {
              // TODO: Navigate to the correct screen
            },
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded),
        onTap: onTap,
      ),
    );
  }
}
