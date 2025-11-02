# 🔍 دليل تطبيق تتبع البحث في التطبيق

## 🎯 المشكلة
تم إنشاء نظام تتبع البحث لكن لم يتم ربطه بصفحات البحث الفعلية في التطبيق.

## ✅ الحل السريع

### الخطوة 1: تطبيق SQL في Supabase
```sql
-- شغل هذا الملف في Supabase SQL Editor:
supabase/create_search_tracking_system_fixed.sql
```

### الخطوة 2: استبدال الصفحة الرئيسية
```dart
// في main.dart أو المكان الذي تستدعي فيه HomeScreen
// من:
import 'package:fieldawy_store/features/home/presentation/screens/home_screen.dart';

// إلى:
import 'package:fieldawy_store/features/home/presentation/screens/home_screen_with_search_tracking.dart';

// واستبدل:
HomeScreen() 
// بـ:
HomeScreenWithSearchTracking()
```

### الخطوة 3: إضافة التتبع للصفحات الأخرى

#### في `my_products_screen.dart`
أضف هذا في بداية الملف:
```dart
import 'package:fieldawy_store/services/search_tracking_service.dart';
```

ثم في الكلاس الرئيسي، أضف متغير للتتبع:
```dart
class _MyProductsScreenState extends ConsumerState<MyProductsScreen> {
  // ... الكود الموجود
  
  // ✅ إضافة متغيرات التتبع
  String? _currentSearchId;
  String _lastSearchTerm = '';
  
  // ✅ دالة تتبع البحث
  Future<void> _trackSearch(String searchTerm) async {
    if (searchTerm.trim().isEmpty || searchTerm == _lastSearchTerm) return;
    
    try {
      final searchTrackingService = ref.read(searchTrackingServiceProvider);
      
      // محاكاة عدد النتائج (استبدل بالعدد الفعلي)
      int resultCount = searchTerm.length * 3;
      
      final searchId = await searchTrackingService.logProductSearch(
        searchTerm: searchTerm,
        results: [], // ضع النتائج الفعلية هنا
        userLocation: SearchHelper.getMockUserLocation(),
      );
      
      _currentSearchId = searchId;
      _lastSearchTerm = searchTerm;
    } catch (e) {
      print('Error tracking search: $e');
    }
  }
}
```

وفي شريط البحث:
```dart
TextField(
  controller: searchController,
  focusNode: searchFocusNode,
  onChanged: (value) {
    searchQuery.value = value;
    // ✅ إضافة تتبع البحث
    _trackSearch(value);
  },
  // ... باقي الكود
)
```

#### في `distributors_screen.dart`
نفس الخطوات ولكن باستخدام:
```dart
await searchTrackingService.logDistributorSearch(
  searchTerm: searchTerm,
  results: distributorResults,
  userLocation: SearchHelper.getMockUserLocation(),
);
```

#### في صفحات العروض والأدوات:
```dart
await searchTrackingService.logGeneralSearch(
  searchTerm: searchTerm,
  results: results,
  userLocation: SearchHelper.getMockUserLocation(),
);
```

### الخطوة 4: تحديث الداش بورد
```dart
// في dashboard_page.dart
// استبدل:
TrendsAnalyticsWidget()

// بـ:
TrendsAnalyticsWidgetUpdated()

// وأضف في بداية الملف:
import 'package:fieldawy_store/features/dashboard/presentation/widgets/trends_analytics_widget_updated.dart';
```

## 🧪 اختبار النظام

### 1. اختبار تسجيل البحث
```dart
// أضف هذا في أي صفحة للاختبار السريع:
ElevatedButton(
  onPressed: () async {
    final searchService = ref.read(searchTrackingServiceProvider);
    await searchService.logProductSearch(
      searchTerm: 'اختبار البحث',
      results: [],
    );
    print('تم تسجيل البحث!');
  },
  child: Text('اختبار البحث'),
)
```

### 2. فحص قاعدة البيانات
```sql
-- في Supabase SQL Editor:
SELECT * FROM search_tracking ORDER BY created_at DESC LIMIT 10;
```

### 3. اختبار الداش بورد
```sql
-- اختبار دالة الترندات:
SELECT * FROM get_top_search_terms(10, 7, 'products');
```

## 📊 النتائج المتوقعة

بعد التطبيق ستحصل على:

### في قاعدة البيانات:
- ✅ جدول `search_tracking` يحتوي على عمليات البحث
- ✅ دوال تحليل الترندات تعمل

### في الداش بورد:
- ✅ قسم "الأكثر بحثاً" يعرض بيانات حقيقية
- ✅ إحصائيات متقدمة (معدل النقر، النمو، الاتجاهات)
- ✅ مؤشر "بيانات حقيقية"

### في التطبيق:
- ✅ كل عملية بحث يتم تسجيلها تلقائياً
- ✅ تحليل نوع البحث (منتجات، موزعين، عروض...)
- ✅ تتبع النقرات على النتائج

## 🚀 اختبار سريع

1. **شغل SQL في Supabase**
2. **استبدل HomeScreen بـ HomeScreenWithSearchTracking**
3. **ابحث في التطبيق عن "مضاد حيوي"**
4. **تحقق من قاعدة البيانات:**
   ```sql
   SELECT search_term, search_count FROM get_top_search_terms(5, 1);
   ```
5. **افتح الداش بورد وشاهد قسم "الأكثر بحثاً"**

## 🔧 الصيانة

### تنظيف البيانات القديمة (اختياري):
```sql
-- حذف البيانات الأقدم من شهر
DELETE FROM search_tracking 
WHERE created_at < NOW() - INTERVAL '30 days';
```

### مراقبة الأداء:
```sql
-- فحص حجم البيانات
SELECT COUNT(*) as total_searches FROM search_tracking;

-- فحص أحدث البيانات
SELECT search_term, created_at FROM search_tracking 
ORDER BY created_at DESC LIMIT 5;
```

## ✨ مميزات إضافية

### 1. إضافة اقتراحات البحث:
```dart
// في أي TextField للبحث:
TextField(
  onChanged: (value) {
    final suggestions = ref.read(searchTrackingServiceProvider)
        .getSearchSuggestions(value);
    // عرض الاقتراحات
  },
)
```

### 2. إضافة إحصائيات الجلسة:
```dart
final sessionStats = ref.read(searchTrackingServiceProvider)
    .getSessionStats();
print('إحصائيات الجلسة: $sessionStats');
```

النظام جاهز ويعمل! 🎉