import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/products/presentation/screens/offer_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // إضافة مكتبة الصور
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
// ignore: unused_import
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:fieldawy_store/services/cloudinary_service.dart';
import 'package:fieldawy_store/services/smart_image_service.dart';
// ignore: unnecessary_import
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

class AddProductOcrScreen extends ConsumerStatefulWidget {
  final bool showExpirationDate;
  final bool isFromOfferScreen;
  final bool isFromSurgicalTools;
  final bool isFromReviewRequest;
  final ProductModel? productToEdit; // Added parameter

  const AddProductOcrScreen({
    super.key,
    this.showExpirationDate = true,
    this.isFromOfferScreen = false,
    this.isFromSurgicalTools = false,
    this.isFromReviewRequest = false,
    this.productToEdit, // Initialize
  });

  @override
  ConsumerState<AddProductOcrScreen> createState() =>
      _AddProductOcrScreenState();
}

class _AddProductOcrScreenState extends ConsumerState<AddProductOcrScreen> {
  File? _originalImage;
  Uint8List? _processedImageBytes;
  File? _processedImageFile;
  String? _existingImageUrl; // To hold existing image URL

  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isFormValid = false;

  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _activePrincipleController = TextEditingController();
  final _priceController = TextEditingController();
  final _packageController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _packageFocusNode = FocusNode(); // جديد

  final List<String> _packageTypes = [
    'bottle',
    'vial',
    'tab',
    'amp',
    'sachet',
    'strip',
    'cream',
    'gel',
    'spray',
    'drops',
    'syringe',
    'powder',
  ];
  String? _selectedPackageType;
  final List<String> _statusKeys = ['جديد', 'مستعمل', 'كسر زيرو'];
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    
    // مستمع لتنظيف حقل العبوة عند فقدان التركيز
    _packageFocusNode.addListener(() {
      if (!_packageFocusNode.hasFocus) {
        _cleanupPackageField();
      }
    });

    if (widget.productToEdit != null) {
      _initializeForEdit();
    }

    // Initialize _selectedStatus with the key
    _selectedStatus = _statusKeys[0];

