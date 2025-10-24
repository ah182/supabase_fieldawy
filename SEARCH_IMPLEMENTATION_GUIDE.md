# دليل تطبيق البحث في جميع التابات

## ✅ تم بالفعل:
1. ✅ Catalog Products Tab
2. ✅ Distributor Products Tab

## 📋 المطلوب تطبيقه على باقي التابات:

### Pattern للتطبيق:

#### 1. تحويل ConsumerWidget إلى ConsumerStatefulWidget:
```dart
// قبل:
class _BooksTab extends ConsumerWidget {
  const _BooksTab();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ...
  }
}

// بعد:
class _BooksTab extends ConsumerStatefulWidget {
  const _BooksTab();
  
  @override
  ConsumerState<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends ConsumerState<_BooksTab> {
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

#### 2. إضافة search filter:
```dart
// بعد جلب البيانات:
var items = books; // أو courses, jobs, etc.

// Apply search filter
if (_searchQuery.isNotEmpty) {
  items = items.where((item) {
    final query = _searchQuery.toLowerCase();
    return item.name.toLowerCase().contains(query) || // أو title للكورسات والجوبز
           (item.author?.toLowerCase().contains(query) ?? false) || // للكتب
           (item.phone?.toLowerCase().contains(query) ?? false);
  }).toList();
}
```

#### 3. تغيير الـ layout من ScrollView إلى Column:
```dart
return Column(
  children: [
    // Search TextField
    Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by [fields]...', // غير حسب التاب
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    ),
    
    // Empty state or Data table
    if (items.isEmpty)
      Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.[icon], size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_searchQuery.isNotEmpty ? 'No results found' : 'No [items] found'),
            ],
          ),
        ),
      )
    else
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: PaginatedDataTable(
              // ... باقي الكود
            ),
          ),
        ),
      ),
  ],
);
```

---

## 🔍 Search Fields لكل Tab:

### Books Tab:
```dart
hintText: 'Search by name, author, or phone...'
return book.name.toLowerCase().contains(query) ||
       book.author.toLowerCase().contains(query) ||
       book.phone.toLowerCase().contains(query);
```

### Courses Tab:
```dart
hintText: 'Search by title, or phone...'
return course.title.toLowerCase().contains(query) ||
       course.phone.toLowerCase().contains(query) ||
       course.description.toLowerCase().contains(query);
```

### Jobs Tab:
```dart
hintText: 'Search by title, or phone...'
return job.title.toLowerCase().contains(query) ||
       job.phone.toLowerCase().contains(query) ||
       job.description.toLowerCase().contains(query);
```

### Vet Supplies Tab:
```dart
hintText: 'Search by name, or phone...'
return supply.name.toLowerCase().contains(query) ||
       supply.phone.toLowerCase().contains(query) ||
       supply.description.toLowerCase().contains(query);
```

### Offers Tab:
```dart
hintText: 'Search by product ID...'
return offer['product_id'].toString().toLowerCase().contains(query);
```

### Surgical Tools Tab:
```dart
hintText: 'Search by tool name, company, or distributor...'
return (tool.toolName ?? '').toLowerCase().contains(query) ||
       (tool.company ?? '').toLowerCase().contains(query) ||
       tool.distributorName.toLowerCase().contains(query);
```

### OCR Products Tab:
```dart
hintText: 'Search by OCR product ID or distributor...'
return (product['ocr_product_id'] ?? '').toString().toLowerCase().contains(query) ||
       (product['distributor_name'] ?? '').toString().toLowerCase().contains(query);
```

---

## 📝 خطوات التطبيق السريع:

1. افتح `product_management_screen.dart`
2. لكل tab (Books, Courses, Jobs, Vet Supplies, Offers, Surgical Tools, OCR):
   - حول الـ ConsumerWidget إلى ConsumerStatefulWidget
   - أضف `String _searchQuery = '';`
   - أضف search TextField في البداية
   - طبق الفلتر على البيانات
   - غير الـ layout إلى Column مع Expanded

---

## ✨ الميزات:
- ✅ بحث فوري real-time
- ✅ زر Clear للمسح السريع
- ✅ رسالة مناسبة عند عدم وجود نتائج
- ✅ تصميم موحد لجميع التابات
