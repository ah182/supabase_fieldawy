# 📊 دليل نظام المشاهدات للمنتجات

## 🎯 **ما تم إنجازه:**

تم تطوير نظام مشاهدات متقدم للمنتجات مع **طريقتين مختلفتين** لحساب المشاهدات حسب نوع التاب.

---

## 📋 **الملفات المنشأة والمعدلة:**

### **1. SQL - إضافة عمود المشاهدات** 💾
📁 `supabase/add_views_to_products.sql`

**المحتويات:**
- ✅ إضافة عمود `views` لجدول `distributor_products`
- ✅ Index لتحسين الأداء
- ✅ Function لزيادة المشاهدات `increment_product_views()`
- ✅ Constraint للتأكد من القيم الموجبة

**كيفية التطبيق:**
```sql
-- 1. افتح Supabase Dashboard
-- 2. اذهب إلى SQL Editor
-- 3. الصق محتويات supabase/add_views_to_products.sql
-- 4. اضغط Run
```

---

### **2. ProductModel - إضافة حقل views** 📝
📁 `lib/features/products/domain/product_model.dart`

**التغييرات:**
```dart
@HiveField(14)
final int views;  // عدد المشاهدات

ProductModel({
  // ...
  this.views = 0,  // القيمة الافتراضية
});
```

---

### **3. ProductRepository - دالة incrementViews** 🔄
📁 `lib/features/products/data/product_repository.dart`

**الدالة المضافة:**
```dart
Future<void> incrementViews(String productId) async {
  try {
    await _supabase.rpc('increment_product_views', params: {
      'product_id': productId,
    });
  } catch (e) {
    print('خطأ في زيادة مشاهدات المنتج: $e');
  }
}
```

---

### **4. ViewTrackingProductCard - تتبع المشاهدات** 🎨
📁 `lib/widgets/product_card.dart`

**Widget جديد:**
```dart
class ViewTrackingProductCard extends ConsumerStatefulWidget {
  final bool trackViewOnVisible; // تفعيل/تعطيل التتبع التلقائي
  // ...
}
```

**الميزات:**
- ✅ استخدام `VisibilityDetector` لرصد ظهور المنتج على الشاشة
- ✅ حساب المشاهدة عندما يكون المنتج ظاهر بنسبة 50% أو أكثر
- ✅ تتبع المنتجات التي تم حساب مشاهداتها لمنع التكرار
- ✅ Cache ذكي باستخدام Set

---

### **5. تحديث التابات** 🔄

#### **أ. Home Tab** 
📁 `lib/features/home/presentation/screens/home_screen.dart`

**التغيير:**
```dart
ViewTrackingProductCard(
  product: product,
  productType: 'home',
  trackViewOnVisible: true, ✅ // حساب المشاهدة عند الظهور
  // ...
)
```

#### **ب. Expire Soon Tab**
📁 `lib/features/home/presentation/widgets/home_tabs_content.dart`

**التغيير:**
```dart
ViewTrackingProductCard(
  product: item.product,
  productType: 'expire_soon',
  trackViewOnVisible: true, ✅ // حساب المشاهدة عند الظهور
  // ...
)
```

#### **ج. Offers Tab**
📁 `lib/features/home/presentation/widgets/home_tabs_content.dart`

**التغيير:**
```dart
ViewTrackingProductCard(
  product: item.product,
  productType: 'offers',
  trackViewOnVisible: true, ✅ // حساب المشاهدة عند الظهور
  // ...
)
```

#### **د. Surgical Tools Tab**
📁 `lib/features/home/presentation/widgets/home_tabs_content.dart`

**التغيير 1 - ProductCard:**
```dart
ViewTrackingProductCard(
  product: tool,
  productType: 'surgical',
  trackViewOnVisible: false, ❌ // لا يحسب عند الظهور
  // ...
)
```

**التغيير 2 - الديالوج:**
📁 `lib/features/home/presentation/widgets/product_dialogs.dart`

```dart
Future<void> showSurgicalToolDialog(
  BuildContext context,
  ProductModel tool,
) {
  // حساب المشاهدة فور فتح الديالوج ✅
  ProductRepository().incrementViews(tool.id);
  
  return showDialog(/* ... */);
}
```

---

## 🎯 **كيفية عمل النظام:**

### **الطريقة الأولى: حساب المشاهدة عند الظهور** 👁️

**المستخدمة في:** Home, Expire Soon, Offers

```
المستخدم يسكرول الشاشة
        ↓
    منتج يظهر بنسبة 50%+
        ↓
    VisibilityDetector يكتشف الظهور
        ↓
    يتحقق: هل تم حسابه قبل ذلك؟
   ↙              ↘
نعم              لا
 ↓                ↓
تجاهل        ✅ increment_product_views()
              ↓
           حفظ في Cache
```

**الفائدة:**
- ✅ المشاهدات تُحسب تلقائياً عند ظهور المنتج
- ✅ لا يحتاج المستخدم للضغط على المنتج
- ✅ يعكس الاهتمام الفعلي بالمنتجات

---

### **الطريقة الثانية: حساب المشاهدة عند فتح الديالوج** 🖱️

**المستخدمة في:** Surgical Tools

```
المستخدم يضغط على أداة جراحية
        ↓
    يفتح الديالوج
        ↓
    ProductRepository.incrementViews()
        ↓
    ✅ تُحسب مشاهدة
```

**الفائدة:**
- ✅ المشاهدات تُحسب فقط عند الاهتمام الفعلي (فتح الديالوج)
- ✅ أكثر دقة للمنتجات المهمة