    // Show instructions dialog when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInstructionsDialog();
    });

    _nameController.addListener(_validateForm);
    _companyController.addListener(_validateForm);
    _activePrincipleController.addListener(_validateForm);
    _priceController.addListener(_validateForm);
    _packageController.addListener(_validateForm);
    _expirationDateController.addListener(_validateForm);
    _descriptionController.addListener(_validateForm);
  }

  // دالة ذكية لاستخراج حجم العبوة فقط
  void _cleanupPackageField() {
    final text = _packageController.text.trim();
    if (text.isEmpty) return;

    final regex = RegExp(
      r'(\d+(?:\.\d+)?\s*(?:ml|mg|g|kg|l|tab|caps|cap|piece|pcs))',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      setState(() {
        _packageController.text = match.group(0)!.toLowerCase();
      });
    }
  }

  Future<void> _showInstructionsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ocr.instructions_title'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ocr.instruction_1'.tr()),
            const SizedBox(height: 8),
            Text('ocr.instruction_2'.tr()),
            const SizedBox(height: 8),
            Text('ocr.instruction_3'.tr()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ocr.got_it'.tr()),
          ),
        ],
      ),
    );
  }

  void _initializeForEdit() {
    final product = widget.productToEdit!;
    _nameController.text = product.name;
    _companyController.text = product.company ?? '';
    _activePrincipleController.text = product.activePrinciple ?? '';
    _existingImageUrl = product.imageUrl;
    
    // Try to parse package
    final package = product.package ?? '';
    String foundType = '';
    for (final type in _packageTypes) {
      if (package.toLowerCase().contains(type)) {
        foundType = type;
        break;
      }
    }
    if (foundType.isNotEmpty) {
      _selectedPackageType = foundType;
      _packageController.text = package.replaceAll(foundType, '').trim();
    } else {
      _packageController.text = package;
    }
    
    // Trigger validation initially
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateForm());
  }

  void _validateForm() {
    bool isValid;
    final hasImage = _processedImageBytes != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    if (widget.isFromReviewRequest) {
      isValid = hasImage &&
          _nameController.text.isNotEmpty &&
          _companyController.text.isNotEmpty &&
          _activePrincipleController.text.isNotEmpty;
    } else if (widget.isFromSurgicalTools) {
      isValid = hasImage &&
          _nameController.text.isNotEmpty &&
          _priceController.text.isNotEmpty &&
          _descriptionController.text.isNotEmpty;
    } else if (widget.productToEdit != null) {
       // For editing, price and expiration date are hidden, so we don't validate them.
       isValid = hasImage &&
          _nameController.text.isNotEmpty &&
          _companyController.text.isNotEmpty &&
          _activePrincipleController.text.isNotEmpty &&
          _packageController.text.isNotEmpty &&
          _selectedPackageType != null;
    } else {
      isValid = hasImage &&
          _nameController.text.isNotEmpty &&
          _companyController.text.isNotEmpty &&
          _activePrincipleController.text.isNotEmpty &&
          _priceController.text.isNotEmpty &&
          _packageController.text.isNotEmpty &&
          _selectedPackageType != null &&
          (widget.showExpirationDate
              ? _expirationDateController.text.isNotEmpty
              : true);
    }
    
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ocr.select_image_source'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickAndProcessImage(ImageSource.camera);
            },
            child: Text('ocr.camera'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickAndProcessImage(ImageSource.gallery);
            },
            child: Text('ocr.gallery'.tr()),
          ),
        ],
      ),
    );
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final tempPngPath = p.join(
        tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_temp.png');
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.path,
      tempPngPath,
      quality: 90,
      minWidth: 800,
      minHeight: 800,
      format: CompressFormat.png,
    );
    return compressedFile != null ? File(compressedFile.path) : file;
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
      _processedImageBytes = null;
      _originalImage = null;
      _processedImageFile = null;
    });

    try {
      _originalImage = File(pickedFile.path);

      // 1. القص (Crop)
      final croppedImage = await _cropImage(_originalImage!);
      if (croppedImage == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // 2. التحسين المحلي (Local Enhancement) - تباين ووضوح
      final enhancedImageFile = await _enhanceImageLocal(croppedImage);

      // 3. الضغط (Compress)
      final compressedImageFile = await _compressImage(enhancedImageFile);

      // 4. الـ OCR bytes للعرض
      final results = await Future.wait([
        compressedImageFile.readAsBytes(),
        _processOCR(compressedImageFile),
      ]);

      final compressedBytes = results[0] as Uint8List;

      setState(() {
        _processedImageBytes = compressedBytes;
        _processedImageFile = compressedImageFile;
      });

      // 📢 عرض تنبيه للمستخدم بخصوص إزالة الخلفية
      if (mounted) {
        _showBackgroundRemovalNotice();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: 'خطأ',
            message: 'Failed to process image: $e',
            contentType: ContentType.failure,
          ),
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _validateForm();
      });
    }
  }

  /// 🛠️ تحسين الصورة محلياً (زيادة التباين والوضوح)
  Future<File> _enhanceImageLocal(File file) async {
    try {
      final bytes = await file.readAsBytes();
      
      // نقوم بالمعالجة في Isolate منفصل لضمان سلاسة التطبيق
      final Uint8List? processedBytes = await compute(_applyLocalFilters, bytes);
      
      if (processedBytes == null) return file;

      final tempDir = await getTemporaryDirectory();
      final path = p.join(tempDir.path, 'enhanced_${DateTime.now().millisecondsSinceEpoch}.png');
      final enhancedFile = File(path);
      await enhancedFile.writeAsBytes(processedBytes);
      
      return enhancedFile;
    } catch (e) {
      print('⚠️ Error enhancing image locally: $e');
      return file;
    }
  }

  /// الفلاتر الفعلية (Contrast & Sharpen)
  static Uint8List? _applyLocalFilters(Uint8List bytes) {
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    // 1. زيادة التباين (Contrast) - يجعل النص أوضح
    image = img.contrast(image, contrast: 120); // 100 هي القيمة العادية

    // 2. زيادة الحِدّة (Sharpen) - يوضح حواف الحروف
    image = img.convolution(image, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]);

    // تحويل إلى PNG للحفاظ على الشفافية والجودة
    return Uint8List.fromList(img.encodePng(image));
  }

  Future<void> _processOCR(File image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    
    // 1. Spatial Sorting: Sort blocks by Y-axis to ensure reading order (Top -> Bottom)
    // هذا يضمن قراءة اسم المنتج أولاً لأنه عادة في الأعلى
    List<TextBlock> sortedBlocks = List.from(recognizedText.blocks);
    sortedBlocks.sort((a, b) {
      // السماح بهامش خطأ بسيط (10 بكسل) لاعتبار النصوص في نفس السطر
      int diffY = a.boundingBox.top.compareTo(b.boundingBox.top);
      if ((a.boundingBox.top - b.boundingBox.top).abs() < 10) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return diffY;
    });

    _parseRecognizedTextSmart(sortedBlocks);
  }

  /// 🧠 Smart Veterinary Parsing Engine
  /// محرك ذكي لتحليل نصوص الأدوية البيطرية
  void _parseRecognizedTextSmart(List<TextBlock> sortedBlocks) {
    // تجميع النصوص في قائمة واحدة نظيفة
    List<String> allLines = [];
    for (var block in sortedBlocks) {
      for (var line in block.lines) {
        String clean = _cleanText(line.text);
        if (clean.length > 2) { // تجاهل الضوضاء القصيرة
          allLines.add(clean);
        }
      }
    }

    if (allLines.isEmpty) return;

    print('🔍 Sorted & Cleaned Lines: $allLines');

    // تعريف المتغيرات المستهدفة
    String extractedName = "";
    String extractedCompany = "";
    String extractedActive = "";
    String extractedPackage = "";
    String extractedPrice = "";

    // قوائم الكلمات المفتاحية (قاعدة بيانات مصغرة)
    final vetKeywords = ['injectable', 'solution', 'suspension', 'tablet', 'bolus', 'cattle', 'sheep', 'swine', 'horse', 'dog', 'cat', 'veterinary', 'use only', 'dose', 'mg/ml', 'ml', 'l'];
    final knownCompanies = ['zoetis', 'msd', 'elanco', 'boehringer', 'bayer', 'merck', 'pfizer', 'virbac', 'ceva', 'vetoquinol', 'adwia', 'pharma', 'company', 'co.', 'ltd', 'inc'];
    final chemicals = ['tulathromycin', 'oxytetracycline', 'ivermectin', 'amoxicillin', 'penicillin', 'tylosin', 'enrofloxacin', 'flunixin', 'dexamethasone', 'calcium', 'magnesium'];

    // 1. استخراج الحجم (Package Size)
    // نبحث عن أرقام يتبعها وحدات قياس (ml, L, gm, kg)
    final packageRegex = RegExp(r'(\d+(?:\.\d+)?\s*(?:mL|L|ml|l|gm|g|kg|vials?|doses?))', caseSensitive: false);
    
    for (var line in allLines) {
      if (extractedPackage.isEmpty) {
        final match = packageRegex.firstMatch(line);
        if (match != null) {
          // نتأكد أنه ليس تركيز (مثل 100 mg/mL) بل حجم عبوة (Net Contents: 100 mL)
          if (!line.toLowerCase().contains('/')) {
             extractedPackage = match.group(0)!;
          } else if (line.toLowerCase().contains('net') || line.toLowerCase().contains('content')) {
             extractedPackage = match.group(0)!;
          }
        }
      }
    }

    // 2. استخراج الشركة (Manufacturer)
    // نبحث في أسفل القائمة أولاً (عادة الشركة في الأسفل)
    for (var i = allLines.length - 1; i >= 0; i--) {
      String lineLower = allLines[i].toLowerCase();
      if (knownCompanies.any((c) => lineLower.contains(c))) {
        extractedCompany = allLines[i];
        allLines.removeAt(i); // حذف السطر حتى لا يختلط مع الاسم
        break; // نكتفي بأول شركة نجدها من الأسفل
      }
    }

    // 3. استخراج المادة الفعالة (Active Ingredient)
    // نبحث عن كلمات كيميائية أو نصوص بين أقواس (...) تحتوي على تركيز
    for (var i = 0; i < allLines.length; i++) {
      String line = allLines[i];
      String lineLower = line.toLowerCase();
      
      // البحث عن أسماء كيميائية معروفة
      if (chemicals.any((c) => lineLower.contains(c))) {
         extractedActive = line;
         // لا نحذف السطر هنا، ربما يكون جزء من اسم المنتج
         break;
      }
      
      // البحث عن نمط (xxxxxx)
      if (line.contains('(') && line.contains(')')) {
         // غالباً المادة الفعالة تكتب تحت الاسم بين قوسين
         extractedActive = line.replaceAll(RegExp(r'[()]'), '');
         break;
      }
    }

    // 4. استخراج اسم المنتج (Product Name)
    // الافتراض: هو أول سطر "مميز" وعريض ليس وصفاً عاماً
    for (var line in allLines) {
      String lineLower = line.toLowerCase();
      
      // تجاهل الأسطر التي تحتوي كلمات وصفية بحتة إذا جاءت في البداية
      bool isGenericDesc = vetKeywords.any((k) => lineLower == k) || 
                           lineLower.startsWith('net content') ||
                           packageRegex.hasMatch(line); // تجاهل السطر لو كان عبارة عن حجم فقط
                           
      if (!isGenericDesc && extractedName.isEmpty) {
        extractedName = line;
        break;
      }
    }

    // 5. استخراج السعر (إن وجد)
    final price = _extractPrice(allLines);
    if (price != null) extractedPrice = price;


    // تعيين القيم للحقول
    setState(() {
      _nameController.text = extractedName;
      _companyController.text = extractedCompany;
      _activePrincipleController.text = extractedActive;
      
      // محاولة ضبط نوع العبوة
      if (extractedPackage.isNotEmpty) {
        _packageController.text = extractedPackage;
        // استنتاج النوع من النص
        if (extractedPackage.toLowerCase().contains('ml') || extractedPackage.toLowerCase().contains('l')) {
           if (extractedName.toLowerCase().contains('spray')) _selectedPackageType = 'spray';
           else if (extractedName.toLowerCase().contains('drop')) _selectedPackageType = 'drops';
           else _selectedPackageType = 'bottle'; // Default liquid
        } else if (extractedPackage.toLowerCase().contains('tab')) {
           _selectedPackageType = 'tab';
        }
      }
      
      if (extractedPrice.isNotEmpty) _priceController.text = extractedPrice;
    });

    // Debugging Output (Simulation of JSON response)
    print('''
    ✅ JSON Result:
    {
      "product_name": "$extractedName",
      "active_ingredient": "$extractedActive",
      "package_size": "$extractedPackage",
      "manufacturer": "$extractedCompany"
    }
    ''');
  }

  /// استخراج السعر (رقم مع رموز عملة أو كلمات مثل price, egp)
  String? _extractPrice(List<String> lines) {
    final allText = lines.join(' ');

    // نبحث عن أنماط السعر المختلفة
    final pricePatterns = [
      RegExp(r'(?:price|egp|le|£|جنيه)\s*:?\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:egp|le|£|جنيه)', caseSensitive: false),
      RegExp(r'(?:^|\s)(\d{2,4}(?:\.\d{1,2})?)\s*(?:egp|le|$)', caseSensitive: false),
    ];

    for (var pattern in pricePatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        final price = match.group(1);
        if (price != null) {
          // تحقق إن السعر معقول (بين 1 و 99999)
          final priceNum = double.tryParse(price);
          if (priceNum != null && priceNum >= 1 && priceNum < 100000) {
            return price;
          }
        }
      }
    }

    // لو مفيش، نبحث عن أي رقم معقول
    for (var line in lines) {
      final numberMatch = RegExp(r'\b(\d{1,5}(?:\.\d{1,2})?)\b').allMatches(line);
      for (var match in numberMatch) {
        final num = double.tryParse(match.group(1) ?? '');
        if (num != null && num >= 10 && num < 100000) {
          return match.group(1);
        }
      }
    }

    return null;
  }

  /// تنظيف النص من الرموز غير المرغوبة
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[®™©]'), '') // إزالة رموز العلامات التجارية
        .replaceAll(RegExp(r'\s+'), ' ') // توحيد المسافات
        .trim();
  }

  Future<void> _saveProduct() async {
    if (!_isFormValid) return;

    setState(() => _isSaving = true);

    try {
      // ✅ التحقق من تاريخ الصلاحية في الحالات الإلزامية (فقط عند الإضافة الجديدة)
      // عند التعديل (productToEdit != null)، تاريخ الصلاحية غير مطلوب أو مخفي
      if (widget.productToEdit == null && 
          (widget.showExpirationDate || widget.isFromOfferScreen) && 
          _expirationDateController.text.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'ocr.error_title'.tr(),
              message: 'يرجى اختيار تاريخ انتهاء الصلاحية أولاً',
              contentType: ContentType.warning,
            ),
          ),
        );
        return;
      }

      String? finalUrl = _existingImageUrl;

      // رفع صورة جديدة فقط إذا قام المستخدم بالتقاط/اختيار صورة
      if (_processedImageFile != null) {
        // استخدام الخدمة الذكية (SmartImageService) لتوفير الكوتا
        // 1. رفع للحساب الأول للإزالة الخلفية
        // 2. نقل للحساب الثاني للتخزين
        final smartImageService = ref.read(smartImageServiceProvider);
        finalUrl = await smartImageService.processAndSaveImage(
          imageFile: _processedImageFile!,
          folder: 'ocr',
        );
      }
      
      if (finalUrl == null) throw Exception('Image is required');

      final name = _nameController.text;
      final company = _companyController.text;
      final activePrinciple = _activePrincipleController.text;
      String package = _packageController.text;
      
      // عند الاستخدام من صفحة التقييمات، لا نحفظ في جدول ocr_products
      // فقط نرجع البيانات الممسوحة والصورة المرفوعة
      if (widget.isFromReviewRequest) {
        if (_selectedPackageType != null &&
            !package
                .toLowerCase()
                .contains(_selectedPackageType!.toLowerCase())) {
          package = '${package.trim()} $_selectedPackageType'.trim();
        }

        if (mounted) {
          print('✅ OCR Process complete for Review Request - returning data without saving to DB');
          setState(() => _isSaving = false);
          Navigator.pop(context, {
            'product_id': 'temp_ocr', // معرف مؤقت
            'product_type': 'ocr_product',
            'product_name': name,
            'product_image': finalUrl,
            'product_package': package,
          });
          return;
        }
      }
      
      // Price is only required for new products (not editing) and not from review request
      double? price;
      if (widget.productToEdit == null && !widget.isFromReviewRequest) {
        price = double.tryParse(_priceController.text);
        if (price == null) throw Exception('Invalid price format');
      }

      if (_selectedPackageType != null &&
          !package
              .toLowerCase()
              .contains(_selectedPackageType!.toLowerCase())) {
        package = '${package.trim()} $_selectedPackageType'.trim();
      }

      final productRepo = ref.read(productRepositoryProvider);
      final userId = ref.read(authServiceProvider).currentUser?.id;
      final userData = await ref.read(userDataProvider.future);
      final distributorName = userData?.displayName ?? 'Unknown Distributor';

      if (userId != null) {
        if (widget.productToEdit != null) {
          // ============================================
          // تحديث المنتج (Update)
          // ============================================
          final success = await productRepo.updateOcrProduct(
            ocrProductId: widget.productToEdit!.id,
            distributorId: userId,
            name: name,
            company: company,
            activePrinciple: activePrinciple,
            package: package,
            imageUrl: finalUrl,
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.transparent,
                content: AwesomeSnackbarContent(
                  title: 'ocr.success_title'.tr(),
                  message: 'ocr.update_success'.tr(),
                  contentType: ContentType.success,
                ),
              ),
            );
            Navigator.of(context).pop();
            return;
          } else {
             throw Exception('Failed to update product');
          }
        }

        // ============================================
        // الأدوات الجراحية (Add)
        // ============================================
        if (widget.isFromSurgicalTools) {
          final description = _descriptionController.text;
          
          // إضافة الأداة للكتالوج العام
          final surgicalToolId = await productRepo.addSurgicalTool(
            toolName: name,
            company: company.isNotEmpty ? company : null,
            imageUrl: finalUrl,
            createdBy: userId,
          );

          if (surgicalToolId != null) {
            // ربط الأداة بالموزع مع السعر والوصف الخاص به
            final success = await productRepo.addDistributorSurgicalTool(
              distributorId: userId,
              distributorName: distributorName,
              surgicalToolId: surgicalToolId,
              description: description,
              price: price!,
              status: _selectedStatus,
            );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.transparent,
                  content: AwesomeSnackbarContent(
                    title: 'ocr.success_title'.tr(),
                    message: 'ocr.surgical_add_success'.tr(),
                    contentType: ContentType.success,
                  ),
                ),
              );
              Navigator.of(context).pop();
              return;
            }
          }
        }
        
        // ============================================
        // المنتجات العادية (OCR)
        // ============================================
        else {
          // إذا كان showExpirationDate = false (قادم من my_products)، لا نحفظ تاريخ الصلاحية
          // إذا كان showExpirationDate = true (قادم من expire_drugs)، نحفظ التاريخ
          DateTime? expirationDate;
          if (widget.showExpirationDate) {
            expirationDate = _expirationDateController.text.isNotEmpty
                ? DateFormat('MM-yyyy').parse(_expirationDateController.text)
                : DateTime.now().add(const Duration(days: 365));
          } else {
            // لا نحفظ تاريخ الصلاحية (null) حتى لا يظهر في expire_drugs
            expirationDate = null;
          }

          final ocrProductId = await productRepo.addOcrProduct(
            distributorId: userId,
            distributorName: distributorName,
            productName: name,
            productCompany: company,
            activePrinciple: activePrinciple,
            package: package,
            imageUrl: finalUrl,
          );
          
          if (ocrProductId != null) {
            if (widget.isFromOfferScreen) {
              // حفظ في جدول offers فقط
              // للـ offers، التاريخ إجباري
              final offerExpirationDate = _expirationDateController.text.isNotEmpty
                  ? DateFormat('MM-yyyy').parse(_expirationDateController.text)
                  : DateTime.now().add(const Duration(days: 365));
              
              final offerId = await productRepo.addOffer(
                productId: ocrProductId,
                isOcr: true,
                userId: userId,
                price: price!,
                expirationDate: offerExpirationDate,
                package: package,
              );

              if (offerId != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 0,
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.transparent,
                    content: AwesomeSnackbarContent(
                      title: 'ocr.success_title'.tr(),
                      message: 'ocr.add_success'.tr(),
                      contentType: ContentType.success,
                    ),
                  ),
                );

                if (mounted) {
                  await Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => OfferDetailScreen(
                        offerId: offerId,
                        productName: name,
                        price: price!,
                        expirationDate: offerExpirationDate,
                      ),
                    ),
                  );
                }
                return;
              }
            } else {
              // الحفظ العادي في distributor_ocr_products
              await productRepo.addDistributorOcrProduct(
                distributorId: userId,
                distributorName: distributorName,
                ocrProductId: ocrProductId,
                price: price!,
                expirationDate: expirationDate, // null إذا قادم من my_products
              );
            }
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.transparent,
                  content: AwesomeSnackbarContent(
                    title: 'ocr.success_title'.tr(),
                    message: 'ocr.add_success'.tr(),
                    contentType: ContentType.success,
                  ),
                ),
              );
              Navigator.of(context).pop();
            }
          }
        }
      }

    } catch (e) {
      print('Error saving product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: 'ocr.error_title'.tr(),
            message: '${'ocr.save_failed'.tr()}: $e',
            contentType: ContentType.failure,
          ),
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// 📢 تنبيه المستخدم بخصوص إزالة الخلفية والتحسين التلقائي
  void _showBackgroundRemovalNotice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 10),
            Text(
              'ocr.image_notice_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'ocr.image_notice_body'.tr(),
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ocr.got_it'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _packageFocusNode.dispose(); // جديد
    _nameController.dispose();
    _companyController.dispose();
    _activePrincipleController.dispose();
    _packageController.dispose();
    _priceController.dispose();
    _expirationDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardElevation = isDark ? 2.0 : 4.0;
    final inputBgColor =
        isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF8FDFF);
    final inputBorderColor =
        isDark ? Colors.grey.shade700 : const Color(0xFFE0E6F0);
    final accentColor = theme.colorScheme.primary;
    final priceColor =
        isDark ? Colors.lightGreenAccent.shade200 : Colors.green.shade700;

    final saveButton = Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24.0),
      child: ElevatedButton(
        onPressed: (_isFormValid && !_isProcessing && !_isSaving)
            ? _saveProduct
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
        child: (_isProcessing || _isSaving)
            ? const ShimmerLoader(
                width: 24,
                height: 24,
                isCircular: true,
                baseColor: Colors.white,
              )
            : Text(
                widget.isFromReviewRequest 
                    ? 'ocr.confirm_selection'.tr() 
                    : widget.productToEdit != null 
                        ? 'ocr.update_product'.tr() 
                        : 'ocr.save_product'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productToEdit != null
              ? 'ocr.update_product_title'.tr()
              : (widget.isFromSurgicalTools ? 'ocr.add_surgical_tool'.tr() : 'ocr.add_product_title'.tr()),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: cardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: inputBgColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(1),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: inputBorderColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _processedImageBytes != null
                                ? Icons.image
                                : Icons.photo_camera,
                            color: _processedImageBytes != null
                                ? accentColor
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _processedImageBytes != null
                                  ? 'ocr.image_processed'.tr()
                                  : 'ocr.take_photo'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _processedImageBytes != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isProcessing)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ShimmerLoader(
                                width: 20,
                                height: 20,
                                isCircular: true,
                                baseColor: accentColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_processedImageBytes != null)
                      SizedBox(
                        height: 250,
                        child: Image.memory(
                          _processedImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                      SizedBox(
                        height: 250,
                        child: CachedNetworkImage(
                          imageUrl: _existingImageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      )
                    else
                      Container(
                        height: 250,
                        color: inputBgColor,
                        child: Center(
                          child: Text(
                            'ocr.no_image_selected'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: (_isProcessing || _isSaving)
                            ? null
                            : _showImageSourceDialog,
                        icon: Icon(
                          _isProcessing
                              ? Icons.hourglass_bottom
                              : Icons.camera_alt,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isProcessing
                              ? 'ocr.processing_image'.tr()
                              : _isSaving
                                  ? 'ocr.saving'.tr()
                                  : 'ocr.scan_product'.tr(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'ocr.product_info_title'.tr(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.productToEdit != null) ...[
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final distributorsAsync = ref.watch(distributorsProvider);
                  final currentName = distributorsAsync.maybeWhen(
                    data: (distributors) {
                      final dist = distributors.firstWhereOrNull((d) => 
                        d.id == widget.productToEdit!.distributorUuid || 
                        d.id == widget.productToEdit!.distributorId
                      );
                      return dist?.displayName;
                    },
                    orElse: () => null,
                  );
                  
                  final finalDisplayName = currentName ?? 
                    (widget.productToEdit!.distributorId != null && !widget.productToEdit!.distributorId!.contains('-') 
                      ? widget.productToEdit!.distributorId 
                      : null);

                  if (finalDisplayName == null) return const SizedBox.shrink();
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_rounded, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${'ocr.added_by'.tr()}: $finalDisplayName',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'ocr.product_info_subtitle'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: cardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // الاسم - إجباري دائماً
                    _buildTextField(
                        widget.isFromSurgicalTools ? 'ocr.label_tool_name'.tr() : 'ocr.label_product_name'.tr(),
                        Icons.medical_services,
                        _nameController,
                        inputBgColor,
                        inputBorderColor,
                        accentColor),
                    const SizedBox(height: 16),
                    
                    // الشركة - اختياري للأدوات الجراحية، إجباري للمنتجات
                    if (!widget.isFromSurgicalTools) ...[
                      _buildTextField(
                          'ocr.label_company'.tr(),
                          Icons.business,
                          _companyController,
                          inputBgColor,
                          inputBorderColor,
                          accentColor),
                      const SizedBox(height: 16),
                    ] else ...[
                      _buildTextField(
                          'ocr.label_company_optional'.tr(),
                          Icons.business,
                          _companyController,
                          inputBgColor,
                          inputBorderColor,
                          accentColor),
                      const SizedBox(height: 16),
                    ],
                    
                    // Active Principle - فقط للمنتجات
                    if (!widget.isFromSurgicalTools) ...[
                      _buildTextField(
                          'ocr.label_active_principle'.tr(),
                          Icons.science,
                          _activePrincipleController,
                          inputBgColor,
                          inputBorderColor,
                          accentColor),
                      const SizedBox(height: 16),
                    ],
                    
                    // Package Description - فقط للمنتجات
                    if (!widget.isFromSurgicalTools) ...[
                      _buildTextField(
                          'ocr.label_package_desc'.tr(),
                          Icons.content_paste,
                          _packageController,
                          inputBgColor,
                          inputBorderColor,
                          accentColor,
                          hintText: 'ocr.label_package_desc_hint'.tr(),
                          focusNode: _packageFocusNode), // جديد
                      const SizedBox(height: 16),
                    ],
                    
                    // Package Type - فقط للمنتجات
                    if (!widget.isFromSurgicalTools) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedPackageType,
                        decoration: InputDecoration(
                          labelText: 'ocr.label_package_type'.tr(),
                          prefixIcon: Icon(
                            FontAwesomeIcons.boxesStacked,
                            size: 20,
                            color: accentColor,
                          ),
                          filled: true,
                          fillColor: inputBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                        ),
                        items: _packageTypes
                            .map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedPackageType = value);
                          _validateForm();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Description - فقط للأدوات الجراحية، إجباري
                    if (widget.isFromSurgicalTools) ...[
                      _buildTextField(
                          'ocr.label_description'.tr(),
                          Icons.description,
                          _descriptionController,
                          inputBgColor,
                          inputBorderColor,
                          accentColor,
                          maxLines: 3),
                      const SizedBox(height: 16),
                      
                      // حالة الأداة
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'ocr.label_tool_status'.tr(),
                          prefixIcon: Icon(
                            Icons.info_outline,
                            color: accentColor,
                          ),
                          filled: true,
                          fillColor: inputBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                        items: _statusKeys.map((String key) {
                          String label = key;
                          if (key == 'جديد') label = 'ocr.status_new'.tr();
                          else if (key == 'مستعمل') label = 'ocr.status_used'.tr();
                          else if (key == 'كسر زيرو') label = 'ocr.status_like_new'.tr();
                          
                          return DropdownMenuItem<String>(
                            value: key,
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
                      const SizedBox(height: 16),
                    ],
                    
                    // السعر - إجباري دائماً (مخفي عند isFromReviewRequest وعند التعديل productToEdit != null)
                    if (!widget.isFromReviewRequest && widget.productToEdit == null) ...[
                      _buildTextField(
                          'ocr.label_price'.tr(),
                          Icons.attach_money,
                          _priceController,
                          inputBgColor,
                          inputBorderColor,
                          priceColor,
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                    ],
                    
                    // Expiration Date - حسب showExpirationDate (مخفي عند التعديل productToEdit != null)
                    if (widget.showExpirationDate && widget.productToEdit == null)
                      _buildTextField(
                        'ocr.label_expiration_date'.tr(),
                        Icons.calendar_today,
                        _expirationDateController,
                        inputBgColor,
                        inputBorderColor,
                        accentColor,
                        readOnly: true,
                        onTap: () async {
                          final DateTime now = DateTime.now();
                          final DateTime? picked = await showMonthPicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(now.month, now.year),
                            lastDate: DateTime(2101, 12),
                          );
                          if (picked != null) {
                            final formattedDate =
                                DateFormat('MM-yyyy').format(picked);
                            _expirationDateController.text = formattedDate;

                            _validateForm();
                          }
                        },
                      ),
                    saveButton,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller,
    Color bgColor,
    Color borderColor,
    Color iconColor, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    String? hintText,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType ?? TextInputType.text,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: iconColor),
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: iconColor, width: 2),
        ),
      ),
    );
  }
}