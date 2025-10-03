import 'package:fieldawy_store/features/products/presentation/screens/add_vet_tools_screen.dart';
import 'package:flutter/material.dart';

class SurgicalToolsScreen extends StatelessWidget {
  const SurgicalToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Surgical Tools'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddVetToolsScreen()));
          },
          child: const Text('Add Surgical Tool'),
        ),
      ),
    );
  }
}
