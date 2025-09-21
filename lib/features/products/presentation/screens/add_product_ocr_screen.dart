import 'dart:io';
import 'package:fieldawy_store/features/authentication/data/storage_service.dart';
import 'package:fieldawy_store/features/authentication/services/auth_service.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class AddProductOcrScreen extends ConsumerStatefulWidget {
  const AddProductOcrScreen({super.key});

  @override
  ConsumerState<AddProductOcrScreen> createState() =>
      _AddProductOcrScreenState();
}

class _AddProductOcrScreenState extends ConsumerState<AddProductOcrScreen> {
  File? _selectedImage;
  String? _previewUrl;
  String? _finalImageUrl;
  String? _tempPublicId; // ← لتخزين publicId للصورة المؤقتة

  bool _isOCRProcessing = false;
  bool _isUploadProcessing = false;
  bool _isFormValid = false;

  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _activePrincipleController = TextEditingController();
  final _priceController = TextEditingController();
  final _packageController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateForm);
    _companyController.addListener(_validateForm);
    _activePrincipleController.addListener(_validateForm);
    _priceController.addListener(_validateForm);
    _packageController.addListener(_validateForm);
  }

  void _validateForm() {
    final isValid = _previewUrl != null &&
        _nameController.text.isNotEmpty &&
        _companyController.text.isNotEmpty &&
        _activePrincipleController.text.isNotEmpty &&
        _priceController.text.isNotEmpty &&
        _packageController.text.isNotEmpty &&
        _selectedPackageType != null;
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
              _pickImage(ImageSource.camera);
            },
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.gallery);
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

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isOCRProcessing = true;
      _isUploadProcessing = false;
      _previewUrl = null;
      _selectedImage = null;
      _finalImageUrl = null;
      _tempPublicId = null;
    });

    try {
      final compressed = await _compressImage(File(pickedFile.path));
      setState(() => _selectedImage = compressed);

      await _processOCR(compressed);

      // Upload temp image
      final storageService = ref.read(storageServiceProvider);
      final tempResult = await storageService.uploadTempImage(compressed);
      if (tempResult != null) {
        setState(() {
          _previewUrl = storageService.buildPreviewUrl(tempResult.secureUrl);
          _tempPublicId = tempResult.publicId; // ← حفظ publicId
        });
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
        _isOCRProcessing = false;
        _validateForm();
      });
    }
  }

  Future<void> _processOCR(File image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    _parseRecognizedText(recognizedText);
  }

  void _parseRecognizedText(RecognizedText recognizedText) {
    final lines = recognizedText.blocks.expand((b) => b.lines).toList();
    if (lines.isEmpty) return;

    _nameController.text = lines.first.text;
    _companyController.text = lines.length > 1 ? lines.last.text : '';
    _activePrincipleController.text = '';

    String package = '';
    String? price;
    final lowerLines = lines.map((l) => l.text.toLowerCase());
    for (var line in lowerLines) {
      if (line.contains('ml') || line.contains('sachet')) package = line;
      final match = RegExp(r'\b\d+(?:\.\d{1,2})?\b').firstMatch(line);
      if (match != null) price = match.group(0);
    }

    _packageController.text = package;
    if (price != null) _priceController.text = price;
  }

  Future<void> _saveProduct() async {
    if (!_isFormValid || _selectedImage == null) return;

    setState(() => _isUploadProcessing = true);

    try {
      final storageService = ref.read(storageServiceProvider);
      final finalUrl = await storageService.uploadFinalImage(_selectedImage!);
      if (finalUrl == null) throw Exception('Failed to make image permanent');

      setState(() => _finalImageUrl = finalUrl);

      // ← حذف الصورة المؤقتة بعد رفع الصورة النهائية
      if (_tempPublicId != null) {
        await storageService.deleteTempImage(_tempPublicId!);
      }

      final name = _nameController.text;
      final company = _companyController.text;
      final activePrinciple = _activePrincipleController.text;
      String package = _packageController.text;
      final price = double.tryParse(_priceController.text);
      if (price == null) throw Exception('Invalid price format');

      if (_selectedPackageType != null &&
          !package
              .toLowerCase()
              .contains(_selectedPackageType!.toLowerCase())) {
        package = '${package.trim()} $_selectedPackageType'.trim();
      }

      final newProduct = ProductModel(
        id: '',
        name: name,
        company: company,
        activePrinciple: activePrinciple,
        imageUrl: finalUrl,
        package: package,
        availablePackages: [package],
      );

      final productRepo = ref.read(productRepositoryProvider);
      final newProductId = await productRepo.addProductToCatalog(newProduct);

      final userId = ref.read(authServiceProvider).currentUser?.id;
      final userData = await ref.read(userDataProvider.future);
      final distributorName = userData?.displayName ?? 'Unknown Distributor';

      if (userId != null) {
        await productRepo.addProductToDistributorCatalog(
          distributorId: userId,
          distributorName: distributorName,
          productId: newProductId!,
          package: package,
          price: price,
        );
      }

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
    } catch (e) {
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
      setState(() => _isUploadProcessing = false);
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
        onPressed: (_isFormValid && !_isOCRProcessing && !_isUploadProcessing)
            ? _saveProduct
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
        child: (_isOCRProcessing || _isUploadProcessing)
            ? const ShimmerLoader(
                width: 24,
                height: 24,
                isCircular: true,
                baseColor: Colors.white,
              )
            : Text(
                'Save Product',
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
          'Add New Product',
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
                            _previewUrl != null
                                ? Icons.image
                                : Icons.photo_camera,
                            color: _previewUrl != null
                                ? accentColor
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _previewUrl != null
                                  ? 'Product Image Selected'
                                  : 'Take product photo',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _previewUrl != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isOCRProcessing)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ShimmerLoader(
                                width: 20,
                                height: 20,
                                isCircular: true,
                                baseColor: accentColor,
                              ),
                            ),
                          if (_isUploadProcessing)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: const ShimmerLoader(
                                width: 20,
                                height: 20,
                                isCircular: true,
                                baseColor: Colors.orangeAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_previewUrl != null)
                      SizedBox(
                        height: 250,
                        child: CachedNetworkImage(
                          imageUrl: _finalImageUrl ?? _previewUrl!,
                          fit: BoxFit.contain,
                          progressIndicatorBuilder: (context, url, progress) =>
                              Center(
                            child: CircularProgressIndicator(
                              value: progress.progress,
                              color: accentColor,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
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
                        onPressed: (_isOCRProcessing || _isUploadProcessing)
                            ? null
                            : _showImageSourceDialog,
                        icon: Icon(
                          _isOCRProcessing || _isUploadProcessing
                              ? Icons.hourglass_bottom
                              : Icons.camera_alt,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isOCRProcessing
                              ? 'Processing OCR...'
                              : _isUploadProcessing
                                  ? 'Uploading...'
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
                    _buildTextField(
                        'Product Name',
                        Icons.medical_services,
                        _nameController,
                        inputBgColor,
                        inputBorderColor,
                        accentColor),
                    const SizedBox(height: 16),
                    _buildTextField(
                        'Company',
                        Icons.business,
                        _companyController,
                        inputBgColor,
                        inputBorderColor,
                        accentColor),
                    const SizedBox(height: 16),
                    _buildTextField(
                        'Active Principle',
                        Icons.science,
                        _activePrincipleController,
                        inputBgColor,
                        inputBorderColor,
                        accentColor),
                    const SizedBox(height: 16),
                    _buildTextField(
                        'Package Description',
                        Icons.content_paste,
                        _packageController,
                        inputBgColor,
                        inputBorderColor,
                        accentColor),
                    const SizedBox(height: 16),
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
                    _buildTextField(
                        'Price',
                        Icons.attach_money,
                        _priceController,
                        inputBgColor,
                        inputBorderColor,
                        priceColor,
                        keyboardType: TextInputType.number),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
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
