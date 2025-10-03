import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_from_catalog_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:flutter/material.dart';

class LimitedOfferScreen extends StatelessWidget {
  const LimitedOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Limited Offer'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SimpleDialog(
                  title: Text('addProduct.limitedOffer.title'.tr()),
                  children: <Widget>[
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context); // Close the dialog
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddFromCatalogScreen()));
                      },
                      child: const Text('Add from Catalog'),
                    ),
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(context); // Close the dialog
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddProductOcrScreen()));
                      },
                      child: const Text('Add from your Gallery'),
                    ),
                  ],
                );
              },
            );
          },
          child: const Text('Add Limited Offer'),
        ),
      ),
    );
  }
}
