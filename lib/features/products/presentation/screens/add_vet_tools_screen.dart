import 'package:flutter/material.dart';

class AddVetToolsScreen extends StatelessWidget {
  const AddVetToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vet Tools'),
      ),
      body: const Center(
        child: Text('This is the Add Vet Tools Screen'),
      ),
    );
  }
}
