import 'package:flutter/material.dart';
import 'package:fieldawy_store/widgets/main_scaffold.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainScaffold(
      selectedIndex: 1, // Dashboard is at index 1 for distributors
      body: Center(
        child: Text('Dashboard Page'),
      ),
    );
  }
}
