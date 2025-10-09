# 🔧 إصلاح خطأ Distributor Surgical Tools Trigger

## ❌ الخطأ

```
Error adding tool to inventory: PostgrestException(message: record "new" has no field "tool_name", code: 42703)
```

عند إضافة أداة جراحية في `distributor_surgical_tools`.

---

## 💡 السبب

### بنية الجداول:

#### 1️⃣ جدول `surgical_tools` (الكتالوج العام):
```sql
CREATE TABLE surgical_tools (
  id uuid PRIMARY KEY,
  tool_name text NOT NULL,        -- ✅ اسم الأداة موجود هنا
  company text,
  image_url text,
  created_by uuid,
  created_at timestamptz,
  updated_at timestamptz
);
```

#### 2️⃣ جدول `distributor_surgical_tools` (أدوات الموزعين):
```sql
CREATE TABLE distributor_surgical_tools (
  id uuid PRIMARY KEY,
  distributor_id uuid NOT NULL,
  distributor_name text NOT NULL,
  surgical_tool_id uuid NOT NULL,  -- ✅ فقط ID (يربط مع surgical_tools)
  description text NOT NULL,       -- وصف من الموزع
  price numeric(12,2) NOT NULL,    -- سعر الموزع
  created_at timestamptz,
  updated_at timestamptz
);
```

**المشكلة:** 
- `surgical_tools` لديه `tool_name` ✅
- `distributor_surgical_tools` **ليس** لديه `tool_name` ❌ (فقط `surgical_tool_id`)

---

## ✅ الحل

### قبل ❌:
```sql
ELSIF TG_TABLE_NAME = 'surgical_tools' OR TG_TABLE_NAME = 'distributor_surgical_tools' THEN
  product_name := COALESCE(NEW.tool_name, 'أداة جراحية');
  -- ❌ distributor_surgical_tools ليس لديه tool_name!
```

### بعد ✅:
```sql
ELSIF TG_TABLE_NAME = 'surgical_tools' THEN
  -- جدول surgical_tools لديه tool_name
  product_name := COALESCE(NEW.tool_name, 'أداة جراحية');
  
ELSIF TG_TABLE_NAME = 'distributor_surgical_tools' THEN
  -- جدول distributor_surgical_tools يحتاج JOIN
  product_name := 'أداة جراحية'; -- placeholder
```

---

## 🧪 اختبار

### Test 1: إضافة أداة في الكتالوج العام (surgical_tools)

```sql
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Surgical Forceps', 'Medline');
```

**النتيجة المتوقعة:**
- ✅ لا يوجد خطأ
- ✅ إشعار: "تم إضافة Surgical Forceps في الأدوات الجراحية والتشخيصية"

---

### Test 2: إضافة أداة في مخزون الموزع (distributor_surgical_tools)

```sql
INSERT INTO distributor_surgical_tools (
  distributor_id,
  distributor_name,
  surgical_tool_id,
  description,
  price
) VALUES (
  auth.uid(),
  'Test Distributor',
  (SELECT id FROM surgical_tools LIMIT 1),
  'Surgical Forceps - High Quality',
  150.00
);
```

**النتيجة المتوقعة:**
- ✅ لا يوجد خطأ
- ✅ إشعار: "تم إضافة أداة جراحية في الأدوات الجراحية والتشخيصية"

---

## 🔄 التطبيق

### الخطوة 1: حذف Triggers القديمة

```sql
DROP TRIGGER IF EXISTS trigger_notify_surgical_tools ON surgical_tools;
DROP TRIGGER IF EXISTS trigger_notify_distributor_surgical_tools ON distributor_surgical_tools;
DROP FUNCTION IF EXISTS notify_product_change();
```

---

### الخطوة 2: تطبيق Migration المُصحّح

```sql
-- في Supabase SQL Editor
-- انسخ والصق محتوى:
supabase/migrations/20250120_add_product_notification_triggers.sql

-- اضغط Run ✅
```

---

## 📊 ملخص الأعمدة لجميع الجداول

| الجدول | عمود الاسم | ملاحظات |
|--------|------------|---------|
| `products` | `name` ✅ | اسم المنتج |
| `distributor_products` | ❌ | يحتاج JOIN مع products |
| `ocr_products` | `product_name` ✅ | من OCR |
| `distributor_ocr_products` | ❌ | يحتاج JOIN مع ocr_products |
| `surgical_tools` | `tool_name` ✅ | اسم الأداة |
| `distributor_surgical_tools` | ❌ | يحتاج JOIN مع surgical_tools |
| `offers` | `description` ✅ | وصف العرض |

---

## ✅ الإصلاحات الكاملة

```sql
-- تحديد اسم المنتج بناءً على نوع الجدول
IF TG_TABLE_NAME = 'products' THEN
  product_name := COALESCE(NEW.name, 'منتج');
  
ELSIF TG_TABLE_NAME = 'distributor_products' THEN
  product_name := 'منتج';
  
ELSIF TG_TABLE_NAME = 'ocr_products' THEN
  product_name := COALESCE(NEW.product_name, 'منتج OCR');
  
ELSIF TG_TABLE_NAME = 'distributor_ocr_products' THEN
  product_name := 'منتج OCR';
  
ELSIF TG_TABLE_NAME = 'surgical_tools' THEN
  product_name := COALESCE(NEW.tool_name, 'أداة جراحية'); -- ✅
  
ELSIF TG_TABLE_NAME = 'distributor_surgical_tools' THEN
  product_name := 'أداة جراحية'; -- ✅ placeholder
  
ELSIF TG_TABLE_NAME = 'offers' THEN
  product_name := COALESCE(NEW.description, 'عرض');
  
ELSE
  product_name := 'منتج';
END IF;
```

---

## 🎯 الخلاصة

تم فصل معالجة `surgical_tools` و `distributor_surgical_tools`:
- ✅ `surgical_tools` يستخدم `NEW.tool_name`
- ✅ `distributor_surgical_tools` يستخدم placeholder

الآن جميع الجداول يجب أن تعمل! 🚀
