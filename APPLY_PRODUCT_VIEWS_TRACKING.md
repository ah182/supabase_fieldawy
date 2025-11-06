# 🚀 دليل تطبيق نظام تتبع المشاهدات

## ⚠️ مهم جداً: ترتيب التنفيذ

يجب تنفيذ الملفات بالترتيب التالي:

---

## 📝 الخطوة 1: إضافة عمود views

### **الملف:** `add_views_column_to_all_tables.sql`

**الغرض:**
- إضافة عمود `views` لجميع الجداول
- إنشاء Indexes للأداء
- تحديث القيم الحالية إلى 0

### **كيفية التطبيق:**

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. افتح ملف `supabase/migrations/add_views_column_to_all_tables.sql`
4. انسخ **كل** المحتوى
5. الصقه في SQL Editor
6. اضغط **Run** أو **F5**

### **النتيجة المتوقعة:**
```
✅ Success. No rows returned
```

### **التحقق:**
```sql
-- التحقق من وجود عمود views
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name IN (
  'distributor_products',
  'distributor_ocr_products',
  'distributor_surgical_tools',
  'offers'
)
AND column_name = 'views';
```

**النتيجة المتوقعة:** 4 صفوف على الأقل

---

## 📝 الخطوة 2: إنشاء نظام التتبع

### **الملف:** `create_product_views_tracking.sql`

**الغرض:**
- إنشاء جدول `product_views`
- إنشاء Functions للتتبع
- إعداد RLS Policies

### **كيفية التطبيق:**

1. في نفس **SQL Editor**
2. افتح ملف `supabase/migrations/create_product_views_tracking.sql`
3. انسخ **كل** المحتوى
4. الصقه في SQL Editor
5. اضغط **Run** أو **F5**

### **النتيجة المتوقعة:**
```
✅ Success. No rows returned
```

### **التحقق:**
```sql
-- التحقق من وجود الجدول
SELECT * FROM product_views LIMIT 1;

-- التحقق من Functions
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%track%view%'
ORDER BY routine_name;
```

**النتيجة المتوقعة:** 7 functions

---

## 🧪 الخطوة 3: اختبار النظام

### **اختبار 1: منتج عادي**
```sql
SELECT track_product_view('test-123', 'regular');
```

### **اختبار 2: منتج OCR**
```sql
SELECT track_product_view('test-ocr-456', 'ocr');
```

### **اختبار 3: أداة جراحية**
```sql
SELECT track_product_view('test-surgical-789', 'surgical');
```

### **اختبار 4: عرض**
```sql
SELECT track_product_view('test-offer-111', 'offer');
```

### **اختبار 5: كورس**
```sql
SELECT track_product_view('test-course-222', 'course');
```

### **اختبار 6: كتاب**
```sql
SELECT track_product_view('test-book-333', 'book');
```

### **التحقق من النتائج:**
```sql
SELECT 
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 10;
```

**النتيجة المتوقعة:** 6 صفوف على الأقل

---

## 📱 الخطوة 4: تحديث Flutter

### **الملفات المحدثة:**
- ✅ `lib/widgets/product_card.dart`
- ✅ `lib/features/home/presentation/widgets/product_dialogs.dart`

### **لا حاجة لتعديلات إضافية!**
الملفات تم تحديثها بالفعل لاستخدام النظام الجديد.

### **إعادة تشغيل التطبيق:**
```bash
flutter run
```

---

## ✅ الخطوة 5: التحقق النهائي

### **1. افتح التطبيق**
- اذهب إلى Home
- اسكرول لمشاهدة بعض المنتجات
- افتح ديالوج منتج

### **2. تحقق من Logs**
ابحث عن:
```
✅ View tracked successfully for regular: 123
```

### **3. تحقق من قاعدة البيانات**
```sql
SELECT * FROM product_views 
WHERE viewed_at >= NOW() - INTERVAL '5 minutes'
ORDER BY viewed_at DESC;
```

### **4. تحقق من الداش بورد**
- افتح Dashboard في التطبيق
- اذهب إلى "إحصائياتي الخاصة"
- ابحث عن "التوزيع الجغرافي للمشاهدات"

---

## 🎯 الأنواع المدعومة

| النوع | الوصف | الجدول |
|------|-------|--------|
| `regular` | منتجات عادية | `distributor_products` |
| `ocr` | منتجات OCR | `distributor_ocr_products` |
| `surgical` | أدوات جراحية | `distributor_surgical_tools` |
| `offer` | عروض | `offers` |
| `course` | كورسات | `courses` |
| `book` | كتب | `books` |

---

## 🔍 استعلامات مفيدة

### **المشاهدات حسب النوع**
```sql
SELECT product_type, COUNT(*) as views
FROM product_views
GROUP BY product_type
ORDER BY views DESC;
```

### **أكثر المنتجات مشاهدة**
```sql
SELECT 
  product_id,
  product_type,
  COUNT(*) as views
FROM product_views
GROUP BY product_id, product_type
ORDER BY views DESC
LIMIT 10;
```

### **التوزيع الجغرافي**
```sql
SELECT 
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as views
FROM product_views pv
JOIN users u ON pv.user_id = u.uid
WHERE u.governorates IS NOT NULL
GROUP BY governorate
ORDER BY views DESC;
```

---

## ⚠️ استكشاف الأخطاء

### **خطأ: "column views does not exist"**
**الحل:** تأكد من تشغيل `add_views_column_to_all_tables.sql` أولاً

### **خطأ: "function track_product_view does not exist"**
**الحل:** تأكد من تشغيل `create_product_views_tracking.sql`

### **خطأ: "table product_views does not exist"**
**الحل:** تأكد من تشغيل `create_product_views_tracking.sql`

---

## ✅ قائمة التحقق

- [ ] تم تشغيل `add_views_column_to_all_tables.sql`
- [ ] تم التحقق من وجود عمود `views`
- [ ] تم تشغيل `create_product_views_tracking.sql`
- [ ] تم التحقق من وجود جدول `product_views`
- [ ] تم التحقق من وجود 7 functions
- [ ] تم اختبار جميع الأنواع (6 اختبارات)
- [ ] البيانات تظهر في `product_views`
- [ ] تم إعادة تشغيل Flutter
- [ ] التطبيق يسجل المشاهدات
- [ ] الداش بورد يعرض البيانات

---

## 🎉 النجاح!

إذا نجحت جميع الخطوات، فالنظام جاهز ويعمل بكفاءة! 🚀

الآن جدول `product_views` سيمتلئ تلقائياً بالبيانات الفعلية.

