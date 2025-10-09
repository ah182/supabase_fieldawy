# 🔧 إصلاح خطأ Offers Trigger

## ❌ الخطأ

```
record "new" has no field "product_name"
```

عند إضافة عرض في جدول `offers`.

---

## 💡 السبب

جدول `offers` **ليس لديه** الأعمدة التالية:
- ❌ `product_name`
- ❌ `title`

### بنية جدول offers:

```sql
CREATE TABLE offers (
  id uuid PRIMARY KEY,
  product_id text NOT NULL,           -- معرف المنتج
  is_ocr boolean NOT NULL,            -- OCR أم catalog
  user_id uuid NOT NULL,              -- صاحب العرض
  price numeric(12,2) NOT NULL,       -- السعر
  expiration_date timestamptz NOT NULL, -- تاريخ انتهاء العرض
  description text,                   -- ✅ وصف العرض (هذا موجود!)
  package text,                       -- العبوة
  created_at timestamptz,
  updated_at timestamptz
);
```

---

## ✅ الحل

### قبل ❌:
```sql
ELSIF TG_TABLE_NAME = 'offers' THEN
  product_name := COALESCE(NEW.product_name, NEW.title, 'عرض');
  -- ❌ NEW.product_name غير موجود!
  -- ❌ NEW.title غير موجود!
```

### بعد ✅:
```sql
ELSIF TG_TABLE_NAME = 'offers' THEN
  -- جدول offers لديه description فقط
  product_name := COALESCE(NEW.description, 'عرض');
  -- ✅ NEW.description موجود!
```

---

## 🧪 اختبار

### Test 1: إضافة عرض

```sql
INSERT INTO offers (
  product_id,
  is_ocr,
  user_id,
  price,
  expiration_date,
  description,
  package
) VALUES (
  (SELECT id::text FROM products LIMIT 1),
  false,
  auth.uid(),
  75.00,
  NOW() + INTERVAL '7 days',
  'خصم 25% على Panadol',
  'Box of 100'
);
```

**النتيجة المتوقعة:**
- ✅ لا يوجد خطأ
- ✅ trigger يُشغّل
- ✅ إشعار يُرسل: "تم إضافة خصم 25% على Panadol في العروض"

---

### Test 2: إضافة عرض بدون description

```sql
INSERT INTO offers (
  product_id,
  is_ocr,
  user_id,
  price,
  expiration_date,
  package
) VALUES (
  (SELECT id::text FROM products LIMIT 1),
  false,
  auth.uid(),
  50.00,
  NOW() + INTERVAL '3 days',
  'Box of 50'
);
```

**النتيجة المتوقعة:**
- ✅ لا يوجد خطأ
- ✅ إشعار يُرسل: "تم إضافة عرض في العروض"

---

## 🔄 التطبيق

### الخطوة 1: حذف Triggers القديمة

```sql
DROP TRIGGER IF EXISTS trigger_notify_offers ON offers;
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

## 📊 خريطة الأعمدة لكل جدول

| الجدول | عمود الاسم | ملاحظات |
|--------|------------|---------|
| `products` | `name` ✅ | اسم المنتج |
| `distributor_products` | لا يوجد ❌ | يحتاج JOIN مع products |
| `ocr_products` | `product_name` ✅ | اسم المنتج من OCR |
| `distributor_ocr_products` | لا يوجد ❌ | يحتاج JOIN مع ocr_products |
| `surgical_tools` | `tool_name` ✅ | اسم الأداة |
| `distributor_surgical_tools` | `tool_name` ✅ | اسم الأداة |
| `offers` | `description` ✅ | وصف العرض (وليس اسم المنتج) |

---

## ✅ الإصلاحات الكاملة في Trigger

```sql
-- تحديد اسم المنتج بناءً على نوع الجدول
IF TG_TABLE_NAME = 'products' THEN
  product_name := COALESCE(NEW.name, 'منتج');
  
ELSIF TG_TABLE_NAME = 'distributor_products' THEN
  product_name := 'منتج'; -- placeholder
  
ELSIF TG_TABLE_NAME = 'ocr_products' THEN
  product_name := COALESCE(NEW.product_name, 'منتج OCR');
  
ELSIF TG_TABLE_NAME = 'distributor_ocr_products' THEN
  product_name := 'منتج OCR'; -- placeholder
  
ELSIF TG_TABLE_NAME = 'surgical_tools' OR TG_TABLE_NAME = 'distributor_surgical_tools' THEN
  product_name := COALESCE(NEW.tool_name, 'أداة جراحية');
  
ELSIF TG_TABLE_NAME = 'offers' THEN
  product_name := COALESCE(NEW.description, 'عرض'); -- ✅ description
  
ELSE
  product_name := 'منتج';
END IF;
```

---

## 💡 ملاحظة مهمة

في جدول `offers`:
- **ليس هناك** اسم منتج مباشر
- **فقط** `product_id` (للربط)
- **و** `description` (وصف العرض)

لذلك نستخدم `description` في الإشعار.

---

## 🎯 الخلاصة

تم إصلاح:
- ✅ استخدام `NEW.description` بدلاً من `NEW.product_name` أو `NEW.title`
- ✅ الآن إضافة عروض يجب أن تعمل بدون أخطاء

**جاهز للاختبار! 🚀**
