# 🔍 دليل تشخيص مشكلة عدم إضافة بيانات في product_views

## 🎯 المشكلة
جدول `product_views` فارغ - لا يتم إضافة أي بيانات

---

## 📋 خطوات التشخيص

### **الخطوة 1: التحقق من Supabase** 🔧

#### **1.1 تشغيل ملف التشخيص**
```sql
-- افتح Supabase Dashboard → SQL Editor
-- انسخ محتوى: DEBUG_PRODUCT_VIEWS.sql
-- الصق واضغط Run
-- راقب النتائج
```

#### **1.2 النتائج المتوقعة:**
- ✅ الجدول موجود
- ✅ 6 أعمدة (id, product_id, user_id, user_role, product_type, viewed_at)
- ✅ 2 Policies (insert, select)
- ✅ Function موجودة
- ✅ الإدراج المباشر يعمل
- ✅ Function تعمل

#### **1.3 إذا فشل أي اختبار:**
- ❌ الجدول غير موجود → أعد تشغيل `CLEAN_INSTALL_product_views.sql`
- ❌ Policies غير موجودة → أعد تشغيل `CLEAN_INSTALL_product_views.sql`
- ❌ Function غير موجودة → أعد تشغيل `CLEAN_INSTALL_product_views.sql`

---

### **الخطوة 2: التحقق من Flutter** 📱

#### **2.1 إضافة ملف الاختبار**
1. انسخ ملف `test_product_views.dart` إلى `lib/`
2. في `main.dart`، أضف:
```dart
import 'test_product_views.dart';

// في initState أو بعد تهيئة Supabase
await testProductViews();
```

#### **2.2 تشغيل التطبيق**
```bash
flutter run
```

#### **2.3 مراقبة Console**
ابحث عن:
```
✅ الجدول موجود
✅ الإدراج المباشر نجح
✅ استدعاء Function نجح
✅ عدد الصفوف المسترجعة: 2
```

#### **2.4 إذا ظهرت أخطاء:**

**خطأ: "table product_views does not exist"**
```
الحل: أعد تشغيل CLEAN_INSTALL_product_views.sql
```

**خطأ: "function track_product_view does not exist"**
```
الحل: أعد تشغيل CLEAN_INSTALL_product_views.sql
```

**خطأ: "permission denied"**
```
الحل: تحقق من RLS Policies
```

**خطأ: "new row violates row-level security policy"**
```
الحل: Policy للإدراج غير موجودة
تشغيل:
CREATE POLICY product_views_insert_all ON product_views
FOR INSERT WITH CHECK (true);
```

---

### **الخطوة 3: التحقق من Logs** 📊

#### **3.1 في Flutter Console**
ابحث عن:
```
🔵 Tracking view for product: xxx, type: xxx
✅ View tracked successfully for xxx: xxx
```

#### **3.2 إذا لم تظهر هذه الرسائل:**
- المشكلة: `_incrementProductViews` لا يتم استدعاؤها
- الحل: تحقق من أن المستخدم يفتح المنتجات فعلاً

#### **3.3 إذا ظهرت رسائل خطأ:**
```
❌ Error tracking view: xxx
```
- انسخ الخطأ بالكامل
- ابحث عن الحل في هذا الدليل

---

### **الخطوة 4: اختبار يدوي** 🧪

#### **4.1 في Supabase SQL Editor:**
```sql
-- اختبار 1: إدراج مباشر
INSERT INTO product_views (product_id, product_type)
VALUES ('manual-test-001', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'manual-test-001';
```

**النتيجة المتوقعة:** صف واحد

#### **4.2 اختبار Function:**
```sql
-- اختبار 2: استدعاء Function
SELECT track_product_view('manual-test-002', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'manual-test-002';
```

**النتيجة المتوقعة:** صف واحد

#### **4.3 إذا فشل الاختبار اليدوي:**
- المشكلة في Supabase نفسه
- الحل: أعد تشغيل `CLEAN_INSTALL_product_views.sql`

---

### **الخطوة 5: التحقق من RLS** 🔒

```sql
-- عرض Policies
SELECT * FROM pg_policies WHERE tablename = 'product_views';
```

**يجب أن ترى:**
- `product_views_insert_all` - FOR INSERT - WITH CHECK (true)
- `product_views_select_all` - FOR SELECT - USING (true)

**إذا لم تكن موجودة:**
```sql
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_views_insert_all ON product_views
FOR INSERT WITH CHECK (true);

CREATE POLICY product_views_select_all ON product_views
FOR SELECT USING (true);
```

---

## 🔍 أسباب شائعة للمشكلة

### **1. RLS مفعل بدون Policies**
```sql
-- الحل
ALTER TABLE product_views DISABLE ROW LEVEL SECURITY;
-- أو
CREATE POLICY product_views_insert_all ON product_views
FOR INSERT WITH CHECK (true);
```

### **2. Function غير موجودة**
```sql
-- التحقق
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'track_product_view';

-- إذا لم تكن موجودة، أعد تشغيل CLEAN_INSTALL_product_views.sql
```

### **3. Flutter لا يستدعي Function**
- تحقق من Logs
- تأكد من أن المستخدم يفتح المنتجات
- استخدم `test_product_views.dart` للاختبار

### **4. الجدول القديم بدون product_type**
```sql
-- الحل: حذف وإعادة إنشاء
DROP TABLE IF EXISTS product_views CASCADE;
-- ثم تشغيل CLEAN_INSTALL_product_views.sql
```

---

## ✅ قائمة التحقق النهائية

- [ ] الجدول `product_views` موجود
- [ ] الجدول يحتوي على 6 أعمدة
- [ ] عمود `product_type` موجود
- [ ] RLS مفعل
- [ ] 2 Policies موجودة
- [ ] Function `track_product_view` موجودة
- [ ] الإدراج اليدوي يعمل
- [ ] Function تعمل يدوياً
- [ ] Flutter يستدعي Function
- [ ] Logs تظهر رسائل النجاح
- [ ] البيانات تظهر في الجدول

---

## 🆘 إذا فشل كل شيء

### **الحل الجذري:**
```sql
-- 1. حذف كل شيء
DROP TABLE IF EXISTS product_views CASCADE;
DROP FUNCTION IF EXISTS track_product_view CASCADE;

-- 2. تشغيل CLEAN_INSTALL_product_views.sql

-- 3. اختبار يدوي
SELECT track_product_view('final-test', 'regular');
SELECT * FROM product_views;

-- 4. إذا نجح، المشكلة في Flutter
-- 5. إذا فشل، المشكلة في Supabase
```

---

## 📞 الدعم

إذا استمرت المشكلة:
1. شغل `DEBUG_PRODUCT_VIEWS.sql` وانسخ النتائج
2. شغل `test_product_views.dart` وانسخ Logs
3. أرسل النتائج للمراجعة

