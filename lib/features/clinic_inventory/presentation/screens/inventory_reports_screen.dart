import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:pdfrx/pdfrx.dart'; // For rendering PDF pages to images
import 'package:image/image.dart' as img; // For image encoding
import 'dart:typed_data';

import 'package:fieldawy_store/widgets/invoice_preview_screen.dart';
import '../../data/services/inventory_report_pdf_service.dart';
import '../../data/models/clinic_inventory_item.dart';
import '../../data/models/inventory_transaction.dart';
import '../../data/services/clinic_inventory_service.dart';

/// شاشة التقارير
class InventoryReportsScreen extends ConsumerStatefulWidget {
  const InventoryReportsScreen({super.key});
  @override
  ConsumerState<InventoryReportsScreen> createState() =>
      _InventoryReportsScreenState();
}

class _InventoryReportsScreenState
    extends ConsumerState<InventoryReportsScreen> {
  String _selectedPeriod = 'daily';
  InventoryReportSummary? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(clinicInventoryServiceProvider);
      DateTime start, end = DateTime.now();

      switch (_selectedPeriod) {
        case 'daily':
          start = end;
          break;
        case 'weekly':
          start = end.subtract(const Duration(days: 7));
          break;
        case 'monthly':
          start = DateTime(end.year, end.month, 1);
          break;
        default:
          start = end;
      }

      final report = await service.getReportSummary(
        startDate: start,
        endDate: end,
        periodType: _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(theme, cs, isArabic),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _report == null
                    ? Center(
                        child: Text(isArabic ? 'لا توجد بيانات' : 'No Data',
                            style: theme.textTheme.bodyLarge))
                    : _buildContent(theme, cs, isArabic),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs, bool isArabic) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primary.withOpacity(0.8),
            cs.secondary.withOpacity(0.6)
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12)),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isArabic ? 'التقارير' : 'Reports',
                            style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                            isArabic
                                ? 'ملخص المبيعات والأرباح'
                                : 'Sales & Profit Summary',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12)),
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.white, size: 20),
                      onPressed: _exportReport,
                      tooltip: isArabic ? 'تصدير التقرير' : 'Export Report',
                    ),
                  ),
                  const SizedBox(width: 8), // Added spacing between buttons
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12)),
                    child: IconButton(
                      icon: const Icon(Icons.print_outlined,
                          color: Colors.white, size: 20),
                      onPressed: _exportReport,
                      tooltip: isArabic ? 'طباعة التقرير' : 'Print Report',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPeriodSelector(cs, isArabic),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(ColorScheme cs, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _periodBtn(isArabic ? 'يومي' : 'Daily', 'daily'),
          _periodBtn(isArabic ? 'أسبوعي' : 'Weekly', 'weekly'),
          _periodBtn(isArabic ? 'شهري' : 'Monthly', 'monthly'),
        ],
      ),
    );
  }

  Widget _periodBtn(String label, String value) {
    final sel = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
          _loadReport();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color:
                    sel ? Theme.of(context).colorScheme.primary : Colors.white,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme cs, bool isArabic) {
    final r = _report!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ملخص الأرقام
          Row(
            children: [
              Expanded(
                  child: _summaryCard(
                      theme,
                      isArabic ? 'إجمالي المبيعات' : 'Total Sales',
                      '${r.totalSales.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}',
                      CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Arrow-Trend-Up-icon.png',
                        width: 20,
                        height: 20,
                        color: Colors.green,
                        placeholder: (context, url) => const Icon(
                            Icons.trending_up,
                            color: Colors.green,
                            size: 20),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.trending_up,
                            color: Colors.green,
                            size: 20),
                      ),
                      Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _summaryCard(
                      theme,
                      isArabic ? 'إجمالي الربح' : 'Total Profit',
                      '${r.totalProfit.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}',
                      CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Money-Bill-Wave-icon.png',
                        width: 20,
                        height: 20,
                        color: Colors.blue,
                        placeholder: (context, url) => const Icon(
                            Icons.attach_money,
                            color: Colors.blue,
                            size: 20),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.attach_money,
                            color: Colors.blue,
                            size: 20),
                      ),
                      Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _summaryCard(
                      theme,
                      isArabic ? 'عدد المبيعات' : 'Sales Count',
                      '${r.totalSellCount}',
                      CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Receipt-icon.png',
                        width: 20,
                        height: 20,
                        color: Colors.purple,
                        placeholder: (context, url) => const Icon(
                            Icons.receipt_long,
                            color: Colors.purple,
                            size: 20),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.receipt_long,
                            color: Colors.purple,
                            size: 20),
                      ),
                      Colors.purple)),
              const SizedBox(width: 12),
              Expanded(
                  child: _summaryCard(
                      theme,
                      isArabic ? 'نسبة الربح' : 'Profit Margin',
                      '${r.profitMargin.toStringAsFixed(1)}%',
                      CachedNetworkImage(
                        imageUrl:
                            'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Chart-Pie-icon.png',
                        width: 20,
                        height: 20,
                        color: Colors.orange,
                        placeholder: (context, url) => const Icon(
                            Icons.pie_chart,
                            color: Colors.orange,
                            size: 20),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.pie_chart,
                            color: Colors.orange,
                            size: 20),
                      ),
                      Colors.orange)),
            ],
          ),

          const SizedBox(height: 24),

          // التفاصيل اليومية
          Text(isArabic ? 'التفاصيل' : 'Details',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (r.dailySummaries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 48, color: cs.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                        isArabic
                            ? 'لا توجد عمليات في هذه الفترة'
                            : 'No transactions in this period',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: r.dailySummaries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _dayCard(theme, cs, r.dailySummaries[i]),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(
      ThemeData theme, String label, String value, Widget icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: icon,
          ),
          const SizedBox(height: 12),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _dayCard(ThemeData theme, ColorScheme cs, DailySummary day) {
    final isArabic = context.locale.languageCode == 'ar';
    final dateStr = isArabic
        ? DateFormat('EEEE, d MMM', 'ar').format(day.date)
        : DateFormat('EEEE, d MMM', 'en').format(day.date);

    return _ExpandableDayCard(
      day: day,
      dateStr: dateStr,
      service: ref.read(clinicInventoryServiceProvider),
    );
  }

  Future<void> _exportReport() async {
    if (_report == null) return;
    final isArabic = context.locale.languageCode == 'ar';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    PdfDocument? doc; // From pdfrx
    try {
      final service = ref.read(clinicInventoryServiceProvider);
      // Fetch detailed transactions for the export period
      final transactions = await service.getTransactionsByPeriod(
          _report!.startDate, _report!.endDate);

      final pdfService = InventoryReportPdfService();
      final pdfBytes = await pdfService.createReport(
        date: _report!.endDate,
        transactions: transactions,
        totalSales: _report!.totalSales,
        totalProfit: _report!.totalProfit,
      );

      // Render to images for preview using pdfrx
      doc = await PdfDocument.openData(pdfBytes);
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final List<Uint8List> imageBytesList = [];

      for (var i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        final pageImage = await page.render(
          width: (page.width * dpr * 0.5).toInt(),
          height: (page.height * dpr * 0.5).toInt(),
        );
        if (pageImage != null) {
          final image = img.Image.fromBytes(
            width: pageImage.width,
            height: pageImage.height,
            bytes: pageImage.pixels.buffer,
            order: img.ChannelOrder.rgba,
          );
          imageBytesList.add(img.encodePng(image));
        }
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader

        if (imageBytesList.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoicePreviewScreen(
                imageBytesList: imageBytesList,
                pdfBytes: pdfBytes,
                title: isArabic ? 'معاينة التقرير' : 'Report Preview',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Export Error: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isArabic ? 'حدث خطأ أثناء التصدير: $e' : 'Export Error: $e')),
        );
      }
    } finally {
      await doc?.dispose();
    }
  }
}

