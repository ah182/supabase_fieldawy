# 🧪 اختبار نظام تتبع المشاهدات

## ✅ خطوات التطبيق والاختبار

### **الخطوة 1: تطبيق SQL Migration** 📝

1. افتح Supabase Dashboard
2. اذهب إلى **SQL Editor**
3. افتح ملف `supabase/migrations/create_product_views_tracking.sql`
4. انسخ **كل** المحتوى
5. الصقه في SQL Editor
6. اضغط **Run** أو **F5**

**النتيجة المتوقعة:**
```
✅ Success. No rows returned
```

---

### **الخطوة 2: التحقق من الجدول** 🔍

```sql
-- التحقق من وجود الجدول
SELECT * FROM product_views LIMIT 1;
```

**النتيجة المتوقعة:**
- إذا كان الجدول فارغاً: `0 rows`
- إذا كان هناك بيانات قديمة: سيعرض صف واحد

---

### **الخطوة 3: التحقق من Functions** ⚙️

```sql
-- عرض جميع Functions المتعلقة بالمشاهدات
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%track%view%'
ORDER BY routine_name;
```

**النتيجة المتوقعة:**
```
track_offer_view          | FUNCTION
track_ocr_product_view    | FUNCTION
track_product_view        | FUNCTION
track_regular_product_view| FUNCTION
track_surgical_tool_view  | FUNCTION
```

---

### **الخطوة 4: اختبار يدوي** 🧪

#### **اختبار 1: منتج عادي**
```sql
SELECT track_product_view('123', 'regular');
```

#### **اختبار 2: منتج OCR**
```sql
SELECT track_product_view('abc-def-ghi', 'ocr');
```

#### **اختبار 3: أداة جراحية**
```sql
SELECT track_product_view('456', 'surgical');
```

#### **اختبار 4: عرض**
```sql
SELECT track_product_view('789', 'offer');
```

**التحقق من النتائج:**
```sql
SELECT * FROM product_views ORDER BY viewed_at DESC LIMIT 10;
```

**النتيجة المتوقعة:**
```
id                  | product_id | user_id | user_role | product_type | viewed_at
--------------------|------------|---------|-----------|--------------|-------------------
uuid-1              | 123        | NULL    | viewer    | regular      | 2025-01-27 10:30:00
uuid-2              | abc-def... | NULL    | viewer    | ocr          | 2025-01-27 10:30:05
uuid-3              | 456        | NULL    | viewer    | surgical     | 2025-01-27 10:30:10
uuid-4              | 789        | NULL    | viewer    | offer        | 2025-01-27 10:30:15
```

---

### **الخطوة 5: اختبار من Flutter** 📱

#### **1. أعد تشغيل التطبيق**
```bash
flutter run
```

#### **2. افتح صفحة المنتجات**
- اذهب إلى Home
- اسكرول لأسفل لمشاهدة بعض المنتجات

#### **3. افتح ديالوج منتج**
- اضغط على أي منتج

#### **4. تحقق من Logs**
ابحث عن:
```
✅ View tracked successfully for regular: 123
```

#### **5. تحقق من قاعدة البيانات**
```sql
SELECT * FROM product_views 
WHERE viewed_at >= NOW() - INTERVAL '5 minutes'
ORDER BY viewed_at DESC;
```

---

### **الخطوة 6: اختبار التوزيع الجغرافي** 📍

#### **1. أضف بيانات تجريبية**
```sql
-- إضافة مستخدم تجريبي
INSERT INTO users (uid, display_name, role, governorates)
VALUES (
  gen_random_uuid(),
  'Test User',
  'doctor',
  '["القاهرة", "الجيزة"]'::jsonb
);

-- الحصول على UID المستخدم
SELECT uid FROM users WHERE display_name = 'Test User';

-- إضافة مشاهدات للمستخدم (استبدل USER_UID بالـ UID الفعلي)
INSERT INTO product_views (product_id, user_id, user_role, product_type)
VALUES 
  ('123', 'USER_UID', 'doctor', 'regular'),
  ('456', 'USER_UID', 'doctor', 'regular'),
  ('789', 'USER_UID', 'doctor', 'regular');
```

#### **2. اختبار استعلام التوزيع الجغرافي**
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

**النتيجة المتوقعة:**
```
governorate | views
------------|------
القاهرة     | 3
الجيزة      | 3
```

---

### **الخطوة 7: اختبار الداش بورد** 📊

#### **1. افتح الداش بورد في التطبيق**
- اذهب إلى Dashboard
- اذهب إلى تاب "إحصائياتي الخاصة"
- ابحث عن "التوزيع الجغرافي للمشاهدات"

#### **2. النتيجة المتوقعة:**
- إذا كانت هناك مشاهدات: عرض المحافظات مع عدد المشاهدات
- إذا لم تكن هناك مشاهدات: "لا توجد بيانات جغرافية"

---

## 🔍 استعلامات التحقق

### **1. عدد المشاهدات الكلي**
```sql
SELECT COUNT(*) as total_views FROM product_views;
```

### **2. المشاهدات حسب النوع**
```sql
SELECT product_type, COUNT(*) as views
FROM product_views
GROUP BY product_type;
```

### **3. المشاهدات حسب الدور**
```sql
SELECT 
  COALESCE(user_role, 'guest') as role,
  COUNT(*) as views
FROM product_views
GROUP BY user_role;
```

### **4. آخر 20 مشاهدة**
```sql
SELECT 
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 20;
```

### **5. المنتجات الأكثر مشاهدة**
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

---

## ⚠️ استكشاف الأخطاء

### **المشكلة 1: "function track_product_view does not exist"**
**الحل:**
- تأكد من تشغيل SQL Migration بالكامل
- تحقق من وجود Function:
```sql
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'track_product_view';
```

### **المشكلة 2: "permission denied for table product_views"**
**الحل:**
- تحقق من RLS Policies:
```sql
SELECT * FROM pg_policies WHERE tablename = 'product_views';
```

### **المشكلة 3: لا توجد بيانات في product_views**
**الحل:**
1. تحقق من Logs في Flutter
2. تأكد من استدعاء `track_product_view`
3. جرب الاختبار اليدوي من SQL Editor

---

## ✅ قائمة التحقق النهائية

- [ ] تم تشغيل SQL Migration بنجاح
- [ ] جدول `product_views` موجود
- [ ] Functions موجودة (5 functions)
- [ ] RLS Policies موجودة
- [ ] الاختبار اليدوي نجح
- [ ] Flutter يسجل المشاهدات
- [ ] البيانات تظهر في `product_views`
- [ ] التوزيع الجغرافي يعمل
- [ ] الداش بورد يعرض البيانات

---

## 🎉 النجاح!

إذا نجحت جميع الاختبارات، فالنظام جاهز ويعمل بكفاءة! 🚀

