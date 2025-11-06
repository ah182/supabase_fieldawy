# 🚀 دليل التثبيت النهائي - نظام تتبع المشاهدات

## ⚠️ مهم جداً: اتبع الخطوات بالترتيب

---

## 📝 الخطوة 1: إضافة عمود views (إلزامي)

### **الملف:** `add_views_column_to_all_tables.sql`

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. افتح ملف `supabase/migrations/add_views_column_to_all_tables.sql`
4. انسخ **كل** المحتوى
5. الصق في SQL Editor
6. اضغط **Run**

### **النتيجة المتوقعة:**
```
✅ Success. No rows returned
```

### **التحقق:**
```sql
SELECT table_name, column_name
FROM information_schema.columns
WHERE column_name = 'views'
AND table_name IN (
  'distributor_products',
  'distributor_ocr_products',
  'distributor_surgical_tools',
  'offers'
);
```
**يجب أن ترى 4 صفوف على الأقل**

---

## 📝 الخطوة 2: إنشاء نظام التتبع

### **الملف:** `FINAL_product_views_system.sql`

1. في نفس **SQL Editor**
2. افتح ملف `supabase/migrations/FINAL_product_views_system.sql`
3. انسخ **كل** المحتوى
4. الصق في SQL Editor
5. اضغط **Run**

### **النتيجة المتوقعة:**
```
✅ Success. No rows returned
```

### **التحقق:**
```sql
-- التحقق من الجدول
SELECT COUNT(*) FROM product_views;

-- التحقق من Functions
SELECT routine_name
FROM information_schema.routines
WHERE routine_name LIKE '%track%view%'
ORDER BY routine_name;
```
**يجب أن ترى 7 functions**

---

## 🧪 الخطوة 3: اختبار النظام

### **اختبار سريع:**
```sql
-- اختبار 1
SELECT track_product_view('test-001', 'regular');

-- اختبار 2
SELECT track_product_view('test-002', 'course');

-- اختبار 3
SELECT track_product_view('test-003', 'book');

-- التحقق
SELECT * FROM product_views ORDER BY viewed_at DESC LIMIT 10;
```

**يجب أن ترى 3 صفوف على الأقل**

---

## 📱 الخطوة 4: إعادة تشغيل Flutter

```bash
flutter run
```

---

## ✅ التحقق النهائي

### **1. في Supabase:**
```sql
-- عدد المشاهدات
SELECT COUNT(*) FROM product_views;

-- المشاهدات حسب النوع
SELECT product_type, COUNT(*) 
FROM product_views 
GROUP BY product_type;
```

### **2. في التطبيق:**
- افتح التطبيق
- اذهب إلى Home
- اسكرول لمشاهدة منتجات
- افتح ديالوج منتج
- تحقق من Logs:
```
✅ View tracked successfully for regular: 123
```

### **3. في الداش بورد:**
- افتح Dashboard
- اذهب إلى "إحصائياتي الخاصة"
- ابحث عن "التوزيع الجغرافي للمشاهدات"
- يجب أن ترى بيانات فعلية

---

## 🎯 الأنواع المدعومة

| النوع | Function |
|------|----------|
| `regular` | `track_regular_product_view()` |
| `ocr` | `track_ocr_product_view()` |
| `surgical` | `track_surgical_tool_view()` |
| `offer` | `track_offer_view()` |
| `course` | `track_course_view()` ⭐ |
| `book` | `track_book_view()` ⭐ |

---

## ⚠️ استكشاف الأخطاء

### **خطأ: "column views does not exist"**
**الحل:** تأكد من تشغيل الخطوة 1 أولاً

### **خطأ: "function track_product_view does not exist"**
**الحل:** تأكد من تشغيل الخطوة 2

### **خطأ: "table product_views does not exist"**
**الحل:** تأكد من تشغيل الخطوة 2

### **لا توجد بيانات في product_views**
**الحل:**
1. تحقق من Logs في Flutter
2. جرب الاختبار اليدوي من SQL Editor
3. تأكد من أن التطبيق يستدعي `track_product_view`

---

## 📊 استعلامات مفيدة

### **إجمالي المشاهدات:**
```sql
SELECT COUNT(*) FROM product_views;
```

### **المشاهدات حسب النوع:**
```sql
SELECT product_type, COUNT(*) as views
FROM product_views
GROUP BY product_type
ORDER BY views DESC;
```

### **أكثر المنتجات مشاهدة:**
```sql
SELECT product_id, COUNT(*) as views
FROM product_views
GROUP BY product_id
ORDER BY views DESC
LIMIT 10;
```

### **التوزيع الجغرافي:**
```sql
SELECT 
  jsonb_array_elements_text(u.governorates) as gov,
  COUNT(*) as views
FROM product_views pv
JOIN users u ON pv.user_id = u.uid
WHERE u.governorates IS NOT NULL
GROUP BY gov
ORDER BY views DESC;
```

---

## ✅ قائمة التحقق

- [ ] تم تشغيل `add_views_column_to_all_tables.sql`
- [ ] عمود `views` موجود في الجداول
- [ ] تم تشغيل `FINAL_product_views_system.sql`
- [ ] جدول `product_views` موجود
- [ ] 7 Functions موجودة
- [ ] الاختبار اليدوي نجح
- [ ] تم إعادة تشغيل Flutter
- [ ] التطبيق يسجل المشاهدات
- [ ] البيانات تظهر في `product_views`
- [ ] الداش بورد يعرض البيانات

---

## 🎉 النجاح!

إذا نجحت جميع الخطوات، فالنظام جاهز ويعمل بكفاءة! 🚀

**الآن جدول `product_views` سيمتلئ تلقائياً بالبيانات الفعلية.**

---

## 📞 الدعم

إذا واجهت أي مشكلة:
1. تحقق من قائمة التحقق أعلاه
2. راجع قسم استكشاف الأخطاء
3. تأكد من تشغيل الملفات بالترتيب الصحيح

