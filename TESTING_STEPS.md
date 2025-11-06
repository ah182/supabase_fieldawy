# 🧪 خطوات الاختبار

## الخطوة 1: اختبار Supabase مباشرة

### **في Supabase SQL Editor:**
```sql
-- اختبار 1: حذف البيانات القديمة
DELETE FROM product_views WHERE product_id LIKE 'test-%';

-- اختبار 2: استدعاء Function
SELECT track_product_view('test-001', 'regular');

-- اختبار 3: التحقق
SELECT * FROM product_views WHERE product_id = 'test-001';
```

### **النتيجة المتوقعة:**
```json
[
  {
    "id": "uuid-here",
    "product_id": "test-001",
    "user_id": null,
    "user_role": "viewer",
    "product_type": "regular",
    "viewed_at": "2025-01-27T..."
  }
]
```

✅ **إذا ظهرت النتيجة:** Supabase يعمل بشكل صحيح
❌ **إذا لم تظهر:** المشكلة في Supabase - أعد تشغيل `CLEAN_INSTALL_product_views.sql`

---

## الخطوة 2: اختبار Flutter

### **2.1 إعادة تشغيل التطبيق:**
```bash
flutter run
```

### **2.2 فتح منتج:**
1. افتح التطبيق
2. اذهب إلى Home
3. اسكرول لأسفل
4. اضغط على **أي منتج** لفتح الديالوج

### **2.3 مراقبة Console:**
ابحث عن هذه الرسائل:

```
🔵 [_incrementProductViews] ========== START ==========
🔵 [_incrementProductViews] Product ID: xxx
🔵 [_incrementProductViews] Product Type: xxx
...
🟢 [_trackView] Starting to track view...
🟢 [_trackView] Product ID: xxx
🟢 [_trackView] Product Type: xxx
✅ [_trackView] View tracked successfully!
```

---

## الخطوة 3: التحقق من البيانات

### **في Supabase SQL Editor:**
```sql
-- عرض آخر 10 مشاهدات
SELECT 
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 10;
```

### **النتيجة المتوقعة:**
يجب أن ترى المنتجات التي فتحتها للتو

---

## 🔍 السيناريوهات المحتملة

### **السيناريو 1: لا توجد رسائل في Console**
**المشكلة:** `_incrementProductViews` لا يتم استدعاؤها

**الحل:**
1. تأكد من أنك تفتح منتج (تضغط عليه)
2. تأكد من أن الديالوج يفتح
3. تحقق من أن الكود في `product_card.dart` محدث

### **السيناريو 2: رسائل تظهر لكن خطأ**
**مثال:**
```
❌ [_trackView] Error tracking view!
❌ [_trackView] Error: ...
```

**الحل:**
- انسخ الخطأ بالكامل
- ابحث عن الحل حسب نوع الخطأ:

**خطأ: "function does not exist"**
```sql
-- أعد تشغيل
-- CLEAN_INSTALL_product_views.sql
```

**خطأ: "permission denied"**
```sql
-- تحقق من Policies
SELECT * FROM pg_policies WHERE tablename = 'product_views';
```

**خطأ: "column does not exist"**
```sql
-- أعد تشغيل
-- CLEAN_INSTALL_product_views.sql
```

### **السيناريو 3: رسائل نجاح لكن لا توجد بيانات**
**المشكلة:** RLS يمنع الإدراج

**الحل:**
```sql
-- تعطيل RLS مؤقتاً للاختبار
ALTER TABLE product_views DISABLE ROW LEVEL SECURITY;

-- اختبار
SELECT track_product_view('test-rls', 'regular');
SELECT * FROM product_views WHERE product_id = 'test-rls';

-- إذا نجح، المشكلة في RLS
-- أعد تفعيل RLS مع Policies صحيحة
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_views_insert_all ON product_views
FOR INSERT WITH CHECK (true);

CREATE POLICY product_views_select_all ON product_views
FOR SELECT USING (true);
```

---

## 📊 اختبار شامل

### **اختبار جميع الأنواع:**

```sql
-- في Supabase
SELECT track_product_view('test-regular', 'regular');
SELECT track_product_view('test-ocr', 'ocr');
SELECT track_product_view('test-surgical', 'surgical');
SELECT track_product_view('test-offer', 'offer');
SELECT track_product_view('test-course', 'course');
SELECT track_product_view('test-book', 'book');

-- التحقق
SELECT product_id, product_type FROM product_views
WHERE product_id LIKE 'test-%'
ORDER BY viewed_at DESC;
```

**النتيجة المتوقعة:** 6 صفوف

---

## ✅ قائمة التحقق

- [ ] اختبار Supabase نجح (الخطوة 1)
- [ ] رسائل Console تظهر (الخطوة 2)
- [ ] رسائل النجاح تظهر
- [ ] البيانات تظهر في Supabase (الخطوة 3)
- [ ] جميع الأنواع تعمل

---

## 🎯 الخطوة التالية

1. **شغل الخطوة 1** في Supabase
2. **إذا نجحت:** انتقل للخطوة 2
3. **إذا فشلت:** أعد تشغيل `CLEAN_INSTALL_product_views.sql`
4. **شغل الخطوة 2** في Flutter
5. **راقب Console** بعناية
6. **انسخ أي أخطاء** وأرسلها

---

## 📞 الدعم

إذا استمرت المشكلة، أرسل:
1. ✅ نتيجة الخطوة 1 (من Supabase)
2. 📱 Logs من Console (الخطوة 2)
3. ❌ أي رسائل خطأ

