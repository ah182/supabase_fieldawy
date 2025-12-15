import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:easy_localization/easy_localization.dart';

class EditSurgicalToolScreen extends ConsumerStatefulWidget {
  final String id;
  final String toolName;
  final String? company;
  final String? imageUrl;
  final String initialDescription;
  final double initialPrice;
  final String initialStatus;

  const EditSurgicalToolScreen({
    super.key,
    required this.id,
    required this.toolName,
    required this.company,
    required this.imageUrl,
    required this.initialDescription,
    required this.initialPrice,
    required this.initialStatus,
  });

  @override
  ConsumerState<EditSurgicalToolScreen> createState() => _EditSurgicalToolScreenState();
}

class _EditSurgicalToolScreenState extends ConsumerState<EditSurgicalToolScreen> {
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late String _selectedStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _priceController = TextEditingController(text: widget.initialPrice.toString());
    _selectedStatus = widget.initialStatus;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  Future<void> _updateTool() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(productRepositoryProvider).updateDistributorSurgicalTool(
            id: widget.id,
            description: _descriptionController.text.trim(),
            price: double.parse(_priceController.text),
            status: _selectedStatus,
          );

      setState(() => _isLoading = false);
      if (success) {
        _showSnackBar('surgical_tools_feature.messages.update_success'.tr(), isError: false);
        Navigator.pop(context, true); // إرجاع true للإشارة إلى نجاح التحديث
      } else {
        _showSnackBar('surgical_tools_feature.messages.update_error'.tr(), isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('surgical_tools_feature.messages.generic_error'.tr(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('surgical_tools_feature.edit.title'.tr()),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // صورة الأداة
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.medical_services_outlined,
                            size: 80,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.medical_services_outlined,
                          size: 80,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // اسم الأداة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'surgical_tools_feature.fields.tool_name'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.toolName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // اسم الشركة
              if (widget.company != null && widget.company!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        color: colorScheme.onTertiaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'surgical_tools_feature.fields.manufacturer'.tr(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.company!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // حقل الوصف
              Text(
                'surgical_tools_feature.fields.description'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: null,
                decoration: InputDecoration(
                  hintText: 'surgical_tools_feature.fields.description_hint'.tr(),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.error,
                    ),
                  ),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'surgical_tools_feature.fields.description_required'.tr();
                  }
                  final wordCount = _countWords(value);
                  if (wordCount > 60) {
                    return 'surgical_tools_feature.fields.description_limit_error'.tr(namedArgs: {'count': wordCount.toString()});
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // لتحديث عداد الكلمات
                },
              ),
              const SizedBox(height: 8),
              // عداد الكلمات
              Builder(
                builder: (context) {
                  final wordCount = _countWords(_descriptionController.text);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'surgical_tools_feature.fields.word_count'.tr(namedArgs: {'count': wordCount.toString()}),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: wordCount > 60
                              ? colorScheme.error
                              : colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        '$wordCount / 60',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: wordCount > 60
                              ? colorScheme.error
                              : colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // حالة الأداة
              Text(
                'surgical_tools_feature.fields.status_label'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                  ),
                ),
                items: ['جديد', 'مستعمل', 'كسر زيرو'].map((String status) {
                  String label = status;
                  if (status == 'جديد') label = 'surgical_tools_feature.status.new'.tr();
                  else if (status == 'مستعمل') label = 'surgical_tools_feature.status.used'.tr();
                  else if (status == 'كسر زيرو') label = 'surgical_tools_feature.status.like_new'.tr();
                  
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedStatus = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // حقل السعر
              Text(
                'surgical_tools_feature.fields.price'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  hintText: 'surgical_tools_feature.fields.price_hint'.tr(),
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: colorScheme.primary,
                  ),
                  suffixText: 'EGP'.tr(),
                  suffixStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.error,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'surgical_tools_feature.fields.price_required'.tr();
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'surgical_tools_feature.fields.price_invalid'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // زر التحديث
              ElevatedButton(
                onPressed: _isLoading ? null : _updateTool,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'surgical_tools_feature.actions.save_changes'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
}
