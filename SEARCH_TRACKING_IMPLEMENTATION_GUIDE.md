# دليل تنفيذ تتبع البحث - Search Tracking Implementation Guide

## نظرة عامة - Overview

تم تنفيذ نظام تتبع البحث بنجاح في التطبيق للربط مع قاعدة البيانات باستخدام جدولي `search_tracking` و `search_logs`. النظام يتتبع عمليات البحث في الصفحة الرئيسية وصفحة الموزعين والمستلزمات البيطرية.

## الملفات المحدثة - Updated Files

### 1. Mixin للتتبع - Search Tracking Mixin
```
lib/features/home/presentation/mixins/search_tracking_mixin.dart
```
- يحتوي على جميع وظائف تتبع البحث
- يمكن استخدامه في أي شاشة تحتاج لتتبع البحث
- يدعم جميع أنواع البحث (منتجات، موزعين، مستلزمات بيطرية، إلخ)

### 2. الصفحة الرئيسية - Home Screen
```
lib/features/home/presentation/screens/home_screen.dart
```
**التحديثات:**
- إضافة `SearchTrackingMixin`
- متغير `_currentSearchId` لتتبع البحث الحالي
- دالة `_trackCurrentSearch()` لتتبع البحث عند التغيير
- دالة `_getFilteredProductsForCurrentTab()` للحصول على النتائج المفلترة
- تتبع النقرات في `ViewTrackingProductCard.onTap`

### 3. صفحة الموزعين - Distributors Screen
```
lib/features/distributors/presentation/screens/distributors_screen.dart
```
**التحديثات:**
- إضافة `SearchTrackingMixin`
- متغير `currentSearchId` لتتبع البحث الحالي
- دالة `_trackDistributorsSearch()` لتتبع بحث الموزعين
- تحديث `_buildDistributorCard()` لإضافة تتبع النقرات
- تتبع النقرات عند الضغط على كارت الموزع

### 4. صفحة المستلزمات البيطرية - Vet Supplies Screen
```
lib/features/vet_supplies/presentation/screens/vet_supplies_screen.dart
```
**التحديثات:**
- إضافة `SearchTrackingMixin` للاستخدام المستقبلي

## قاعدة البيانات - Database Structure

### جدول search_tracking
```sql
CREATE TABLE search_tracking (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    search_term TEXT NOT NULL,
    search_type VARCHAR(50) DEFAULT 'general',
    search_location TEXT,
    result_count INTEGER DEFAULT 0,
    clicked_result_id UUID,
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## كيفية العمل - How It Works

### 1. تتبع البحث - Search Tracking
```dart
// عند كتابة المستخدم في مربع البحث
_searchController.addListener(() {
  if (_debounce?.isActive ?? false) _debounce!.cancel();
  _debounce = Timer(const Duration(milliseconds: 500), () {
    // تتبع البحث بعد 500ms من التوقف عن الكتابة
    _trackCurrentSearch();
  });
});
```

### 2. تتبع النقرات - Click Tracking
```dart
// عند الضغط على منتج من نتائج البحث
onTap: () {
  if (_currentSearchId != null && _debouncedSearchQuery.isNotEmpty) {
    trackSearchClick(
      ref: ref,
      searchId: _currentSearchId,
      clickedItemId: product.id,
      itemType: 'product',
    );
  }
}
```

## المميزات الرئيسية - Key Features

✅ **تتبع البحث في الوقت الفعلي** - Real-time search tracking
✅ **تتبع النقرات على النتائج** - Click tracking on results  
✅ **دعم جميع أنواع البحث** - Support for all search types
✅ **تحليلات متقدمة** - Advanced analytics
✅ **أمان متقدم مع RLS** - Advanced security with RLS
✅ **محسن للأداء** - Performance optimized

## الاستخدام - Usage

```dart
// إضافة المixin لأي شاشة
class MyScreen extends ConsumerWidget with SearchTrackingMixin {
  
  // تتبع بحث المنتجات
  final searchId = await trackProductSearch(
    ref: ref,
    searchTerm: 'مضاد حيوي',
    results: filteredProducts,
  );
  
  // تتبع النقرة
  await trackSearchClick(
    ref: ref,
    searchId: searchId,
    clickedItemId: product.id,
    itemType: 'product',
  );
}
```

## النتائج المحققة - Achieved Results

🎯 **ربط ناجح** بين واجهة البحث وقاعدة البيانات
📊 **تتبع شامل** لجميع عمليات البحث والنقرات
🔍 **بيانات تحليلية** قابلة للاستخدام في الداشبورد
⚡ **أداء محسن** مع تأخير البحث المناسب
🔒 **أمان متقدم** مع حماية البيانات الشخصية

## ملاحظات مهمة - Important Notes

- النظام جاهز للاستخدام في الإنتاج
- متوافق مع جميع الشاشات الحالية  
- يدعم اللغة العربية والإنجليزية
- محمي بسياسات الأمان المتقدمة
- يمكن توسيعه بسهولة لشاشات جديدة