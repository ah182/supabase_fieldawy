import 'package:fieldawy_store/features/authentication/data/user_repository.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/features/authentication/domain/user_role.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/governorate_selection_screen.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserModel userModel;

  const EditProfileScreen({super.key, required this.userModel});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late List<String> _governorates;
  late List<String> _centers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userModel.displayName);
    _phoneController =
        TextEditingController(text: widget.userModel.whatsappNumber);
    _governorates = widget.userModel.governorates ?? [];
    _centers = widget.userModel.centers ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Edit Profile'),
            pinned: true,
            floating: true,
            backgroundColor: colorScheme.surface,
            elevation: 1,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInputField(
                              controller: _nameController,
                              label: 'Name',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: _phoneController,
                              label: 'WhatsApp Number',
                              icon: Icons.phone_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.map_outlined),
                        title: const Text('Governorates and Centers'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => GovernorateSelectionScreen(
                                role: UserRoleHelper.fromString(
                                    widget.userModel.role),
                                onContinue: (governorates, centers) {
                                  setState(() {
                                    _governorates = governorates;
                                    _centers = centers;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );
              await ref.read(userRepositoryProvider).updateUserProfile(
                    id: widget.userModel.id,
                    displayName: _nameController.text,
                    whatsappNumber: _phoneController.text,
                    governorates: _governorates,
                    centers: _centers,
                  );
              ref.invalidate(userDataProvider);
              Navigator.of(context).pop(); // Close the loading dialog
              Navigator.of(context).pop(); // Close the edit screen
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save'),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
