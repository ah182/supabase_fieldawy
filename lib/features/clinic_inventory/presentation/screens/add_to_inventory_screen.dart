import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../../data/models/clinic_inventory_item.dart';
import '../../data/services/clinic_inventory_service.dart';

/// شاشة إضافة منتج للجرد
class AddToInventoryScreen extends ConsumerStatefulWidget {
  final String? productName;
  final String? package;
  final String? company;
  final String? imageUrl;
  final String sourceType;
  final String? sourceProductId;
  final String? sourceOcrProductId;
  final double? suggestedUnitSize;
  final ClinicInventoryItem? itemToEdit;

  const AddToInventoryScreen({
    super.key,
    this.productName,
    this.package,
    this.company,
    this.imageUrl,
    this.sourceType = 'manual',
    this.sourceProductId,
    this.sourceOcrProductId,
    this.suggestedUnitSize,
    this.itemToEdit,
  });

  @override
  ConsumerState<AddToInventoryScreen> createState() =>
      _AddToInventoryScreenState();
}

class _AddToInventoryScreenState extends ConsumerState<AddToInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _packageController = TextEditingController();
  final _companyController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _purchasePriceController = TextEditingController();
  final _unitSizeController = TextEditingController();
  final _minStockController = TextEditingController(text: '3');
  final _notesController = TextEditingController();

  DateTime? _expiryDate;
  String _unitType = 'box';
  String _packageType = 'box'; // نوع العبوة (علبة، زجاجة، فيال...)
  bool _isSaving = false;
  String? _fetchedImageUrl;
  Timer? _debounce;

  final List<String> _packageTypes = [
    'box',
    'bottle',
    'vial',
    'ampoule',
    'tube',
    'strip',
    'sachet',
    'can',
    'jar',
    'bag'
  ];

  String _translatePackageType(String type) {
    final isArabic = context.locale.languageCode == 'ar';
    switch (type) {
      case 'box':
        return isArabic ? 'علبة' : 'Box';
      case 'bottle':
        return isArabic ? 'زجاجة' : 'Bottle';
      case 'vial':
        return isArabic ? 'فيال' : 'Vial';
      case 'ampoule':
        return isArabic ? 'أمبول' : 'Ampoule';
      case 'tube':
        return isArabic ? 'أنبوب' : 'Tube';
      case 'strip':
        return isArabic ? 'شريط' : 'Strip';
      case 'sachet':
        return isArabic ? 'كيس' : 'Sachet';
      case 'can':
        return isArabic ? 'علبة' : 'Can';
      case 'jar':
        return isArabic ? 'برطمان' : 'Jar';
      case 'bag':
        return isArabic ? 'كيس' : 'Bag';
      default:
        return type;
    }
  }

  @override
  @override
  void initState() {
    super.initState();

    // في حالة التعديل
    if (widget.itemToEdit != null) {
      final i = widget.itemToEdit!;
      _nameController.text = i.productName;
      _packageController.text = i.package;
      _companyController.text = i.company ?? '';
      _quantityController.text = i.quantity.toString();
      _purchasePriceController.text = i.purchasePrice.toString();
      _unitSizeController.text = i.unitSize.toString();
      _unitSizeController.text = i.unitSize.toString();
      _unitType = i.unitType;
      _packageType = i.packageType;
      _minStockController.text = i.minStock.toString();
      _notesController.text = i.notes ?? '';
      _notesController.text = i.notes ?? '';
      _expiryDate = i.expiryDate;
      _fetchedImageUrl = i.imageUrl;
    } else {
      // ملء البيانات المبدئية للإضافة الجديدة
      if (widget.productName != null) {
        _nameController.text = widget.productName!;
      }
      if (widget.package != null) {
        _packageController.text = widget.package!;
        // محاولة استخراج حجم الوحدة من العبوة
        _extractUnitSize(widget.package!);
      }
      if (widget.company != null) {
        _companyController.text = widget.company!;
      }
      if (widget.suggestedUnitSize != null) {
        _unitSizeController.text = widget.suggestedUnitSize!.toString();
      }
    }

    // استماع للتغييرات في حقل العبوة لاستخراج حجم الوحدة ونوع العبوة تلقائياً
    _packageController.addListener(() {
      _extractUnitSize(_packageController.text);
      _extractPackageType(_packageController.text);
    });

    // استماع لتغيير الاسم للبحث عن الصورة تلقائياً (فقط في الإضافة اليدوية)
    if (widget.itemToEdit == null) {
      _fetchedImageUrl = widget.imageUrl; // Start with passed image if any
      _nameController.addListener(_onNameChanged);
    }
  }

  void _onNameChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final name = _nameController.text;
      if (name.trim().length > 2) {
        final img = await ref
            .read(clinicInventoryServiceProvider)
            .findProductImageByName(name);
        if (img != null && mounted) {
          setState(() {
            _fetchedImageUrl = img;
          });
        }
      }
    });
  }

  void _extractPackageType(String package) {
    if (package.isEmpty) return;
    final lower = package.toLowerCase();

    // البحث عن كلمات مفتاحية لنوع العبوة
    for (final type in _packageTypes) {
      // تجاهل 'box' لأنه الافتراضي ولتجنب التطابق الخاطئ
      if (type == 'box') continue;

      // الكلمات المفتاحية البديلة (مثلاً tabs قد تعني strip أو box)
      if (lower.contains(type)) {
        setState(() => _packageType = type);
        return;
      }
    }

    // معالجة خاصة لبعض الكلمات
    if (lower.contains('tab') || lower.contains('cap')) {
      // الحبوب غالباً شرائط أو علب، نتركها box افتراضياً أو strip لو ذكرت
      if (lower.contains('strip')) setState(() => _packageType = 'strip');
    }
  }

  void _extractUnitSize(String package) {
    if (package.isEmpty) return;

    // محاولة استخراج الرقم من العبوة (مثل 100ml, 500g)
    final regex = RegExp(
        r'(\d+(?:\.\d+)?)\s*(ml|g|gram|gm|kg|l|piece|pcs|tabs?|caps?|amp|vials?)?',
        caseSensitive: false);
    final match = regex.firstMatch(package);

    if (match != null) {
      final size = match.group(1) ?? '';
      _unitSizeController.text = size;

      final unit = match.group(2)?.toLowerCase();
      if (unit != null) {
        if (unit.contains('ml') || unit.contains('l')) {
          _unitType = 'ml';
        } else if (unit.contains('g') || unit.contains('kg')) {
          _unitType = 'gram';
        } else if (unit.contains('tab') || unit.contains('cap')) {
          _unitType = 'box'; // عادة الحبوب تباع بالعلبة كوحدة كبرى
        } else if (unit.contains('amp')) {
          _unitType = 'ampoule';
        } else {
          _unitType = 'piece';
        }
        setState(() {}); // لتحديث الحالة (رغم عدم وجود UI، مفيد للتأكد)
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageController.dispose();
    _companyController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _unitSizeController.dispose();
    _minStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showMonthPicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        // آخر يوم في الشهر
        _expiryDate = DateTime(picked.year, picked.month + 1, 0);
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(clinicInventoryServiceProvider);

      if (widget.itemToEdit != null) {
        await service.updateInventoryItem(
          id: widget.itemToEdit!.id,
          productName: _nameController.text.trim(),
          package: _packageController.text.trim(),
          company: _companyController.text.trim().isNotEmpty
              ? _companyController.text.trim()
              : null,
          imageUrl: _fetchedImageUrl ?? widget.imageUrl,
          quantity: int.parse(_quantityController.text),
          purchasePrice: double.parse(_purchasePriceController.text),
          unitSize: _unitSizeController.text.isNotEmpty
              ? double.parse(_unitSizeController.text)
              : 1,
          unitType: _unitType,
          packageType: _packageType,
          minStock: int.parse(_minStockController.text),
          expiryDate: _expiryDate,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      } else {
        await service.addInventoryItem(
          productName: _nameController.text.trim(),
          package: _packageController.text.trim(),
          company: _companyController.text.trim().isNotEmpty
              ? _companyController.text.trim()
              : null,
          imageUrl: _fetchedImageUrl ?? widget.imageUrl,
          quantity: int.parse(_quantityController.text),
          purchasePrice: double.parse(_purchasePriceController.text),
          unitSize: _unitSizeController.text.isNotEmpty
              ? double.parse(_unitSizeController.text)
              : 1,
          unitType: _unitType,
          packageType: _packageType,
          minStock: int.parse(_minStockController.text),
          expiryDate: _expiryDate,
          sourceType: widget.sourceType,
          sourceProductId: widget.sourceProductId,
          sourceOcrProductId: widget.sourceOcrProductId,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      }

      if (mounted) {
        final isArabic = context.locale.languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(widget.itemToEdit != null
                    ? (isArabic
                        ? 'تم تعديل ${_nameController.text} بنجاح'
                        : 'Updated ${_nameController.text} successfully')
                    : (isArabic
                        ? 'تمت إضافة ${_nameController.text} للجرد'
                        : 'Added ${_nameController.text} successfully')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final isArabic = context.locale.languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'حدث خطأ: $e' : 'Error occurred: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إضافة للجرد' : 'Add to Inventory'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات المنتج
              _buildSectionHeader(
                  theme,
                  isArabic ? 'معلومات المنتج' : 'Product Info',
                  CachedNetworkImage(
                    imageUrl:
                        'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Prescription-Bottle-Medical-icon.png',
                    width: 20,
                    height: 20,
                    color: colorScheme.primary,
                    placeholder: (context, url) => Icon(
                        Icons.medication_outlined,
                        color: colorScheme.primary,
                        size: 20),
                    errorWidget: (context, url, error) => Icon(
                        Icons.medication_outlined,
                        color: colorScheme.primary,
                        size: 20),
                  )),
              const SizedBox(height: 16),

              if (_fetchedImageUrl != null && _fetchedImageUrl!.isNotEmpty) ...[
                Center(
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _fetchedImageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.medication_outlined),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم الدواء *' : 'Medicine Name *',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Prescription-Bottle-Medical-icon.png',
                      width: 20,
                      height: 20,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      placeholder: (context, url) =>
                          const Icon(Icons.medication_outlined),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.medication_outlined),
                    ),
                  ),
                ),
                validator: (v) => v?.trim().isEmpty == true
                    ? (isArabic ? 'مطلوب' : 'Required')
                    : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _packageController,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'العبوة *' : 'Package *',
                        hintText: isArabic ? 'مثال: 100ml' : 'Ex: 100ml',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Box-icon.png',
                            width: 20,
                            height: 20,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            placeholder: (context, url) =>
                                const Icon(Icons.inventory_2_outlined),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.inventory_2_outlined),
                          ),
                        ),
                      ),
                      validator: (v) => v?.trim().isEmpty == true
                          ? (isArabic ? 'مطلوب' : 'Required')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _companyController,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الشركة' : 'Company',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Building-icon.png',
                            width: 20,
                            height: 20,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            placeholder: (context, url) =>
                                const Icon(Icons.business_outlined),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.business_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // الكمية والسعر
              _buildSectionHeader(
                  theme,
                  isArabic ? 'الكمية والسعر' : 'Qty & Price',
                  CachedNetworkImage(
                    imageUrl:
                        'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Cart-Shopping-icon.png',
                    width: 20,
                    height: 20,
                    color: colorScheme.primary,
                    placeholder: (context, url) => Icon(
                        Icons.shopping_cart_outlined,
                        color: colorScheme.primary,
                        size: 20),
                    errorWidget: (context, url, error) => Icon(
                        Icons.shopping_cart_outlined,
                        color: colorScheme.primary,
                        size: 20),
                  )),
              const SizedBox(height: 16),

              // صف نوع العبوة والكمية والسعر
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // نوع العبوة
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _packageType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'نوع العبوة' : 'Type',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Layer-Group-icon.png',
                            width: 20,
                            height: 20,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            placeholder: (context, url) =>
                                const Icon(Icons.category_outlined),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.category_outlined),
                          ),
                        ),
                      ),
                      items: _packageTypes.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(_translatePackageType(t)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _packageType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // الكمية
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: isArabic
                            ? 'العدد (${_translatePackageType(_packageType)}) *'
                            : 'Count (${_translatePackageType(_packageType)}) *',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Plus-icon.png',
                            width: 20,
                            height: 20,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            placeholder: (context, url) =>
                                const Icon(Icons.add_box_outlined),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.add_box_outlined),
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v?.trim().isEmpty == true) {
                          return isArabic ? 'مطلوب' : 'Required';
                        }
                        if (int.tryParse(v!) == null || int.parse(v) <= 0) {
                          return isArabic ? 'أدخل رقم' : 'Enter number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // السعر
              TextFormField(
                controller: _purchasePriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isArabic ? 'سعر الشراء *' : 'Purchase Price *',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Money-Bill-icon.png',
                      width: 20,
                      height: 20,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      placeholder: (context, url) =>
                          const Icon(Icons.attach_money_rounded),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  suffixText: isArabic ? 'ج' : 'EGP',
                ),
                validator: (v) {
                  if (v?.trim().isEmpty == true) {
                    return isArabic ? 'مطلوب' : 'Required';
                  }
                  if (double.tryParse(v!) == null || double.parse(v) <= 0) {
                    return isArabic ? 'أدخل سعر صحيح' : 'Enter valid price';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // تم إخفاء حقل حجم الوحدة والنوع لأنه يتم استنتاجه تلقائياً من العبوة
              const SizedBox.shrink(),

              const SizedBox(height: 32),

              // الصلاحية والحد الأدنى
              _buildSectionHeader(
                  theme,
                  isArabic ? 'إعدادات إضافية' : 'Additional Settings',
                  CachedNetworkImage(
                    imageUrl:
                        'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Gears-icon.png',
                    width: 20,
                    height: 20,
                    color: colorScheme.primary,
                    placeholder: (context, url) => Icon(Icons.settings_outlined,
                        color: colorScheme.primary, size: 20),
                    errorWidget: (context, url, error) => Icon(
                        Icons.settings_outlined,
                        color: colorScheme.primary,
                        size: 20),
                  )),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectExpiryDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText:
                              isArabic ? 'تاريخ الانتهاء' : 'Expiry Date',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Calendar-Days-icon.png',
                              width: 20,
                              height: 20,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              placeholder: (context, url) =>
                                  const Icon(Icons.calendar_month_outlined),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                        ),
                        child: Text(
                          _expiryDate != null
                              ? '${_expiryDate!.month}/${_expiryDate!.year}'
                              : (isArabic ? 'اختر الشهر' : 'Select Month'),
                          style: TextStyle(
                            color: _expiryDate != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: isArabic ? 'حد التنبيه' : 'Alert Limit',
                        hintText: isArabic ? 'عدد العلب' : 'Count',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Triangle-Exclamation-icon.png',
                            width: 20,
                            height: 20,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            placeholder: (context, url) =>
                                const Icon(Icons.warning_amber_outlined),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.warning_amber_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isArabic ? 'ملاحظات' : 'Notes',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Note-Sticky-icon.png',
                      width: 20,
                      height: 20,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      placeholder: (context, url) =>
                          const Icon(Icons.note_outlined),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.note_outlined),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveItem,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : CachedNetworkImage(
                          imageUrl:
                              'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Plus-icon.png',
                          width: 24,
                          height: 24,
                          color: Colors.white,
                          placeholder: (context, url) => const Icon(
                              Icons.add_rounded,
                              color: Colors.white),
                          errorWidget: (context, url, error) => const Icon(
                              Icons.add_rounded,
                              color: Colors.white),
                        ),
                  label: Text(
                    _isSaving
                        ? (isArabic ? 'جاري الحفظ...' : 'Saving...')
                        : (isArabic ? 'إضافة للجرد' : 'Add'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, Widget icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: icon,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
