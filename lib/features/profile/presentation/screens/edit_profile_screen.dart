import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
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
  List<Governorate> _allGovernorateData = [];
  
  String? _selectedRole;
  String? _selectedDistributionMethod;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userModel.displayName);
    _phoneController =
        TextEditingController(text: widget.userModel.whatsappNumber);
    _governorates = widget.userModel.governorates ?? [];
    _centers = widget.userModel.centers ?? [];
    
    _selectedRole = widget.userModel.role;
    // نفترض أن المودل يحتوي على distributionMethod، إذا لم يكن كذلك سنحتاج لإضافته أو قراءته من map
    // سأستخدم map مؤقتاً إذا لم يكن في المودل، لكن بما أننا نستخدم UserModel، 
    // يجب أن يكون الحقل موجوداً في UserModel. 
    // إذا لم يكن موجوداً، سأحاول الحصول عليه بطريقة أخرى أو أتركه null
    // سأفترض وجوده كحقل إضافي في الخريطة إذا لم يكن في الكلاس الأساسي
    _selectedDistributionMethod = widget.userModel.distributionMethod;
    
    _loadGovernorateData();
  }

  Future<void> _loadGovernorateData() async {
    final String response =
        await rootBundle.loadString('assets/governorates.json');
    final List<dynamic> data = json.decode(response);
    if (mounted) {
      setState(() {
        _allGovernorateData =
            data.map((json) => Governorate.fromJson(json)).toList();
      });
    }
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
    
    // Group centers by governorate
    final Map<String, List<String>> centersByGovernorate = {};
    for (var govName in _governorates) {
      final govData = _allGovernorateData.firstWhere(
        (g) => g.name == govName,
        orElse: () => Governorate(id: 0, name: '', centers: []),
      );
      
      final govCenters = govData.centers
          .where((center) => _centers.contains(center))
          .toList();
          
      if (govCenters.isNotEmpty) {
        centersByGovernorate[govName] = govCenters;
      } else {
        // Include governorate even if no centers selected (just to show it)
        centersByGovernorate[govName] = []; 
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('profile_feature.edit.title'.tr()),
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
                              label: 'profile_feature.edit.name_label'.tr(),
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: _phoneController,
                              label: 'profile_feature.edit.whatsapp_label'.tr(),
                              icon: Icons.phone_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                      // Role Selection (Only for Company/Distributor)
                    if (widget.userModel.role == 'company' || widget.userModel.role == 'distributor') ...[
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('profile_feature.edit.account_type'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              _buildOptionCard(
                                title: 'profile_feature.roles.company'.tr(),
                                value: 'company',
                                groupValue: _selectedRole,
                                icon: Icons.business_rounded,
                                onChanged: (val) => setState(() => _selectedRole = val),
                              ),
                              const SizedBox(height: 8),
                              _buildOptionCard(
                                title: 'profile_feature.roles.distributor'.tr(),
                                value: 'distributor',
                                groupValue: _selectedRole,
                                icon: Icons.person_outline_rounded,
                                onChanged: (val) => setState(() => _selectedRole = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Distribution Method
                      if (_selectedRole == 'company' || _selectedRole == 'distributor')
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('profile_feature.edit.distribution_method'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                _buildOptionCard(
                                  title: 'profile_feature.distribution.direct'.tr(),
                                  value: 'direct_distribution',
                                  groupValue: _selectedDistributionMethod,
                                  icon: Icons.local_shipping_outlined,
                                  onChanged: (val) => setState(
                                      () => _selectedDistributionMethod = val),
                                ),
                                const SizedBox(height: 8),
                                _buildOptionCard(
                                  title: 'profile_feature.distribution.delivery'.tr(),
                                  value: 'order_delivery',
                                  groupValue: _selectedDistributionMethod,
                                  icon: Icons.shopping_bag_outlined,
                                  onChanged: (val) => setState(
                                      () => _selectedDistributionMethod = val),
                                ),
                                const SizedBox(height: 8),
                                _buildOptionCard(
                                  title: 'profile_feature.distribution.both'.tr(),
                                  value: 'both',
                                  groupValue: _selectedDistributionMethod,
                                  icon: Icons.all_inclusive_rounded,
                                  onChanged: (val) => setState(
                                      () => _selectedDistributionMethod = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],

                    _buildCoverageSection(context, centersByGovernorate),
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
                    role: _selectedRole,
                    distributionMethod: _selectedDistributionMethod,
                  );
              ref.invalidate(userDataProvider);
              Navigator.of(context).pop(); // Close the loading dialog
              Navigator.of(context).pop(); // Close the edit screen
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).primaryColor,
            foregroundColor: Theme.of(context).brightness == Brightness.dark 
                ? Theme.of(context).colorScheme.onPrimary 
                : Colors.white,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('profile_feature.edit.save'.tr(), 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildCoverageSection(BuildContext context, Map<String, List<String>> centersByGovernorate) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // ignore: unused_local_variable
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'profile_feature.edit.coverage_areas'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GovernorateSelectionScreen(
                          role: UserRoleHelper.fromString(widget.userModel.role),
                          initialGovernorates: _governorates,
                          initialCenters: _centers,
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
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: Text('profile_feature.edit.edit'.tr()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: (_governorates.isEmpty)
                ? _buildEmptyState(context)
                : Column(
                    children: centersByGovernorate.entries.map((entry) {
                      return _buildGovernorateItem(context, entry.key, entry.value);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'profile_feature.edit.tap_to_select'.tr(),
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernorateItem(BuildContext context, String govName, List<String> centers) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceVariant.withOpacity(0.2) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(Icons.location_city, size: 18, color: colorScheme.primary),
          title: Text(
            govName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${centers.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          children: [
            if (centers.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'profile_feature.edit.all_governorate'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: centers.map((center) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ),
          ],
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

  Widget _buildOptionCard({
    required String title,
    required String value,
    required String? groupValue,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? colorScheme.primary : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
