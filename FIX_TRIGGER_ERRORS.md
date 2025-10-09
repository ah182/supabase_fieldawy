# 🔧 إصلاح أخطاء Trigger

## ❌ الأخطاء

### 1. `ocr_product_id` does not exist
```
record "new" has no field "ocr_product_id"
```

**السبب:** حاولنا الوصول لعمود غير موجود في بعض الجداول.

**الحل:** إزالة محاولة الوصول لأعمدة محددة، إرسال بيانات أساسية فقط.

---

### 2. تعديل السعر لم يعد يعمل

**السبب:** منطق التحقق من تغيير السعر لم يكن دقيقاً.

**الحل:** إضافة فحص `TG_OP = 'UPDATE'` والتحقق من NULL.

---

## ✅ الإصلاحات

### 1️⃣ تبسيط pg_notify payload

**قبل ❌:**
```sql
json_build_object(
  'operation', TG_OP,
  'table', TG_TABLE_NAME,
  'product_name', product_name,
  'tab_name', tab_name,
  'product_id', CASE 
    WHEN TG_TABLE_NAME = 'distributor_products' THEN NEW.product_id
    WHEN TG_TABLE_NAME = 'distributor_ocr_products' THEN NEW.ocr_product_id -- ❌ خطأ
    ELSE NULL
  END,
  'record_id', NEW.id
)
```

**بعد ✅:**
```sql
json_build_object(
  'operation', TG_OP,
  'table', TG_TABLE_NAME,
  'product_name', product_name,
  'tab_name', tab_name
)
```

---

### 2️⃣ إصلاح منطق Price Action

**قبل ❌:**
```sql
IF TG_OP = 'UPDATE' AND OLD.price IS NOT NULL AND OLD.price != NEW.price THEN
  tab_name := 'price_action';
```

**المشكلة:** لم يتحقق من `NEW.price IS NOT NULL`

**بعد ✅:**
```sql
IF TG_OP = 'UPDATE' 
   AND OLD.price IS NOT NULL 
   AND NEW.price IS NOT NULL 
   AND OLD.price != NEW.price THEN
  tab_name := 'price_action';
```

---

### 3️⃣ إصلاح منطق Expire Soon

**قبل ❌:**
```sql
ELSIF NEW.expiration_date IS NOT NULL AND 
      NEW.expiration_date <= (NOW() + INTERVAL '60 days') THEN
  tab_name := 'expire_soon';
```

**المشكلة:** قد يرسل إشعار لمنتجات منتهية بالفعل!

**بعد ✅:**
```sql
ELSIF NEW.expiration_date IS NOT NULL AND 
      NEW.expiration_date > NOW() AND  -- ✅ لم ينتهِ بعد
      NEW.expiration_date <= (NOW() + INTERVAL '60 days') THEN
  tab_name := 'expire_soon';
```

---

## 🧪 اختبار بعد الإصلاح

### Test 1: تعديل سعر منتج

```sql
-- إضافة منتج
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  package,
  price
) VALUES (
  'test_price_001',
  (SELECT id FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products LIMIT 1),
  'Box of 100',
  100.00
);

-- تعديل السعر
UPDATE distributor_products
SET price = 150.00
WHERE id = 'test_price_001';
```

**النتيجة المتوقعة:**
- ✅ لا يوجد خطأ
- ✅ `old_price` يُحفظ تلقائياً = 100.00
- ✅ trigger يرسل notification مع `tab_name = 'price_action'`
- ✅ إشعار يصل: "تم تحديث منتج في تغيير السعر"

---

### Test 2: إضافة منتج قرب الانتهاء

```sql
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  package,
  price,
  expiration_date
) VALUES (
  'test_expire_001',
  (SELECT id FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products LIMIT 1),
  'Box of 50',
  75.00,
  NOW() + INTERVAL '30 days' -- ينتهي بعد 30 يوم
);
```

**النتيجة المتوقعة:**
- ✅ لا يوجد خطأ
- ✅ trigger يرسل notification مع `tab_name = 'expire_soon'`
- ✅ إشعار يصل: "تم إضافة منتج في قرب الانتهاء"

---

### Test 3: إضافة منتج منتهي بالفعل (لا يجب إشعار)

```sql
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  package,
  price,
  expiration_date
) VALUES (
  'test_expired_001',
  (SELECT id FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products LIMIT 1),
  'Box of 50',
  75.00,
  NOW() - INTERVAL '10 days' -- منتهي منذ 10 أيام
);
```

**النتيجة المتوقعة:**
- ✅ لا يوجد خطأ
- ✅ trigger يرسل notification مع `tab_name = 'home'` (وليس expire_soon)
- ✅ إشعار يصل: "تم إضافة منتج في الرئيسية"

---

## 🔄 إعادة التطبيق

### الخطوة 1: حذف Triggers والFunction القديمة

```sql
DROP TRIGGER IF EXISTS trigger_notify_products ON products;
DROP TRIGGER IF EXISTS trigger_notify_distributor_products ON distributor_products;
DROP TRIGGER IF EXISTS trigger_notify_ocr_products ON ocr_products;
DROP TRIGGER IF EXISTS trigger_notify_distributor_ocr_products ON distributor_ocr_products;
DROP TRIGGER IF EXISTS trigger_notify_surgical_tools ON surgical_tools;
DROP TRIGGER IF EXISTS trigger_notify_distributor_surgical_tools ON distributor_surgical_tools;
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

### الخطوة 3: إعادة تشغيل Notification Server

```bash
# في terminal
cd D:\fieldawy_store
npm start
```

---

## ✅ التحسينات

| | قبل ❌ | بعد ✅ |
|---|-------|--------|
| **Payload** | معقد (product_id, record_id) | بسيط (فقط الأساسيات) |
| **Price Action** | قد يفشل | دقيق مع فحص NULL |
| **Expire Soon** | يشمل المنتهية | فقط القريبة من الانتهاء |
| **الأخطاء** | ocr_product_id error | لا توجد ✅ |

---

## 📝 ملاحظات مهمة

### Trigger الآن يُرسل فقط:
```json
{
  "operation": "INSERT" | "UPDATE",
  "table": "distributor_products",
  "product_name": "منتج",
  "tab_name": "price_action" | "expire_soon" | "home" | "surgical" | "offers"
}
```

### Webhook Server يستقبل ويستخدم:
```javascript
const { operation, table, product_name, tab_name } = req.body;
// كل البيانات المطلوبة موجودة!
```

---

## 🎯 الخلاصة

تم إصلاح:
1. ✅ إزالة محاولة الوصول لـ `ocr_product_id`
2. ✅ إصلاح منطق Price Action
3. ✅ إصلاح منطق Expire Soon (منع الإشعار للمنتجات المنتهية)
4. ✅ تبسيط payload المُرسل

**كل شيء يجب أن يعمل الآن! 🚀**
