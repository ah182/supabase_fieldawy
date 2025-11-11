import 'dart:io';
import 'dart:typed_data';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/presentation/screens/offer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:http/http.dart' as http;
import 'package:fieldawy_store/services/cloudinary_service.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

class AddProductOcrScreen extends ConsumerStatefulWidget {
  final bool showExpirationDate;
  final bool isFromOfferScreen;
  final bool isFromSurgicalTools;
  final bool isFromReviewRequest;
  const AddProductOcrScreen({
    super.key,
    this.showExpirationDate = true,
    this.isFromOfferScreen = false,
    this.isFromSurgicalTools = false,
    this.isFromReviewRequest = false,
  });

  @override
  ConsumerState<AddProductOcrScreen> createState() =>
      _AddProductOcrScreenState();
}

class _AddProductOcrScreenState extends ConsumerState<AddProductOcrScreen> {
  File? _originalImage;
  Uint8List? _processedImageBytes;
  File? _processedImageFile;

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
  ];
  String? _selectedPackageType;
  String _selectedStatus = 'جديد'; // للأدوات الجراحية

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateForm);
    _companyController.addListener(_validateForm);
    _activePrincipleController.addListener(_validateForm);
    _priceController.addListener(_validateForm);
    _packageController.addListener(_validateForm);
    _expirationDateController.addListener(_validateForm);
    _descriptionController.addListener(_validateForm);
  }

  void _validateForm() {
    bool isValid;
    
    if (widget.isFromReviewRequest) {
      // من صفحة التقييمات: الاسم + الشركة + المادة الفعالة فقط
      isValid = _processedImageBytes != null &&
          _nameController.text.isNotEmpty &&
          _companyController.text.isNotEmpty &&
          _activePrincipleController.text.isNotEmpty;
    } else if (widget.isFromSurgicalTools) {
      // للأدوات الجراحية: الاسم + السعر + الوصف إجباري
      isValid = _processedImageBytes != null &&
          _nameController.text.isNotEmpty &&
          _priceController.text.isNotEmpty &&
          _descriptionController.text.isNotEmpty;
    } else {
      // للمنتجات العادية
      isValid = _processedImageBytes != null &&
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
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickAndProcessImage(ImageSource.camera);
            },
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickAndProcessImage(ImageSource.gallery);
            },
            child: const Text('Gallery'),
          ),
        ],
      ),
    );
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final tempJpegPath = p.join(
        tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_temp.jpg');
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.path,
      tempJpegPath,
      quality: 80,
      minWidth: 800,
      minHeight: 800,
      format: CompressFormat.jpeg,
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

  Future<Uint8List?> _removeBackground(File imageFile) async {
    try {
      final url =
          Uri.parse("https://ah3181997-my-rembg-space.hf.space/api/remove");
      final request = http.MultipartRequest('POST', url);
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        return await response.stream.toBytes();
      } else {
        throw Exception('Failed to remove background: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to remove background: $e');
    }
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

      // 1. Compress
      final compressedImage = await _compressImage(_originalImage!);

      // 2. Crop
      final croppedImage = await _cropImage(compressedImage);
      if (croppedImage == null) {
        setState(() => _isProcessing = false);
        return; // User cancelled cropping
      }

      // 3. Remove Background & Process OCR in parallel
      final results = await Future.wait([
        _removeBackground(croppedImage),
        _processOCR(croppedImage),
      ]);

      final bgRemovedBytes = results[0] as Uint8List?;
      if (bgRemovedBytes == null) {
        throw Exception("Background removal failed.");
      }

      // Save the processed image to a temporary file for later upload
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'processed_product.png');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bgRemovedBytes);

      setState(() {
        _processedImageBytes = bgRemovedBytes;
        _processedImageFile = tempFile;
      });
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

  Future<void> _processOCR(File image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    _parseRecognizedTextAI(recognizedText);
  }

  /// 🤖 AI-Powered Text Parsing
  /// استخراج ذكي للبيانات من النص مع تصحيح الأخطاء
  void _parseRecognizedTextAI(RecognizedText recognizedText) {
    final lines = recognizedText.blocks.expand((b) => b.lines).toList();
    if (lines.isEmpty) return;

    // تجميع كل النصوص
    final allText = lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).toList();
    
    print('🔍 OCR Extracted Lines:');
    for (var i = 0; i < allText.length; i++) {
      print('  Line $i: "${allText[i]}"');
    }

    // ✅ 1. استخراج اسم المنتج (أول سطر كبير عادة)
    _nameController.text = _extractProductName(allText);

    // ✅ 2. استخراج اسم الشركة (آخر سطر أو سطر يحتوي على كلمات مفتاحية)
    _companyController.text = _extractCompanyName(allText);

    // ✅ 3. استخراج المادة الفعالة (سطر يحتوي على اسم كيميائي)
    _activePrincipleController.text = _extractActivePrinciple(allText);

    // ✅ 4. استخراج معلومات التعبئة (ml, mg, tab, vial, etc)
    final packageInfo = _extractPackageInfo(allText);
    _packageController.text = packageInfo['description'] ?? '';
    _selectedPackageType = packageInfo['type'];

    // ✅ 5. استخراج السعر
    final price = _extractPrice(allText);
    if (price != null) _priceController.text = price;

    print('✅ AI Parsing Results:');
    print('  Name: ${_nameController.text}');
    print('  Company: ${_companyController.text}');
    print('  Active: ${_activePrincipleController.text}');
    print('  Package: ${_packageController.text}');
    print('  Type: $_selectedPackageType');
    print('  Price: ${_priceController.text}');
  }

  /// استخراج اسم المنتج (أول سطر كبير أو أول سطر غير رقمي)
  String _extractProductName(List<String> lines) {
    if (lines.isEmpty) return '';
    
    // نبحث عن أول سطر يحتوي على حروف (مش أرقام فقط)
    for (var line in lines) {
      final cleaned = line.trim();
      // تجاهل الأسطر القصيرة جداً أو الأرقام فقط
      if (cleaned.length < 2 || RegExp(r'^\d+$').hasMatch(cleaned)) continue;
      
      // تنظيف من الرموز غير المرغوبة
      final name = _cleanText(cleaned);
      if (name.length >= 2) return name;
    }
    
    return lines.first.trim();
  }

  /// استخراج اسم الشركة (عادة آخر سطر أو سطر يحتوي على كلمات مثل pharma, lab, co)
  String _extractCompanyName(List<String> lines) {
    if (lines.length < 2) return '';

    // الكلمات المفتاحية للشركات
    final companyKeywords = [
      'pharma', 'pharmaceutical', 'lab', 'laboratories', 
      'co', 'company', 'ltd', 'inc', 'egypt', 'international',
      'health', 'medical', 'care', 'industries'
    ];

    // نبحث من الآخر للأول
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].toLowerCase();
      
      // لو السطر يحتوي على كلمة مفتاحية
      if (companyKeywords.any((keyword) => line.contains(keyword))) {
        return _cleanText(lines[i]);
      }
    }

    // لو مفيش، نرجع آخر سطر
    return _cleanText(lines.last);
  }

  /// استخراج المادة الفعالة (سطر يحتوي على اسم كيميائي معقد)
  String _extractActivePrinciple(List<String> lines) {
    // نبحث عن سطر يحتوي على حروف معقدة (اسم دواء)
    // عادة يحتوي على حروف كبيرة صغيرة متداخلة
    
    for (var line in lines) {
      final cleaned = line.trim();
      
      // تجاهل الأسطر القصيرة أو الأرقام
      if (cleaned.length < 3) continue;
      
      // لو السطر يحتوي على حروف كبيرة وصغيرة ومعقد
      if (_looksLikeChemicalName(cleaned)) {
        return _cleanText(cleaned);
      }
    }

    // لو مفيش، نحاول نجيب السطر الثاني أو الثالث
    if (lines.length > 2) return _cleanText(lines[1]);
    return '';
  }

  /// فحص لو النص يشبه اسم كيميائي
  bool _looksLikeChemicalName(String text) {
    // الأسماء الكيميائية عادة:
    // 1. تحتوي على حروف كبيرة وصغيرة
    // 2. طويلة نسبياً (أكثر من 5 حروف)
    // 3. قد تحتوي على أرقام لكن مش أرقام فقط
    
    if (text.length < 4) return false;
    
    final hasUpper = RegExp(r'[A-Z]').hasMatch(text);
    final hasLower = RegExp(r'[a-z]').hasMatch(text);
    final notOnlyNumbers = !RegExp(r'^\d+$').hasMatch(text);
    
    return hasUpper && hasLower && notOnlyNumbers;
  }

  /// استخراج معلومات التعبئة (ml, mg, tab, etc)
  Map<String, String?> _extractPackageInfo(List<String> lines) {
    final allText = lines.join(' ').toLowerCase();
    
    // أنواع التعبئة وكلماتها المفتاحية
    final packagePatterns = {
      'bottle': RegExp(r'(\d+\s*ml|bottle)', caseSensitive: false),
      'vial': RegExp(r'(\d+\s*vial|vial)', caseSensitive: false),
      'tab': RegExp(r'(\d+\s*tab|tablet|tabs)', caseSensitive: false),
      'amp': RegExp(r'(\d+\s*amp|ampoule|ampule)', caseSensitive: false),
      'sachet': RegExp(r'(\d+\s*sachet|sach)', caseSensitive: false),
      'strip': RegExp(r'(\d+\s*strip)', caseSensitive: false),
      'cream': RegExp(r'(cream|ointment)', caseSensitive: false),
      'gel': RegExp(r'(gel)', caseSensitive: false),
      'spray': RegExp(r'(spray)', caseSensitive: false),
      'drops': RegExp(r'(drops|drop)', caseSensitive: false),
    };

    String? packageType;
    String description = '';

    // نبحث عن كل نوع
    for (var entry in packagePatterns.entries) {
      final match = entry.value.firstMatch(allText);
      if (match != null) {
        packageType = entry.key;
        description = match.group(0) ?? '';
        
        // نحاول نجيب السطر الكامل اللي فيه المعلومة دي
        for (var line in lines) {
          if (line.toLowerCase().contains(description.toLowerCase())) {
            description = _cleanText(line);
            break;
          }
        }
        break;
      }
    }

    // لو مفيش نوع محدد، نبحث عن أي رقم + وحدة
    if (packageType == null) {
      final unitMatch = RegExp(
        r'(\d+\s*(?:ml|mg|g|kg|l|tab|caps|cap|piece|pcs))',
        caseSensitive: false,
      ).firstMatch(allText);
      
      if (unitMatch != null) {
        description = unitMatch.group(0) ?? '';
      }
    }

    return {
      'type': packageType,
      'description': description,
    };
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
    if (!_isFormValid || _processedImageFile == null) return;

    setState(() => _isSaving = true);

    try {
      final cloudinaryService = ref.read(cloudinaryServiceProvider);
      final finalUrl = await cloudinaryService.uploadImage(
        imageFile: _processedImageFile!,
        folder: 'ocr',
      );
      if (finalUrl == null) throw Exception('Failed to upload image');

      final name = _nameController.text;
      final company = _companyController.text;
      final activePrinciple = _activePrincipleController.text;
      String package = _packageController.text;
      
      // عند الاستخدام من صفحة التقييمات، نضيف المنتج للكتالوج ونرجع ID
      if (widget.isFromReviewRequest) {
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

        String? ocrProductId;  // تعريف المتغير خارج الـ if
        
        if (userId != null) {
          ocrProductId = await productRepo.addOcrProduct(
            distributorId: userId,
            distributorName: distributorName,
            productName: name,
            productCompany: company,
            activePrinciple: activePrinciple,
            package: package,
            imageUrl: finalUrl,
          );

          // Debug: طباعة القيمة المُرجعة
          print('🔍 OCR Product ID returned: $ocrProductId');
          print('🔍 OCR Product ID type: ${ocrProductId.runtimeType}');
          
          if (ocrProductId != null && ocrProductId.isNotEmpty && mounted) {
            // التحقق من أن الـ ID صالح
            if (ocrProductId.length < 10) {
              print('⚠️ Invalid product ID: too short');
              throw Exception('Invalid product ID format');
            }
            
            print('✅ Returning product ID: $ocrProductId');
            setState(() => _isSaving = false);
            Navigator.pop(context, {
              'product_id': ocrProductId,
              'product_type': 'ocr_product',
              'product_name': name,
              'product_image': finalUrl,
            });
            return;
          } else {
            print('❌ OCR Product ID is null or empty!');
          }
        } else {
          print('❌ User ID is null!');
        }
        throw Exception('Failed to add product: userId=${userId != null}, ocrProductId=$ocrProductId');
      }
      
      final price = double.tryParse(_priceController.text);
      if (price == null) throw Exception('Invalid price format');

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
        // ============================================
        // الأدوات الجراحية
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
              price: price,
              status: _selectedStatus,
            );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.transparent,
                  content: AwesomeSnackbarContent(
                    title: 'نجاح',
                    message: 'تم إضافة الأداة الجراحية بنجاح!',
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
                price: price,
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
                      title: 'نجاح',
                      message: 'تم إضافة المنتج بنجاح',
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
                        price: price,
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
                price: price,
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
                    title: 'نجاح',
                    message: 'Product added successfully!',
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
            title: 'خطأ',
            message: 'Failed to save product: $e',
            contentType: ContentType.failure,
          ),
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
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
                widget.isFromReviewRequest ? 'تأكيد الاختيار' : 'Save Product',
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
          widget.isFromSurgicalTools ? 'Add Surgical Tool' : 'Add New Product',
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
                                  ? 'Product Image Processed'
                                  : 'Take product photo',
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
                    else
                      Container(
                        height: 250,
                        color: inputBgColor,
                        child: Center(
                          child: Text(
                            'No image selected',
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
                              ? 'Processing Image...'
                              : _isSaving
                                  ? 'Saving...'
                                  : 'Scan Product',
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
            const SizedBox(height: 24),
            Text(
              'Product Information',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fill in or verify the extracted details',
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
                        widget.isFromSurgicalTools ? 'Tool Name' : 'Product Name',
                        Icons.medical_services,
                        _nameController,
                        inputBgColor,
                        inputBorderColor,
                        accentColor),
                    const SizedBox(height: 16),
                    
                    // الشركة - اختياري للأدوات الجراحية، إجباري للمنتجات
                    if (!widget.isFromSurgicalTools) ...[
                      _buildTextField(
                          'Company',
                          Icons.business,
                          _companyController,
                          inputBgColor,
                          inputBorderColor,
                          accentColor),
                      const SizedBox(height: 16),
                    ] else ...[
                      _buildTextField(
                          'Company (Optional)',
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
                          'Active Principle',
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
                          'Package Description',
                          Icons.content_paste,
                          _packageController,
                          inputBgColor,
                          inputBorderColor,
                          accentColor),
                      const SizedBox(height: 16),
                    ],
                    
                    // Package Type - فقط للمنتجات
                    if (!widget.isFromSurgicalTools) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedPackageType,
                        decoration: InputDecoration(
                          labelText: 'Package Type',
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
                          'Description',
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
                          labelText: 'Tool Status / حالة الأداة',
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
                        items: ['جديد', 'مستعمل', 'كسر زيرو'].map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
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
                    
                    // السعر - إجباري دائماً (مخفي عند isFromReviewRequest)
                    if (!widget.isFromReviewRequest) ...[
                      _buildTextField(
                          'Price',
                          Icons.attach_money,
                          _priceController,
                          inputBgColor,
                          inputBorderColor,
                          priceColor,
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                    ],
                    
                    // Expiration Date - حسب showExpirationDate
                    if (widget.showExpirationDate)
                      _buildTextField(
                        'Expiration Date',
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
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