# تعليمات تطبيق النقر على الصور في باقي التابات

## التعديلات المكتملة:
✅ Catalog Products Tab
✅ Distributor Products Tab
✅ Books Tab
✅ Courses Tab

## التابات التي تحتاج تعديل:
- [ ] Jobs Tab
- [ ] VetSupplies Tab
- [ ] Offers Tab
- [ ] Surgical Tools Tab  
- [ ] OCR Products Tab

## الخطوات المطلوبة لكل تاب:

### 1. في DataRow - تحديث استدعاء _buildImage
```dart
// قبل
DataCell(_buildImage(item.imageUrl))

// بعد
DataCell(_buildImage(item.imageUrl, item))
```

### 2. تحديث دالة _buildImage لإضافة Parameter ثاني و InkWell
```dart
// قبل
Widget _buildImage(String url) {
  if (url.isEmpty) return Container(...);
  return ClipRRect(...);
}

// بعد
Widget _buildImage(String url, ItemType item) {
  final Widget imageWidget = url.isEmpty
      ? Container(...)
      : ClipRRect(...);
  
  return InkWell(
    onTap: () => _showDetailsDialog(item),
    child: imageWidget,
  );
}
```

### 3. إضافة _showDetailsDialog جديدة
```dart
void _showDetailsDialog(ItemType item) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Item Details'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة كبيرة
              if (item.imageUrl.isNotEmpty)
                Center(child: CachedNetworkImage(imageUrl: item.imageUrl, width: 250, height: 250, fit: BoxFit.contain)),
              const SizedBox(height: 16),
              
              // التفاصيل المطلوبة
              _buildDetailRow('ID', item.id),
              _buildDetailRow('Name', item.name),
              _buildDetailRow('Price', item.price != null ? '${item.price.toStringAsFixed(2)} EGP' : 'N/A'),
              _buildDetailRow('Distributor', item.distributorId ?? 'N/A'),
              // ...باقي التفاصيل
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}
```

### 4. إضافة _buildDetailRow helper (إذا لم تكن موجودة)
```dart
Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
```

## ملاحظات مهمة:
- Jobs Tab: لا يوجد `distributor`, استخدم 'N/A'
- VetSupplies Tab: لديه `status`, يمكن عرضه
- Offers Tab: يعرض `productId` بدلاً من الاسم  
- Surgical Tools: لديه `distributorName` و `toolName`
- OCR Products: البيانات من `Map<String, dynamic>`
