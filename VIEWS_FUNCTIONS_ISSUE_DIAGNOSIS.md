# 🔍 تشخيص مشكلة عدادات المشاهدات

## 📋 **تشخيص المشكلة:**

### ✅ **ما يعمل:**
- Repository يستدعي الدوال الصحيحة:
  - `increment_job_views` للوظائف
  - `increment_vet_supply_views` للمستلزمات
- العداد يحدث في الواجهة (Provider يحدث الـ state)
- VisibilityDetector يعمل بشكل صحيح

### ❌ **ما لا يعمل:**
- العداد لا يحفظ في قاعدة البيانات
- المشكلة: SQL Functions غير موجودة أو لا تعمل

---

## 🛠️ **الحل المطلوب:**

### **1️⃣ تطبيق SQL Functions في Supabase:**

```sql
-- في Supabase SQL Editor، تشغيل:
supabase/fix_views_functions.sql
```

### **2️⃣ ما سيفعله الـ Script:**

#### **أ) إنشاء/إصلاح دالة الوظائف:**
```sql
CREATE OR REPLACE FUNCTION increment_job_views(p_job_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE job_offers 
  SET views_count = COALESCE(views_count, 0) + 1,
      updated_at = NOW()
  WHERE id = p_job_id;
END;
$$ LANGUAGE plpgsql;
```

#### **ب) إنشاء/إصلاح دالة المستلزمات:**
```sql
CREATE OR REPLACE FUNCTION increment_vet_supply_views(p_supply_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE vet_supplies 
  SET views_count = COALESCE(views_count, 0) + 1,
      updated_at = NOW()
  WHERE id = p_supply_id;
END;
$$ LANGUAGE plpgsql;
```

#### **ج) التحقق من وجود أعمدة `views_count`:**
- في جدول `job_offers`
- في جدول `vet_supplies`
- إضافتها إذا لم تكن موجودة

#### **د) اختبار الدوال:**
- اختبار تلقائي للتأكد من عملها
- رسائل تأكيد النجاح

---

## 🧪 **للاختبار بعد التطبيق:**

### **1️⃣ اختبار يدوي في Supabase:**
```sql
-- اختبار دالة الوظائف
SELECT increment_job_views('job-id-here');

-- اختبار دالة المستلزمات
SELECT increment_vet_supply_views('supply-id-here');

-- التحقق من النتائج
SELECT id, title, views_count FROM job_offers ORDER BY updated_at DESC LIMIT 5;
SELECT id, name, views_count FROM vet_supplies ORDER BY updated_at DESC LIMIT 5;
```

### **2️⃣ اختبار من التطبيق:**
1. افتح صفحة الوظائف
2. مرر بين الوظائف
3. تحقق من قاعدة البيانات → يجب أن ترى `views_count` يزيد
4. نفس الشيء للمستلزمات

---

## 📊 **التدفق الصحيح بعد الإصلاح:**

```
👀 المستخدم يرى الكارت
    ↓
📱 VisibilityDetector يكتشف
    ↓
⚡ Provider.incrementViews(id)
    ↓
📡 Repository.incrementJobViews(id)
    ↓
🗄️ Supabase RPC: increment_job_views(p_job_id)
    ↓
🔧 SQL Function ينفذ UPDATE
    ↓
✅ views_count يزيد في قاعدة البيانات
    ↓
📱 Provider يحدث الواجهة المحلية
    ↓
👁️ العداد يظهر الرقم الصحيح
```

---

## 🎯 **خطوات التطبيق:**

### **1. تطبيق SQL Script:**
- اذهب إلى Supabase Dashboard
- افتح SQL Editor
- انسخ محتوى `supabase/fix_views_functions.sql`
- اضغط Run

### **2. التحقق من النجاح:**
- يجب أن ترى رسائل نجاح في النتائج
- اختبر الدوال يدوياً
- اختبر من التطبيق

### **3. النتيجة المتوقعة:**
- ✅ العداد يظهر في الواجهة
- ✅ العداد يحفظ في قاعدة البيانات
- ✅ النظام يعمل بشكل كامل

---

هل تريد تطبيق SQL Script الآن؟