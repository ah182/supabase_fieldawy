// ignore_for_file: unused_import

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/distributors/presentation/screens/distributors_screen.dart';
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert'; // Added for jsonDecode

import 'package:fieldawy_store/widgets/refreshable_error_widget.dart';
import 'package:fieldawy_store/features/home/application/user_data_provider.dart';
import 'package:fieldawy_store/features/products/application/catalog_selection_controller.dart';
import 'package:fieldawy_store/features/products/data/product_repository.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:fieldawy_store/features/products/presentation/screens/offer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/widgets/shimmer_loader.dart';
import 'package:fieldawy_store/widgets/custom_product_dialog.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:fieldawy_store/features/products/presentation/screens/bulk_add_review_screen.dart';
// ignore: duplicate_import
import 'package:fieldawy_store/features/products/presentation/screens/add_product_ocr_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fieldawy_store/services/ocr_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddFromCatalogScreen extends ConsumerStatefulWidget {
  final CatalogContext catalogContext;
  final bool showExpirationDate;
  final bool isFromOfferScreen;
  final bool isFromReviewRequest;
  const AddFromCatalogScreen({
    super.key,
    required this.catalogContext,
    this.showExpirationDate = false,
    this.isFromOfferScreen = false,
    this.isFromReviewRequest = false,
  });

  @override
  ConsumerState<AddFromCatalogScreen> createState() =>
      _AddFromCatalogScreenState();

  /// دالة علشان تفتح Dialog فيه تفاصيل المنتج كاملة
  /// معرفة كـ static علشان نقدر نستخدمها من الـ Item
  static void showProductDetailDialog(
      BuildContext context, ProductModel product,
      [String? package]) {
    // إنشاء نسخة مؤقتة من المنتج مع العبوة المحددة
    final productWithPackage = ProductModel(
      id: product.id,
      name: product.name,
      description: product.description,
      activePrinciple: product.activePrinciple,
      company: product.company,
      action: product.action,
      package: package ?? product.selectedPackage,
      availablePackages: product.availablePackages,
      imageUrl: product.imageUrl,
      price: product.price,
      distributorId: product.distributorId,
      createdAt: product.createdAt,
      selectedPackage: package ?? product.selectedPackage,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: CustomProductDialog(product: productWithPackage),
          ),
        );
      },
      transitionBuilder: (context, animation1, animation2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation1,
            curve: Curves.elasticOut,
          ),
          child: FadeTransition(
            opacity: animation1,
            child: child,
          ),
        );
      },
    );
  }
}