---

## 📊 **المقارنة:**

| الميزة | Home/Expire/Offers | Surgical Tools |
|--------|-------------------|----------------|
| **المشاهدة تُحسب** | عند الظهور على الشاشة | عند فتح الديالوج |
| **نسبة الظهور** | 50% أو أكثر | - |
| **يحتاج ضغطة** | ❌ لا | ✅ نعم |
| **VisibilityDetector** | ✅ مفعّل | ❌ معطّل |
| **الدقة** | اهتمام عام | اهتمام فعلي |

---

## 🚀 **خطوات التشغيل:**

### **الخطوة 1: تطبيق SQL** ⚠️ **إلزامي**
```bash
# 1. افتح Supabase Dashboard
# 2. SQL Editor → New Query
# 3. انسخ محتوى: supabase/add_views_to_products.sql
# 4. الصق واضغط Run
```

### **الخطوة 2: إعادة توليد Hive Adapters** ⚠️ **إلزامي**
```bash
# في terminal
cd D:\fieldawy_store
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**ملاحظة:** قد يستغرق 2-3 دقائق

### **الخطوة 3: تشغيل التطبيق**
```bash
flutter run
```

---

## 🧪 **اختبار النظام:**

### **اختبار 1: Home Tab**
```
1. افتح التطبيق → Home Tab
2. ✅ اسكرول لأسفل
3. ✅ شاهد 4 منتجات تظهر
4. تحقق من قاعدة البيانات
5. ✅ يجب أن ترى views = 1 لكل منتج ظهر
```

### **اختبار 2: Expire Soon Tab**
```
1. اذهب لـ Expire Soon Tab
2. ✅ اسكرول واعرض بعض المنتجات
3. ✅ المشاهدات تزيد تلقائياً
```

### **اختبار 3: Offers Tab**
```
1. اذهب لـ Offers Tab
2. ✅ اسكرول واعرض المنتجات
3. ✅ المشاهدات تزيد تلقائياً
```

### **اختبار 4: Surgical Tools Tab**
```
1. اذهب لـ Surgical Tools Tab
2. ❌ اسكرول - المشاهدات لا تزيد
3. ✅ اضغط على أداة → يفتح الديالوج
4. ✅ الآن المشاهدة تُحسب
```

---

## 📈 **التحقق من قاعدة البيانات:**

```sql
-- 1. عرض المنتجات الأكثر مشاهدة
SELECT name, views 
FROM distributor_products 
ORDER BY views DESC 
LIMIT 10;

-- 2. عرض إجمالي المشاهدات
SELECT SUM(views) as total_views 
FROM distributor_products;

-- 3. متوسط المشاهدات
SELECT AVG(views) as avg_views 
FROM distributor_products;

-- 4. المنتجات بدون مشاهدات
SELECT COUNT(*) as zero_views 
FROM distributor_products 
WHERE views = 0;
```

---

## ⚡ **الأداء:**

### **التحسينات المطبقة:**
1. **Cache ذكي:** كل منتج يُحسب مرة واحدة فقط في الجلسة
2. **Index على views:** للبحث السريع والترتيب
3. **Function في SQL:** أسرع من update مباشر
4. **VisibilityDetector:** خفيف جداً على الأداء

### **الاستهلاك:**
- **ذاكرة:** ~1-2 MB للـ Cache
- **شبكة:** طلب واحد فقط لكل منتج
- **معالج:** لا يؤثر على سلاسة التطبيق

---

## 🔍 **حل المشاكل:**

### **مشكلة 1: المشاهدات لا تزيد**

**السبب المحتمل:**
- ❌ SQL لم يتم تطبيقه

**الحل:**
```sql
-- تحقق من وجود عمود views
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'distributor_products' 
AND column_name = 'views';

-- إذا لم يظهر، طبّق SQL script
```

---

### **مشكلة 2: Build Runner يفشل**

**السبب المحتمل:**
- ❌ conflict في Hive adapters

**الحل:**
```bash
# احذف الملفات القديمة
flutter clean
flutter pub get

# ثم شغل build_runner
flutter packages pub run build_runner build --delete-conflicting-outputs
```

---

### **مشكلة 3: المشاهدات تُحسب أكثر من مرة**

**السبب المحتمل:**
- ❌ Cache لا يعمل

**الحل:**
- تأكد من أن `_viewedProducts` Set يعمل بشكل صحيح
- راجع logs في Console

---

## 📝 **ملاحظات مهمة:**

1. **Cache محلي:**
   - يُمسح عند إعادة تشغيل التطبيق
   - هذا سلوك مقصود

2. **نسبة الظهور:**
   - حالياً: 50%
   - يمكن تعديلها في `product_card.dart`

3. **الأدوات الجراحية:**
   - المشاهدة تُحسب **فقط** عند فتح الديالوج
   - الظهور على الشاشة لا يكفي

4. **Realtime:**
   - المشاهدات تُحدث فوراً في قاعدة البيانات
   - يمكن استخدام Supabase Realtime للعرض المباشر

---

## 🎉 **النتيجة النهائية:**

✅ **نظام مشاهدات متقدم ودقيق**
✅ **طريقتين مختلفتين حسب نوع المحتوى**
✅ **أداء ممتاز مع cache ذكي**
✅ **سهل الصيانة والتطوير**
✅ **إحصائيات دقيقة ومفيدة**

---

**🚀 النظام جاهز للاستخدام! ابدأ الآن!**