/// ويدجت بطاقة اليوم القابلة للتوسيع لعرض تفاصيل العمليات
class _ExpandableDayCard extends StatefulWidget {
  final DailySummary day;
  final String dateStr;
  final ClinicInventoryService service;

  const _ExpandableDayCard({
    required this.day,
    required this.dateStr,
    required this.service,
  });

  @override
  State<_ExpandableDayCard> createState() => _ExpandableDayCardState();
}

class _ExpandableDayCardState extends State<_ExpandableDayCard> {
  bool _isExpanded = false;
  List<InventoryTransaction>? _transactions;
  bool _loading = false;

  Future<void> _loadTransactions() async {
    if (_transactions != null) return;

    setState(() => _loading = true);
    final txs = await widget.service.getTransactionsByDate(widget.day.date);
    if (mounted) {
      setState(() {
        _transactions = txs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // الهيدر (قابل للضغط)
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded) _loadTransactions();
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.day.date.day}',
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: cs.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.dateStr,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _miniStat(
                                theme,
                                isArabic ? 'مبيعات' : 'Sales',
                                '${widget.day.totalSales.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}',
                                Colors.green),
                            const SizedBox(width: 12),
                            _miniStat(
                                theme,
                                isArabic ? 'ربح' : 'Profit',
                                '${widget.day.totalProfit.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}',
                                Colors.blue),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${widget.day.sellCount} ${isArabic ? "عملية" : "Tx"}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
                      const SizedBox(height: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: cs.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // التفاصيل المُوسّعة
          if (_isExpanded)
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.3),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                    )
                  : _transactions == null || _transactions!.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                                isArabic ? 'لا توجد عمليات' : 'No transactions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withOpacity(0.5))),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _transactions!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildTransactionItem(
                              theme, cs, _transactions![i]),
                        ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
      ThemeData theme, ColorScheme cs, InventoryTransaction tx) {
    final isSell = tx.transactionType == TransactionType.sell;
    final color = isSell ? Colors.green : Colors.blue;
    final icon = isSell ? Icons.point_of_sale : Icons.add_box;
    final isArabic = context.locale.languageCode == 'ar';

    String title = tx.productName ?? (isArabic ? 'منتج غير محدد' : 'Unknown');
    Widget subtitleWidget;
    final subStyle = theme.textTheme.labelSmall
        ?.copyWith(color: cs.onSurface.withOpacity(0.6));

    if (isSell) {
      String unitDisplay = tx.unitSold ?? '';
      if (unitDisplay == 'piece') {
        if (tx.package != null) {
          final lowerPkg = tx.package!.toLowerCase();
          if (lowerPkg.contains('ml')) {
            unitDisplay = 'ml';
          } else if (lowerPkg.contains('gm') || lowerPkg.contains('g')) {
            unitDisplay = isArabic ? 'جرام' : 'g';
          } else if (lowerPkg.contains('tab') || lowerPkg.contains('cap')) {
            unitDisplay = isArabic ? 'قرص' : 'tab';
          } else if (lowerPkg.contains('amp')) {
            unitDisplay = isArabic ? 'أمبول' : 'amp';
          } else {
            unitDisplay = isArabic ? 'وحدة' : 'unit';
          }
        } else {
          unitDisplay = isArabic ? 'وحدة' : 'unit';
        }
      } else if (unitDisplay == 'box') {
        unitDisplay = isArabic ? 'علبة' : 'box';
      }

      final isLatin = unitDisplay.contains(RegExp(r'[a-zA-Z]'));

      subtitleWidget = Row(
        children: [
          Text(isArabic ? 'بيع ' : 'Sell ', style: subStyle),
          Directionality(
            textDirection: isLatin ? TextDirection.ltr : TextDirection.rtl,
            child: Text('${tx.quantitySold.toStringAsFixed(0)} $unitDisplay',
                style: subStyle?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Text(
              ' • ${tx.sellingPrice?.toStringAsFixed(0) ?? 0} ${isArabic ? "ج" : "EGP"}',
              style: subStyle),
        ],
      );
    } else {
      subtitleWidget = Text(
          isArabic
              ? 'إضافة ${tx.boxesAdded} علبة • ${tx.totalPurchaseCost?.toStringAsFixed(0) ?? 0} ج'
              : 'Add ${tx.boxesAdded} Box • ${tx.totalPurchaseCost?.toStringAsFixed(0) ?? 0} EGP',
          style: subStyle);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CachedNetworkImage(
              imageUrl: isSell
                  ? 'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Cash-Register-icon.png'
                  : 'https://icons.iconarchive.com/icons/fa-team/fontawesome/128/FontAwesome-Box-Open-icon.png',
              width: 16,
              height: 16,
              color: color,
              placeholder: (context, url) => Icon(icon, color: color, size: 16),
              errorWidget: (context, url, error) =>
                  Icon(icon, color: color, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitleWidget,
              ],
            ),
          ),
          if (isSell && tx.profit != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tx.profit! >= 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${tx.profit! >= 0 ? '+' : ''}${tx.profit!.toStringAsFixed(0)} ${isArabic ? "ج" : "EGP"}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tx.profit! >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniStat(ThemeData theme, String label, String value, Color color) {
    return Row(
      children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(value,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