class _AddFromCatalogScreenState extends ConsumerState<AddFromCatalogScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _ghostText = '';
  String _fullSuggestion = '';
  List<Map<String, dynamic>> _mainCatalogShuffledDisplayItems = [];
  List<Map<String, dynamic>> _ocrCatalogShuffledDisplayItems = [];
  String? _lastShuffledQuery; // علشان نعرف نعيد الشفل لو البحث اتغير
  String? _lastOcrShuffledQuery; // For OCR catalog search
  bool _isSaving = false;
  bool _isProcessingFile = false;
  bool _isOcrLoading = false;
  bool _hasShownOcrWarning = false;

  @override
  void initState() {
    super.initState();
    

    _searchController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      if (mounted) {
        // إخفاء الكيبورد عند تغيير التاب
        FocusScope.of(context).unfocus();

        // عرض تحذير عند فتح تاب OCR لأول مرة
        if (_tabController!.index == 1 && !_hasShownOcrWarning) {
          _hasShownOcrWarning = true;
          // استخدام Future.delayed لضمان عدم تداخل الـ build
          Future.delayed(Duration.zero, () => _showOcrWarningDialog());
        }

        if (_searchController.text.isEmpty) {
          setState(() {
            _ghostText = '';
            _fullSuggestion = '';
          });
        } else {
          setState(() {});
        }
      }
    });
    _lastShuffledQuery = null; // مش اتعمل شفل لحد دلوقتي
    _lastOcrShuffledQuery = null; // OCR catalog
  }

  void _showOcrWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 28),
            const SizedBox(width: 12),
            const Text(
              'تنبيه هام',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المنتجات في هذا القسم (OCR) تمت إضافتها بواسطة مستخدمين آخرين.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                'قد تحتوي البيانات على بعض الأخطاء غير المقصودة.\n\n'
                'يرجى التأكد بدقة من:\n'
                '• اسم المنتج\n'
                '• صورة المنتج\n'
                '• المادة الفعالة\n'
                '• حجم العبوة\n\n'
                'وذلك قبل إضافتها إلى كتالوجك الخاص.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('فهمت، سأقوم بالمراجعة', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // State is cleared in initState, not here, to avoid lifecycle issues.
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _showTipsDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colorScheme.surface,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- العنوان ---
            Text(
              "تحويل الصورة إلى بيانات",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "صورالورقة بوضوح واجعلها في شكل جدول كما هو موضح ادناه باللغة الانجليزية، وسيتولى الذكاء الاصطناعي الباقي! 🚀\nسيتم استخراج البيانات (اسم الدواء، الحجم، السعر) تلقائياً وتنظيمها في جدول لتوفير وقتك ومجهودك.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? colorScheme.onSurface.withOpacity(0.7) : Colors.grey[600],
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // --- المحاكاة البصرية (صورة -> جدول) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 40, color: isDark ? colorScheme.onSurface.withOpacity(0.5) : Colors.blueGrey),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, color: colorScheme.primary),
                ),
                Icon(Icons.table_chart_rounded, size: 40, color: isDark ? Colors.greenAccent : Colors.green),
              ],
            ),
            const SizedBox(height: 20),

            // --- الجدول التوضيحي (Responsive Table) ---
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? colorScheme.outline.withOpacity(0.3) : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2), // Name (Wider)
                    1: FlexColumnWidth(1.5), // Pack
                    2: FlexColumnWidth(1), // Price
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(
                    horizontalInside: BorderSide(color: isDark ? colorScheme.outline.withOpacity(0.2) : Colors.grey.shade200, width: 1),
                  ),
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(color: isDark ? colorScheme.surfaceVariant.withOpacity(0.5) : Colors.grey.shade100),
                      children: const [
                        Padding(padding: EdgeInsets.all(10), child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(10), child: Text("Package", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(10), child: Text("Price", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    // Data Rows
                    _buildTableRow("Diflam", "100ml vial", "45", isDark, colorScheme),
                    _buildTableRow("Histacure", "100ml vial", "130", isDark, colorScheme),
                    _buildTableRow("Antoplex", "100ml vial", "600", isDark, colorScheme),
                    _buildTableRow("Gentacure", "50ml vial", "125", isDark, colorScheme),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            // --- الأزرار ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("إلغاء"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text("تصوير"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  TableRow _buildTableRow(String name, String pack, String price, bool isDark, ColorScheme colorScheme) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(10), child: Text(name, style: const TextStyle(fontSize: 12))),
        Padding(
          padding: const EdgeInsets.all(10), 
          child: Text(
            pack, 
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? colorScheme.onSurface.withOpacity(0.7) : Colors.grey[700]
            )
          )
        ),
        Padding(
          padding: const EdgeInsets.all(10), 
          child: Text(
            price, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.greenAccent : Colors.green
            )
          )
        ),
      ],
    );
  }

  Future<void> _pickAndProcessImage() async {
    // 1. التحقق من حد الاستخدام (Rate Limit)
    final remaining = OcrService.getRemainingCooldown();
    if (remaining.inSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.timer, color: Colors.white),
              const SizedBox(width: 12),
              Text('يرجى الانتظار ${remaining.inSeconds} ثانية قبل المسح التالي'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. عرض الدليل البصري قبل البدء
    final bool proceed = await _showTipsDialog();
    if (!proceed) return;

    try {
      final ImagePicker picker = ImagePicker();
      // عرض خيار للمستخدم لاختيار الكاميرا أو المعرض
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('اختر مصدر الصورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('الكاميرا'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('المعرض'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await picker.pickImage(source: source);

      if (image != null && mounted) {
        setState(() {
          _isOcrLoading = true;
        });

        File file = File(image.path);
        OcrService service = OcrService();
        
        // استخراج النص (JSON)
        String? jsonResult = await service.extractTextFromImage(file);

        if (mounted) {
          setState(() {
            _isOcrLoading = false;
          });

          if (jsonResult != null && jsonResult.isNotEmpty) {
            try {
              // تنظيف النص من علامات Markdown إذا وجدت (Gemini يحب إضافتها)
              String cleanJson = jsonResult.replaceAll('```json', '').replaceAll('```', '').trim();
              
              final List<dynamic> decodedList = jsonDecode(cleanJson);
              final List<ExtractedItem> extractedItems = [];

              for (var item in decodedList) {
                // استخراج السعر وتنظيفه من أي رموز عملات
                String priceStr = item['price']?.toString() ?? '0';
                // إبقاء الأرقام والنقطة فقط
                priceStr = priceStr.replaceAll(RegExp(r'[^0-9.]'), '');
                
                extractedItems.add(ExtractedItem(
                  name: item['medicine_name']?.toString() ?? '',
                  package: item['package']?.toString() ?? '',
                  price: double.tryParse(priceStr) ?? 0.0,
                ));
              }

              if (extractedItems.isNotEmpty) {
                // الانتقال لشاشة المراجعة (نفس سلوك الإكسل)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BulkAddReviewScreen(extractedItems: extractedItems),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لم يتم العثور على منتجات واضحة في الصورة')),
                );
              }

            } catch (e) {
              print("OCR Parsing Error: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('فشل في قراءة البيانات: تأكد من وضوح الصورة')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل استخراج النص من الصورة'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print("OCR Error: $e");
      if (mounted) {
        setState(() {
          _isOcrLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء المعالجة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showExcelTipsDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colorScheme.surface,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- العنوان ---
            Text(
              "استيراد ملف Excel",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "يجب أن يكون ملف الإكسل منظماً بنفس تنسيق الجدول أدناه (باللغة الإنجليزية) لضمان قراءة البيانات بشكل صحيح.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? colorScheme.onSurface.withOpacity(0.7) : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // --- المحاكاة البصرية (ملف -> جدول) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FontAwesomeIcons.fileExcel, size: 40, color: isDark ? Colors.greenAccent : Colors.green),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, color: colorScheme.primary),
                ),
                Icon(Icons.table_chart_rounded, size: 40, color: isDark ? colorScheme.onSurface.withOpacity(0.5) : Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 20),

            // --- الجدول التوضيحي (Responsive Table) ---
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? colorScheme.outline.withOpacity(0.3) : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2), // Name (Wider)
                    1: FlexColumnWidth(1.5), // Pack
                    2: FlexColumnWidth(1), // Price
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(
                    horizontalInside: BorderSide(color: isDark ? colorScheme.outline.withOpacity(0.2) : Colors.grey.shade200, width: 1),
                  ),
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(color: isDark ? colorScheme.surfaceVariant.withOpacity(0.5) : Colors.grey.shade100),
                      children: const [
                        Padding(padding: EdgeInsets.all(10), child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(10), child: Text("Package", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(10), child: Text("Price", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    // Data Rows
                    _buildTableRow("Diflam", "100ml vial", "45", isDark, colorScheme),
                    _buildTableRow("Histacure", "100ml vial", "130", isDark, colorScheme),
                    _buildTableRow("Antoplex", "100ml vial", "600", isDark, colorScheme),
                    _buildTableRow("Gentacure", "50ml vial", "125", isDark, colorScheme),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            // --- الأزرار ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("إلغاء"),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.upload_file, size: 15),
                    label: const Text("اختيار"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  Future<void> _pickExcelFile() async {
    // عرض الدليل البصري قبل اختيار الملف
    final bool proceed = await _showExcelTipsDialog();
    if (!proceed) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        final path = result.files.single.path;
        if (path != null && mounted) {
          setState(() { _isProcessingFile = true; });
          try {
            await _processExcelFile(path);
          } finally {
            if (mounted) {
              setState(() { _isProcessingFile = false; });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _processExcelFile(String path) async {
    try {
      var bytes = File(path).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      var sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null || sheet.maxRows < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel file is empty or has no data rows.')),
          );
        }
        return;
      }

      // 1. Find column indices from header row
      final headerRow = sheet.row(0);
      final Map<String, int> columnIndices = {};
      for (int i = 0; i < headerRow.length; i++) {
        final cellValue = headerRow[i]?.value?.toString().toLowerCase() ?? '';
        if (cellValue.contains('name') || cellValue.contains('product')) {
          columnIndices['name'] = i;
        } else if (cellValue.contains('package')) {
          columnIndices['package'] = i;
        } else if (cellValue.contains('price')) {
          columnIndices['price'] = i;
        }
      }

      // 2. Validate that the 'name' column was found
      if (!columnIndices.containsKey('name')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel file must contain a column with \'name\' or \'product\' in the header.')),
          );
        }
        return;
      }

      // 3. Process data rows
      List<ExtractedItem> extractedItems = [];
      final nameIndex = columnIndices['name']!;
      final packageIndex = columnIndices['package']; // Can be null
      final priceIndex = columnIndices['price'];   // Can be null

      for (var i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty || row.length <= nameIndex || row[nameIndex] == null) continue;

        final name = row[nameIndex]?.value?.toString();
        
        final package = (packageIndex != null && row.length > packageIndex && row[packageIndex] != null)
                        ? row[packageIndex]!.value?.toString()
                        : '';
        final price = (priceIndex != null && row.length > priceIndex && row[priceIndex] != null)
                      ? double.tryParse(row[priceIndex]!.value?.toString() ?? '')
                      : 0.0;

        if (name != null && name.isNotEmpty) {
          extractedItems.add(ExtractedItem(
            name: name,
            package: package ?? '',
            price: price ?? 0.0,
          ));
        }
      }

      if (mounted) {
        if (extractedItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data could be extracted from the Excel file.')),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BulkAddReviewScreen(extractedItems: extractedItems),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint('Error processing Excel file: $e');
      String errorMessage = 'Error processing file: $e';
      if (e.toString().contains('numFmtId')) {
        errorMessage = 'Unsupported Excel format. Please re-save the file using Microsoft Excel or Google Sheets and try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }



    void _buildMainCatalogShuffledDisplayItems(
      List<ProductModel> filteredProducts, String currentSearchQuery) {
    // لو البحث اتغير أو مش اتعمل شفل لحد دلوقتي، نعمل شفل
    if (_lastShuffledQuery != currentSearchQuery) {
      final List<Map<String, dynamic>> items = [];
      for (var product in filteredProducts) {
        for (var package in product.availablePackages) {
          items.add({'product': product, 'package': package});
        }
      }
      items.shuffle(); // شفل بس مرة وحدة للقائمة الحالية
      setState(() {
        _mainCatalogShuffledDisplayItems = items;
        _lastShuffledQuery = currentSearchQuery; // نخزن نص البحث اللي اتشالّك وقت الشفل
      });
    }
    // لو `_lastShuffledQuery == currentSearchQuery`، يفضل نستخدم نفس `_shuffledDisplayItems`
  }

  void _buildOcrCatalogShuffledDisplayItems(
      List<ProductModel> filteredProducts, String currentSearchQuery) {
    // لو البحث اتغير أو مش اتعمل شفل لحد دلوقتي، نعمل شفل
    if (_lastOcrShuffledQuery != currentSearchQuery) {
      final List<Map<String, dynamic>> items = [];
      for (var product in filteredProducts) {
        for (var package in product.availablePackages) {
          items.add({'product': product, 'package': package});
        }
      }
      items.shuffle(); // شفل بس مرة وحدة للقائمة الحالية
      setState(() {
        _ocrCatalogShuffledDisplayItems = items;
        _lastOcrShuffledQuery = currentSearchQuery; // نخزن نص البحث اللي اتشالّك وقت الشفل
      });
    }
    // لو `_lastOcrShuffledQuery == currentSearchQuery`، يفضل نستخدم نفس `_ocrCatalogShuffledDisplayItems`
  }

  // Helper method to check if OCR product exists or create it
  Future<String?> _checkOrCreateOcrProduct(
    WidgetRef ref,
    String distributorId,
    String distributorName,
    ProductModel product,
    String package,
  ) async {
    try {
      // Check if this specific product with package combination already exists in ocr_products
      final existingOcrProducts = await ref.read(productRepositoryProvider).getOcrProducts();
      final existingProduct = existingOcrProducts.firstWhere(
        (p) => p.name == product.name && 
               p.company == product.company && 
               p.package == package,
        orElse: () => ProductModel(id: '', name: '', availablePackages: [], imageUrl: ''), // Default if not found
      );

      if (existingProduct.id.isNotEmpty) {
        // Product already exists, return its ID
        return existingProduct.id;
      } else {
        // Product doesn't exist, create new one
        final newOcrProductId = await ref.read(productRepositoryProvider).addOcrProduct(
          distributorId: distributorId,
          distributorName: distributorName,
          productName: product.name,
          productCompany: product.company ?? '',
          activePrinciple: product.activePrinciple ?? '',
          package: package,
          imageUrl: product.imageUrl,
        );
        return newOcrProductId;
      }
        } catch (e) {
          print('Error checking/creating OCR product: $e');
          return null;
        }
      }
    
      Future<void> _showEditProductDialog(ProductModel product, String currentPackage) async {
    // الانتقال إلى شاشة AddProductOcrScreen في وضع التعديل
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductOcrScreen(
          productToEdit: product,
          // تمرير بقية المعاملات حسب الحاجة، هنا نفترض الإعدادات الافتراضية مناسبة
          isFromOfferScreen: widget.isFromOfferScreen,
          isFromReviewRequest: widget.isFromReviewRequest,
        ),
      ),
    );

    // تحديث القائمة إذا تم التعديل بنجاح
    if (result == true || result != null) { // Assuming AddProductOcrScreen returns something on success
      if (mounted) {
        ref.invalidate(ocrProductsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث المنتج بنجاح')),
        );
      }
    }
  }
  
    @override
    Widget build(BuildContext context) {
    final allProductsAsync = ref.watch(productsProvider);
    final ocrProductsAsync = ref.watch(ocrProductsProvider);
    final selection = ref.watch(catalogSelectionControllerProvider(widget.catalogContext));

    // Determine which list of items to use based on the active tab
    final currentItems = _tabController?.index == 0
        ? _mainCatalogShuffledDisplayItems
        : _ocrCatalogShuffledDisplayItems;

    // Get the keys for the items in the current tab
    final currentTabKeys = currentItems.map((item) {
      final ProductModel product = item['product'];
      final String package = item['package'];
      return '${product.id}_$package';
    }).toSet();

    // Filter selected items from the current tab that have a valid price
    final validSelections = Map.from(selection.prices)
      ..removeWhere((key, price) => 
        !currentTabKeys.contains(key) || 
        !selection.selectedKeys.contains(key) || 
        price <= 0);

    // === تحديد الألوان المطلوبة للعناصر المخصصة ===
    final Color customElementColor = const Color.fromARGB(255, 119, 186, 225);

    return Theme(
      // نعمل نسخة من الثيم الأساسي ونعدل عليه بس لو الوضع داكن
      data: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).copyWith(
              // === تغيير ألوان الـ Switch بس في الوضع الداكن ===
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return customElementColor; // لون الزرّاعة لما يكون مفعل
                  }
                  return null; // يسيب اللون الافتراضي
                }),
                trackColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return customElementColor
                        .withOpacity(0.5); // لون الخلفية لما يكون مفعل
                  }
                  return null; // يسيب اللون الافتراضي
                }),
              ),
            )
          : Theme.of(context), // لو مش داكن، نسيب الثيم زي ما هو
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // دالة مساعدة لإخفاء الكيبورد
          FocusScope.of(context).unfocus();
          // إعادة تعيين النص الشبحي إذا كان مربع البحث فارغاً
          if (_searchController.text.isEmpty) {
            setState(() {
              _ghostText = '';
              _fullSuggestion = '';
            });
          }
        },
        child: Stack(
          children: [
            Scaffold(
          // === تعديل AppBar علشان يحتوي على SearchBar وعداد المنتجات ===
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إضافة من الكتالوج'),
                if (widget.isFromOfferScreen)
                  Text(
                    'اختر منتج واحد فقط',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
            actions: [
              // زر الـ OCR الجديد
              IconButton(
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                onPressed: _pickAndProcessImage,
                tooltip: 'Scan text from image',
              ),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.fileExcel, color: Colors.green),
                onPressed: _pickExcelFile,
                tooltip: 'Import from Excel',
              ),
            ],
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            // إضافة SearchBar وعداد المنتجات في الـ AppBar
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(
                  kToolbarHeight + 40.0 + kTextTabBarHeight), // زيادة الارتفاع لاستيعاب العداد
              child: Column(
                children: [
                  // === شريط البحث المحسن ===
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Stack(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                            
                            // Update ghost text immediately
                            if (value.isNotEmpty) {
                              final provider = _tabController?.index == 0 ? productsProvider : ocrProductsProvider;
                              final asyncValue = ref.read(provider);
                              
                              if (asyncValue is AsyncData<List<ProductModel>>) {
                                final products = asyncValue.value;
                                final matches = products.where((product) {
                                  return product.name.toLowerCase().startsWith(value.toLowerCase());
                                }).toList();
                                
                                setState(() {
                                  if (matches.isNotEmpty) {
                                    _ghostText = matches.first.name;
                                    _fullSuggestion = matches.first.name;
                                  } else {
                                    _ghostText = '';
                                    _fullSuggestion = '';
                                  }
                                });
                              }
                            } else {
                              setState(() {
                                _ghostText = '';
                                _fullSuggestion = '';
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث عن منتج...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _ghostText = '';
                                        _fullSuggestion = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                        if (_ghostText.isNotEmpty)
                          Positioned(
                            top: 11,
                            right: 55,
                            child: GestureDetector(
                              onTap: () {
                                if (_fullSuggestion.isNotEmpty) {
                                  _searchController.text = _fullSuggestion;
                                  setState(() {
                                    _searchQuery = _fullSuggestion;
                                    _ghostText = '';
                                    _fullSuggestion = '';
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _ghostText,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // === عداد المنتجات المحسن ===
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Builder(builder: (context) {
                          final isMainTab = _tabController?.index == 0;
                          final provider =
                              isMainTab ? productsProvider : ocrProductsProvider;
                          final asyncValue = ref.watch(provider);
                          return asyncValue.when(
                            data: (products) {
                              List<ProductModel> filteredProducts;
                              if (_searchQuery.isEmpty) {
                                filteredProducts = products;
                              } else {
                                filteredProducts = products.where((product) {
                                  final query = _searchQuery.toLowerCase();
                                  final productName = product.name.toLowerCase();
                                  final productCompany =
                                      product.company?.toLowerCase() ?? '';
                                  final productActivePrinciple =
                                      product.activePrinciple?.toLowerCase() ?? '';
                                  return productName.contains(query) ||
                                      productCompany.contains(query) ||
                                      productActivePrinciple.contains(query);
                                }).toList();
                              }
                              int totalItems = 0;
                              for (var p in products) {
                                totalItems += p.availablePackages.length;
                              }
                              int filteredItems = 0;
                              for (var p in filteredProducts) {
                                filteredItems += p.availablePackages.length;
                              }
                              return Text(
                                _searchQuery.isEmpty
                                    ? 'إجمالي العناصر: $totalItems'
                                    : 'عرض $filteredItems من $totalItems عنصر',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              );
                            },
                            loading: () => Text('جارٍ العد...',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w500)),
                            error: (_, __) => Text('خطأ في العد',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w500)),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Main Cataloge'),
                      Tab(text: 'OCR Cataloge'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: validSelections.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: widget.isFromReviewRequest
                      ? () {
                          final selection = ref.read(catalogSelectionControllerProvider(widget.catalogContext));
                          if (selection.prices.isEmpty) return;

                          final selectedKey = selection.prices.keys.first;
                          
                          // Debug
                          print('🔍 CATALOG: Selected Key: $selectedKey');
                          
                          // استخراج الـ product_id من الـ key
                          // الـ key format: "product_id_package"
                          // نحتاج آخر underscore لفصل الـ package
                          final lastUnderscoreIndex = selectedKey.lastIndexOf('_');
                          final productId = lastUnderscoreIndex > 0 
                              ? selectedKey.substring(0, lastUnderscoreIndex)
                              : selectedKey.split('_')[0];
                          
                          final productType = _tabController?.index == 0 ? 'product' : 'ocr_product';

                          print('🔍 CATALOG: Extracted Product ID: $productId');
                          print('🔍 CATALOG: Product Type: $productType');

                          // البحث عن معلومات المنتج (الاسم والصورة)
                          String? productName;
                          String? productImage;
                          
                          final provider = _tabController?.index == 0 ? productsProvider : ocrProductsProvider;
                          final asyncValue = ref.read(provider);
                          
                          asyncValue.whenData((products) {
                            final product = products.firstWhere(
                              (p) => p.id == productId,
                              orElse: () => products.first,
                            );
                            productName = product.name;
                            productImage = product.imageUrl;
                          });

                          Navigator.pop(context, {
                            'product_id': productId,
                            'product_type': productType,
                            'product_name': productName ?? 'منتج',
                            'product_image': productImage ?? '',
                          });
                        }
                      : () async {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isSaving = true;
                    });
                    try {
                      // Check which tab is currently active
                      if (_tabController?.index == 1) {
                        // OCR Tab
                        try {
                          final userModel = await ref.read(userDataProvider.future);
                          final distributorId = userModel?.id;
                          final distributorName = userModel?.displayName ?? 'اسم غير معروف';

                          if (distributorId == null) {
                            throw Exception('User not authenticated');
                          }

                          final selection = ref.read(catalogSelectionControllerProvider(widget.catalogContext));
                          final List<Map<String, dynamic>> ocrProductsToAdd = [];
                          final Set<String> keysToClear = {};

                          // ✅ فحص تواريخ الصلاحية قبل البدء (لـ OCR)
                          if (widget.showExpirationDate || widget.isFromOfferScreen) {
                            for (var item in _ocrCatalogShuffledDisplayItems) {
                              final ProductModel product = item['product'];
                              final String package = item['package'];
                              final String key = '${product.id}_$package';
                              
                              if (selection.selectedKeys.contains(key) && selection.expirationDates[key] == null) {
                                setState(() => _isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    content: AwesomeSnackbarContent(
                                      title: 'تنبيه',
                                      message: 'يرجى تحديد تاريخ الصلاحية للمنتج: ${product.name}',
                                      contentType: ContentType.warning,
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                          }

                          for (var item in _ocrCatalogShuffledDisplayItems) {
                            final ProductModel product = item['product'];
                            final String package = item['package'];
                            final String key = '${product.id}_$package';

                            final isSelectedNow = ref
                                .read(catalogSelectionControllerProvider(widget.catalogContext))
                                .prices
                                .containsKey(key);

                            if (isSelectedNow) {
                              final price = ref
                                      .read(catalogSelectionControllerProvider(widget.catalogContext))
                                      .prices[key] ??
                                  0.0;
                              final expirationDate = ref
                                  .read(catalogSelectionControllerProvider(widget.catalogContext))
                                  .expirationDates[key];
                              if (price > 0) {
                                String? ocrProductId = await _checkOrCreateOcrProduct(
                                  ref,
                                  distributorId,
                                  distributorName,
                                  product,
                                  package,
                                );

                                if (ocrProductId != null) {
                                  ocrProductsToAdd.add({
                                    'ocrProductId': ocrProductId,
                                    'price': price,
                                    'expiration_date': expirationDate?.toIso8601String(),
                                    'package': package,
                                  });
                                  keysToClear.add(key);
                                }
                              }
                            }
                          }

                          if (ocrProductsToAdd.isNotEmpty) {
                            if (widget.isFromOfferScreen) {
                              // حفظ في جدول offers
                              final List<String> offerIds = [];
                              final List<Map<String, dynamic>> offerDetails = [];

                              for (var item in ocrProductsToAdd) {
                                final offerId = await ref.read(productRepositoryProvider).addOffer(
                                      productId: item['ocrProductId'],
                                      isOcr: true,
                                      userId: distributorId,
                                      price: item['price'],
                                      expirationDate: item['expiration_date'] != null
                                          ? DateTime.parse(item['expiration_date'])
                                          : DateTime.now().add(const Duration(days: 365)),
                                      package: item['package'],
                                    );
                                if (offerId != null) {
                                  offerIds.add(offerId);
                                  offerDetails.add(item);
                                }
                              }

                              ref
                                  .read(catalogSelectionControllerProvider(widget.catalogContext).notifier)
                                  .clearSelections(keysToClear);

                              if (context.mounted) {
                                if (offerIds.length == 1) {
                                  // منتج واحد - نفتح صفحة offer_detail_screen
                                  final firstKey = keysToClear.first;
                                  final firstProduct = _ocrCatalogShuffledDisplayItems.firstWhere(
                                      (item) => '${item['product'].id}_${item['package']}' == firstKey);
                                  final productName = firstProduct['product'].name;
                                  final price = offerDetails[0]['price'];
                                  final expirationDate = offerDetails[0]['expiration_date'] != null
                                      ? DateTime.parse(offerDetails[0]['expiration_date'])
                                      : DateTime.now().add(const Duration(days: 365));

                                  await Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => OfferDetailScreen(
                                        offerId: offerIds[0],
                                        productName: productName,
                                        price: price,
                                        expirationDate: expirationDate,
                                      ),
                                    ),
                                  );
                                } else {
                                  // أكثر من منتج - نظهر رسالة نجاح ونرجع
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      elevation: 0,
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.transparent,
                                      content: AwesomeSnackbarContent(
                                        title: 'نجاح',
                                        message: 'تم إضافة ${offerIds.length} منتج للعروض بنجاح',
                                        contentType: ContentType.success,
                                      ),
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                }
                              }
                            } else {
                              // الحفظ العادي في distributor_ocr_products
                              await ref.read(productRepositoryProvider).addMultipleDistributorOcrProducts(
                                    distributorId: distributorId,
                                    distributorName: distributorName,
                                    ocrProducts: ocrProductsToAdd,
                                  );

                              ref
                                  .read(catalogSelectionControllerProvider(widget.catalogContext).notifier)
                                  .clearSelections(keysToClear);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    content: AwesomeSnackbarContent(
                                      title: 'نجاح',
                                      message: 'تم إضافة ${ocrProductsToAdd.length} منتج إلى OCR بنجاح',
                                      contentType: ContentType.success,
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  elevation: 0,
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.transparent,
                                  content: AwesomeSnackbarContent(
                                    title: 'تنبيه',
                                    message: 'الرجاء تحديد منتجات بأسعار صحيحة',
                                    contentType: ContentType.warning,
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                elevation: 0,
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.transparent,
                                content: AwesomeSnackbarContent(
                                  title: 'خطأ',
                                  message: 'فشل إضافة المنتجات إلى OCR: ${e.toString()}',
                                  contentType: ContentType.failure,
                                ),
                              ),
                            );
                          }
                        }
                      } else {
                        // Main Catalog Tab
                        final mainCatalogKeys = _mainCatalogShuffledDisplayItems.map((item) {
                          final ProductModel product = item['product'];
                          final String package = item['package'];
                          return '${product.id}_$package';
                        }).toSet();

                        final selection = ref.read(catalogSelectionControllerProvider(widget.catalogContext));

                        // ✅ فحص تواريخ الصلاحية قبل البدء (للكتالوج الرئيسي)
                        if (widget.showExpirationDate || widget.isFromOfferScreen) {
                          for (var item in _mainCatalogShuffledDisplayItems) {
                            final ProductModel product = item['product'];
                            final String package = item['package'];
                            final String key = '${product.id}_$package';
                            
                            if (selection.selectedKeys.contains(key) && selection.expirationDates[key] == null) {
                              setState(() => _isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  elevation: 0,
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.transparent,
                                  content: AwesomeSnackbarContent(
                                    title: 'تنبيه',
                                    message: 'يرجى تحديد تاريخ الصلاحية للمنتج: ${product.name}',
                                    contentType: ContentType.warning,
                                  ),
                                ),
                              );
                              return;
                            }
                          }
                        }

                        if (widget.isFromOfferScreen) {
                          // حفظ في جدول offers
                          final userModel = await ref.read(userDataProvider.future);
                          final userId = userModel?.id;

                          if (userId != null) {
                            final selection = ref.read(catalogSelectionControllerProvider(widget.catalogContext));
                            final List<String> offerIds = [];
                            final List<Map<String, dynamic>> offerDetails = [];

                            for (var item in _mainCatalogShuffledDisplayItems) {
                              final ProductModel product = item['product'];
                              final String package = item['package'];
                              final String key = '${product.id}_$package';

                              if (selection.prices.containsKey(key)) {
                                final price = selection.prices[key] ?? 0.0;
                                final expirationDate = selection.expirationDates[key] ??
                                    DateTime.now().add(const Duration(days: 365));

                                if (price > 0) {
                                  final offerId = await ref.read(productRepositoryProvider).addOffer(
                                        productId: product.id,
                                        isOcr: false,
                                        userId: userId,
                                        price: price,
                                        expirationDate: expirationDate,
                                        package: package,
                                      );
                                  if (offerId != null) {
                                    offerIds.add(offerId);
                                    offerDetails.add({
                                      'productName': product.name,
                                      'price': price,
                                      'expirationDate': expirationDate,
                                    });
                                  }
                                }
                              }
                            }

                            ref
                                .read(catalogSelectionControllerProvider(widget.catalogContext).notifier)
                                .clearSelections(mainCatalogKeys);

                            if (context.mounted) {
                              if (offerIds.length == 1) {
                                // منتج واحد - نفتح صفحة offer_detail_screen
                                await Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => OfferDetailScreen(
                                      offerId: offerIds[0],
                                      productName: offerDetails[0]['productName'],
                                      price: offerDetails[0]['price'],
                                      expirationDate: offerDetails[0]['expirationDate'],
                                    ),
                                  ),
                                );
                              } else {
                                // أكثر من منتج - نظهر رسالة نجاح ونرجع
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.transparent,
                                    content: AwesomeSnackbarContent(
                                      title: 'نجاح',
                                      message: 'تم إضافة ${offerIds.length} منتج للعروض بنجاح',
                                      contentType: ContentType.success,
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            }
                          }
                        } else {
                          // الحفظ العادي في distributor_products
                          final success = await ref
                              .read(catalogSelectionControllerProvider(widget.catalogContext).notifier)
                              .saveSelections(
                                  keysToSave: mainCatalogKeys, withExpiration: widget.showExpirationDate);

                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                elevation: 0,
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.transparent,
                                content: AwesomeSnackbarContent(
                                  title: 'نجاح',
                                  message: 'تم حفظ المنتجات بنجاح',
                                  contentType: ContentType.success,
                                ),
                              ),
                            );
                            Navigator.of(context).pop();
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                elevation: 0,
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.transparent,
                                content: AwesomeSnackbarContent(
                                  title: 'تنبيه',
                                  message: 'حدث خطأ أثناء حفظ المنتجات أو لا يوجد منتجات للحفظ',
                                  contentType: ContentType.warning,
                                ),
                              ),
                            );
                          }
                        }
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isSaving = false;
                        });
                      }
                    }
                  },
                  label: Text(
                    widget.isFromReviewRequest
                        ? 'تأكيد الاختيار'
                        : 'add_items'.tr(
                            namedArgs: {'count': validSelections.length.toString()},
                          ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.check_rounded),
                  elevation: 2,
                )
              : null,
          body: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  allProductsAsync.when(
                    data: (products) {
                      // === فلترة المنتجات حسب نص البحث (في الاسم، الشركة، والمادة الفعالة) ===
                      List<ProductModel> filteredProducts;
                      if (_searchQuery.isEmpty) {
                        filteredProducts = products;
                      } else {
                        filteredProducts = products.where((product) {
                          // تحويل النص للحروف صغيرة علشان المقارنة تكون case-insensitive
                          final query = _searchQuery.toLowerCase();
                          final productName = product.name.toLowerCase();
                          // تأكد إن الخواص دي موجودة في ProductModel
                          final productCompany =
                              product.company?.toLowerCase() ?? '';
                          final productActivePrinciple =
                              product.activePrinciple?.toLowerCase() ?? '';

                          // بنشوف لو النص موجود في أي واحد من الثلاثة
                          return productName.contains(query) ||
                              productCompany.contains(query) ||
                              productActivePrinciple.contains(query);
                        }).toList();
                      }

                      // === بني القائمة العشوائية إذا لسه ما اتعملتش أو البحث اتغير ===
                      _buildMainCatalogShuffledDisplayItems(filteredProducts, _searchQuery);

                      if (_mainCatalogShuffledDisplayItems.isEmpty) {
                        // عرض رسالة مناسبة لو مفيش منتجات بعد الفلترة والشفل
                        if (_searchQuery.isNotEmpty) {
                          // لو في بحث ونتائج فاضية
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد نتائج للبحث.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // لو مفيش منتجات أصلاً
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد منتجات في الكتالوج الرئيسي.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                ),
                              ],
                            ),
                          );
                        }
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90, top: 8),
                        itemCount:
                            _mainCatalogShuffledDisplayItems.length, // استخدم القائمة العشوائية
                        itemBuilder: (context, index) {
                          final item = _mainCatalogShuffledDisplayItems[index];
                          final ProductModel product = item['product'];
                          final String package = item['package'];
                          return _ProductCatalogItem(
                              key: ValueKey('${product.id}_$package'),
                              catalogContext: widget.catalogContext,
                              product: product,
                              package: package,
                              showExpirationDate: widget.showExpirationDate,
                              singleSelection: widget.isFromOfferScreen || widget.isFromReviewRequest,
                              hidePrice: widget.isFromReviewRequest);
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      itemCount: 6,
                      padding: const EdgeInsets.all(16.0),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ProductCardShimmer(),
                        );
                      },
                    ),
                    error: (error, stack) => RefreshableErrorWidget(
                      message: 'حدث خطأ: $error',
                      onRetry: () => ref.refresh(productsProvider),
                    ),
                  ),
                  // Tab for OCR Catalog - fetch and display OCR products
                  ref.watch(ocrProductsProvider).when(
                    data: (ocrProducts) {
                      // Filter OCR products based on search query
                      List<ProductModel> filteredOcrProducts;
                      if (_searchQuery.isEmpty) {
                        filteredOcrProducts = ocrProducts;
                      } else {
                        filteredOcrProducts = ocrProducts.where((product) {
                          final query = _searchQuery.toLowerCase();
                          final productName = product.name.toLowerCase();
                          final productCompany = product.company?.toLowerCase() ?? '';
                          final productActivePrinciple = product.activePrinciple?.toLowerCase() ?? '';

                          return productName.contains(query) ||
                              productCompany.contains(query) ||
                              productActivePrinciple.contains(query);
                        }).toList();
                      }

                      // Build shuffled display items for OCR products
                      _buildOcrCatalogShuffledDisplayItems(filteredOcrProducts, _searchQuery);

                      if (_ocrCatalogShuffledDisplayItems.isEmpty) {
                        // Show appropriate message if no OCR products
                        if (_searchQuery.isNotEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد نتائج للبحث في OCR.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد منتجات في OCR الكتالوج.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                ),
                              ],
                            ),
                          );
                        }
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90, top: 8),
                        itemCount: _ocrCatalogShuffledDisplayItems.length,
                        itemBuilder: (context, index) {
                          final item = _ocrCatalogShuffledDisplayItems[index];
                          final ProductModel product = item['product'];
                          final String package = item['package'];
                          final currentUserId = ref.watch(userDataProvider).value?.id;
                          final canEdit = currentUserId != null && product.distributorId == currentUserId;

                          return _ProductCatalogItem(
                                  key: ValueKey('${product.id}_$package'),
                                  catalogContext: widget.catalogContext,
                                  product: product,
                                  package: package,
                                  showExpirationDate:
                                      widget.showExpirationDate,
                                  singleSelection: widget.isFromOfferScreen || widget.isFromReviewRequest,
                                  hidePrice: widget.isFromReviewRequest,
                                  canEdit: canEdit,
                                  onEdit: () => _showEditProductDialog(product, package),
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      itemCount: 6,
                      padding: const EdgeInsets.all(16.0),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ProductCardShimmer(),
                        );
                      },
                    ),
                    error: (error, stack) => RefreshableErrorWidget(
                      message: 'حدث خطأ في تحميل OCR: $error',
                      onRetry: () => ref.refresh(ocrProductsProvider),
                    ),
                  ),
                ],
              ),
              if (_isProcessingFile)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_isSaving)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_isOcrLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'جاري استخراج النص من الصورة...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              // Floating Stats Widget
              Positioned(
                left: 16,
                bottom: 16,
                child: Builder(
                  builder: (context) {
                    final isMainTab = _tabController?.index == 0;
                    final products = isMainTab 
                        ? (allProductsAsync.valueOrNull ?? []) 
                        : (ocrProductsAsync.valueOrNull ?? []);

                    final categorized = _categorizeProducts(products);
                    final completeCount = categorized['complete']?.length ?? 0;
                    final missingPriceCount = categorized['missingPrice']?.length ?? 0;
                    final notActivatedCount = categorized['notActivated']?.length ?? 0;

                    // Only show if there are items in any category
                    if (completeCount == 0 && missingPriceCount == 0 && notActivatedCount == 0) {
                      return const SizedBox.shrink();
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Complete Badge
                                if (completeCount > 0)
                                  _StatsBadge(
                                    count: completeCount,
                                    label: 'مكتمل',
                                    color: Colors.green,
                                    icon: Icons.check_circle,
                                    onTap: () => _showStatsDialog('complete', products),
                                  ),
                                if (completeCount > 0 && (missingPriceCount > 0 || notActivatedCount > 0))
                                  const SizedBox(height: 6),
                                // Missing Price Badge
                                if (missingPriceCount > 0)
                                  _StatsBadge(
                                    count: missingPriceCount,
                                    label: 'بدون سعر',
                                    color: Colors.orange,
                                    icon: Icons.warning_amber_rounded,
                                    onTap: () => _showStatsDialog('missingPrice', products),
                                  ),
                                if (missingPriceCount > 0 && notActivatedCount > 0)
                                  const SizedBox(height: 6),
                                // Not Activated Badge
                                if (notActivatedCount > 0)
                                  _StatsBadge(
                                    count: notActivatedCount,
                                    label: 'غير مفعّل',
                                    color: Colors.red,
                                    icon: Icons.toggle_off,
                                    onTap: () => _showStatsDialog('notActivated', products),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: -5,
                          right: -5,
                          child: InkWell(
                            onTap: () {
                              ref.read(catalogSelectionControllerProvider(widget.catalogContext).notifier).clearAll();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color.fromARGB(255, 245, 241, 241)),
                              ),
                              child: Icon(Icons.close, size: 16, color: const Color.fromARGB(255, 243, 136, 136)),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
       
        ],
      ),
      ),
    );
  }

  // Method to calculate product states
  Map<String, List<Map<String, dynamic>>> _categorizeProducts(List<ProductModel> products) {
    final selection = ref.watch(catalogSelectionControllerProvider(widget.catalogContext));

    final Map<String, List<Map<String, dynamic>>> categorized = {
      'complete': [], // مفعّل + كاتب السعر
      'missingPrice': [], // مفعّل + مش كاتب السعر
      'notActivated': [], // كاتب السعر + مش مفعّل
    };

    for (var product in products) {
      for (var package in product.availablePackages) {
        final String key = '${product.id}_$package';
        
        final bool isSelected = selection.selectedKeys.contains(key);
        final double? price = selection.prices[key];
        final bool hasValidPrice = price != null && price > 0;

        if (isSelected && hasValidPrice) {
          // الحالة 1: مفعّل + كاتب السعر
          categorized['complete']!.add({
            'product': product,
            'package': package,
            'key': key,
            'price': price,
          });
        } else if (isSelected && !hasValidPrice) {
          // الحالة 2: مفعّل + مش كاتب السعر
          categorized['missingPrice']!.add({
            'product': product,
            'package': package,
            'key': key,
          });
        } else if (!isSelected && hasValidPrice) {
          // الحالة 3: كاتب السعر + مش مفعّل
          categorized['notActivated']!.add({
            'product': product,
            'package': package,
            'key': key,
            'price': price,
          });
        }
      }
    }

    return categorized;
  }

  // Show stats dialog
  void _showStatsDialog(String category, List<ProductModel> products) {
    final categorized = _categorizeProducts(products);
    final items = categorized[category] ?? [];

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا توجد منتجات في هذه الحالة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String title;
    Color headerColor;
    switch (category) {
      case 'complete':
        title = 'منتجات مكتملة (مفعّلة + بسعر)';
        headerColor = Colors.green;
        break;
      case 'missingPrice':
        title = 'منتجات مفعّلة بدون سعر';
        headerColor = Colors.orange;
        break;
      case 'notActivated':
        title = 'منتجات بسعر لكن غير مفعّلة';
        headerColor = Colors.red;
        break;
      default:
        title = 'منتجات';
        headerColor = Colors.grey;
    }

    showDialog<Map<String, Map<String, String>>?>(
      context: context,
      builder: (context) => _StatsDialog(
        catalogContext: widget.catalogContext,
        title: title,
        headerColor: headerColor,
        items: items,
        category: category,
      ),
    ).then((edits) {
      if (edits == null || edits.isEmpty) {
        return;
      }

      print("======== DIALOG CLOSED WITH EDITS: $edits ========");

      // Update the provider state here, in the main screen's context.
      final controller = ref.read(catalogSelectionControllerProvider(widget.catalogContext).notifier);
      edits.forEach((key, data) {
        final productId = data['productId']!;
        final package = data['package']!;
        final price = data['price']!;
        print(">>> Calling setPrice for key: $key with price: '$price'");
        controller.setPrice(productId, package, price);
      });
    });
  }
}

// Stats Dialog Widget
class _StatsDialog extends ConsumerStatefulWidget {
  final CatalogContext catalogContext;
  final String title;
  final Color headerColor;
  final List<Map<String, dynamic>> items;
  final String category;

  const _StatsDialog({
    required this.catalogContext,
    required this.title,
    required this.headerColor,
    required this.items,
    required this.category,
  });

  @override
  ConsumerState<_StatsDialog> createState() => _StatsDialogState();
}

class _StatsDialogState extends ConsumerState<_StatsDialog> {
  // Map to store temporary price edits (key -> {productId, package, price})
  final Map<String, Map<String, String>> _tempPriceEdits = {};

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.headerColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final product = item['product'] as ProductModel;
                    final package = item['package'] as String;
                    final key = item['key'] as String;
                    final price = item['price'] as double?;

                    return _ProductStatusItem(
                      catalogContext: widget.catalogContext,
                      product: product,
                      package: package,
                      uniqueKey: key,
                      initialPrice: price,
                      category: widget.category,
                      onPriceChanged: (newPrice) {
                        // حفظ مؤقت في الـ Dialog
                        _tempPriceEdits[key] = {
                          'productId': product.id,
                          'package': package,
                          'price': newPrice,
                        };
                      },
                    );
                  },
                ),
              ),
              // Close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    // Don't update the state here.
                    // Just pop and return the temporary edits.
                    Navigator.pop(context, _tempPriceEdits);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

// Product Status Item Widget
class _ProductStatusItem extends ConsumerStatefulWidget {
  final CatalogContext catalogContext;
  final ProductModel product;
  final String package;
  final String uniqueKey;
  final double? initialPrice;
  final String category;
  final Function(String)? onPriceChanged;

  const _ProductStatusItem({
    required this.catalogContext,
    required this.product,
    required this.package,
    required this.uniqueKey,
    this.initialPrice,
    required this.category,
    this.onPriceChanged,
  });

  @override
  ConsumerState<_ProductStatusItem> createState() => _ProductStatusItemState();
}

class _ProductStatusItemState extends ConsumerState<_ProductStatusItem> {
  late TextEditingController _priceController;
  
  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.initialPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(catalogSelectionControllerProvider(widget.catalogContext));
    final isSelected = selection.selectedKeys.contains(widget.uniqueKey);
    
    // تحديث السعر من الـ state فقط إذا مفيش callback (يعني مش في Dialog)
    if (widget.onPriceChanged == null) {
      final currentPrice = selection.prices[widget.uniqueKey];
      if (currentPrice != null && currentPrice > 0) {
        if (_priceController.text != currentPrice.toString()) {
          _priceController.text = currentPrice.toString();
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.product.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[200],
                  child: const Icon(Icons.medication, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (widget.package.isNotEmpty)
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.package,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Price Field
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _priceController,
                      enabled: true,
                      onChanged: (value) {
                        // إذا كان في callback، نستخدمه (من الـ Dialog)
                        if (widget.onPriceChanged != null) {
                          // حفظ أي تغيير حتى لو السعر فاضي
                          widget.onPriceChanged!(value);
                        } else {
                          // من الشاشة الأساسية - حفظ مباشرة
                          final controller = ref.read(
                              catalogSelectionControllerProvider(widget.catalogContext).notifier);

                          if (value.trim().isEmpty) {
                            controller.setPrice(widget.product.id, widget.package, '0');
                          } else {
                            controller.setPrice(widget.product.id, widget.package, value);
                          }
                        }
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'price'.tr(),
                        prefixText: 'EGP ',
                        prefixStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                            width: 1.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.3),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        hintText: isSelected ? null : 'حدد المنتج',
                        hintStyle: TextStyle(
                          color: Theme.of(context).disabledColor,
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Toggle
            Switch(
              value: isSelected,
              onChanged: (value) {
                final priceText = _priceController.text.isEmpty ? '0' : _priceController.text;
                ref
                    .read(catalogSelectionControllerProvider(widget.catalogContext).notifier)
                    .toggleProduct(
                      widget.product.id,
                      widget.package,
                      priceText,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Stats Badge Widget
class _StatsBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatsBadge({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCatalogItem extends HookConsumerWidget {
  final CatalogContext catalogContext;
  final ProductModel product;
  final String package;
  final bool showExpirationDate;
  final bool singleSelection;
  final bool hidePrice;
  final bool canEdit;
  final VoidCallback? onEdit;

  const _ProductCatalogItem({
    super.key,
    required this.catalogContext,
    required this.product,
    required this.package,
    this.showExpirationDate = false,
    this.singleSelection = false,
    this.hidePrice = false,
    this.canEdit = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(catalogSelectionControllerProvider(catalogContext));
    final uniqueKey = '${product.id}_$package';
    final isSelected = selection.selectedKeys.contains(uniqueKey);

    final priceController = useTextEditingController();
    final expirationDateController = useTextEditingController();
    final focusNode = useMemoized(() => FocusNode(), const []);
    final expirationDateFocusNode = useMemoized(() => FocusNode(), const []);
    

    useEffect(() {
      // This effect ALWAYS synchronizes the text field with the provider state.
      // The user's input is now only sent to the provider on "onEditingComplete",
      // which prevents race conditions.

      // HACK: Force-read the latest state from the provider to bypass a timing
      // issue where the `selection` object from the build method is stale.
      final latestSelection = ref.read(catalogSelectionControllerProvider(catalogContext));
      final priceFromState = latestSelection.prices[uniqueKey];
      final isSelectedNow = latestSelection.selectedKeys.contains(uniqueKey);

      final priceString = (priceFromState == null || priceFromState <= 0) ? '' : priceFromState.toString();

      if (priceController.text != priceString) {
        priceController.text = priceString;
      }
      
      if (!isSelectedNow) {
        if (expirationDateController.text.isNotEmpty) {
          expirationDateController.clear();
        }
      }
      
      return null;
    }, [selection]); // Depend only on selection for robustness

    // State for debouncing
    final debounceTimer = useState<Timer?>(null);

    // تنظيف
    useEffect(() {
      return () {
        focusNode.dispose();
        expirationDateFocusNode.dispose();
        debounceTimer.value?.cancel(); // Cancel timer on dispose
      };
    }, const []);

    // === استخدام Container بدلاً من Card مع التصميم المحسن ===
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === تحسين الصورة مع إمكانية المعاينة ===
              GestureDetector(
                onTap: () {
                  // استدعاء الدالة كـ static من الـ StatefulWidget
                  AddFromCatalogScreen.showProductDetailDialog(
                      context, product, package);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: ImageLoadingIndicator(size: 24),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          size: 28,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === تحسين اسم المنتج بحجم أصغر ===
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // عرض اسم الموزع الأصلي في تاب الـ OCR فقط
                              if (product.distributorUuid != null || (product.distributorId != null && product.distributorId!.isNotEmpty))
                                Consumer(
                                  builder: (context, ref, child) {
                                    final distributorsAsync = ref.watch(distributorsProvider);
                                    // محاولة البحث بالـ UUID أو بالاسم (في حال كان الـ ID مخزناً في حقل distributorId)
                                    final currentName = distributorsAsync.maybeWhen(
                                      data: (distributors) {
                                        final dist = distributors.firstWhereOrNull((d) => 
                                          d.id == product.distributorUuid || 
                                          d.id == product.distributorId
                                        );
                                        return dist?.displayName;
                                      },
                                      orElse: () => null,
                                    );
                                    
                                    // إذا لم نجد الاسم في القائمة، نعرض الاسم المخزن بشرط ألا يكون UUID
                                    final finalDisplayName = currentName ?? 
                                      (product.distributorId != null && !product.distributorId!.contains('-') 
                                        ? product.distributorId 
                                        : null);

                                    if (finalDisplayName == null) return const SizedBox.shrink();
                                    
                                    return Text(
                                      'بواسطة: $finalDisplayName',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        if (canEdit && onEdit != null)
                          InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.edit_note_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // === تحسين الباكدج ===
                    if (package.isNotEmpty)
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            package,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // === حقل السعر المحسن ===
                    if (!hidePrice)
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: priceController,
                          focusNode: focusNode,
                          enabled: true,
                          textInputAction: TextInputAction.done,
                          onChanged: (value) {
                            // Debounce the input to update the state only when the user stops typing.
                            debounceTimer.value?.cancel();
                            debounceTimer.value = Timer(const Duration(seconds: 3), () {
                              final controller = ref.read(catalogSelectionControllerProvider(catalogContext).notifier);
                              if (value.trim().isEmpty) {
                                controller.setPrice(product.id, package, '0');
                              } else {
                                controller.setPrice(product.id, package, value);
                              }
                            });
                          },
                          onEditingComplete: () {
                            // When editing is done, cancel any pending timer and update immediately.
                            debounceTimer.value?.cancel();
                            final controller = ref.read(catalogSelectionControllerProvider(catalogContext).notifier);
                            final value = priceController.text;
                            if (value.trim().isEmpty) {
                              controller.setPrice(product.id, package, '0');
                            } else {
                              controller.setPrice(product.id, package, value);
                            }
                            focusNode.unfocus();
                          },
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'price'.tr(),
                          prefixText: 'EGP ',
                          prefixStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.5)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.3),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          hintText: isSelected ? null : 'حدد المنتج',
                          hintStyle: TextStyle(
                            color: Theme.of(context).disabledColor,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    if (showExpirationDate) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: expirationDateController,
                          focusNode: expirationDateFocusNode,
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
                              expirationDateController.text = formattedDate;
                              ref
                                  .read(catalogSelectionControllerProvider(catalogContext)
                                      .notifier)
                                  .setExpirationDate(
                                      product.id, package, picked);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Expiration Date (YYYY-MM)',
                            prefixIcon: Icon(Icons.calendar_today,
                                color: Theme.of(context).colorScheme.primary),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.3),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // === تحسين الـ Switch ===
              Switch.adaptive(
                value: isSelected,
                onChanged: (value) {
                  final controller = ref.read(catalogSelectionControllerProvider(catalogContext).notifier);
                  
                  // إذا كان singleSelection مفعل ونريد اختيار منتج جديد
                  if (singleSelection && value) {
                    // امسح كل الاختيارات السابقة أولاً
                    final currentSelections = ref.read(catalogSelectionControllerProvider(catalogContext)).prices.keys.toSet();
                    controller.clearSelections(currentSelections);
                  }
                  
                  // عند hidePrice، نستخدم قيمة افتراضية (1) بدلاً من قيمة حقل السعر
                  // التأكد من أننا لا نمرر نصًا فارغًا للسعر لتجنب خطأ التحويل
                  final priceText = priceController.text.isEmpty ? '0' : priceController.text;
                  controller.toggleProduct(product.id, package, hidePrice ? '1' : priceText);

                  // لو المنتج بقى محدد، نركز على حقل السعر (إلا إذا كان مخفي)
                  if (value && !hidePrice) {
                    // استخدام Future.microtask علشان نتأكد إن الحقل اتشالّك قبل ما نركز عليه
                    Future.microtask(() {
                      focusNode.requestFocus();
                    });
                  } else if (!value) {
                    // لو اتشال التحديد، نمسح النص ونخلّي الحقل يفقد التركيز
                    if (!hidePrice) {
                      priceController.clear();
                      focusNode.unfocus();
                    }
                    expirationDateController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
