# 🔍 نحتاج Render Logs

## ❌ المشكلة:

مازال يظهر:
```
Tab Name: price_action
Title: 💰 تم تحديث سعر منتج
```

بدلاً من:
```
Tab Name: expire_soon_price
Title: 💰⚠️ تحديث سعر منتج على وشك انتهاء صلاحيته
```

---

## 🔍 نحتاج هذه المعلومات:

### 1️⃣ من Render Logs (آخر webhook):

انسخ **كل السطور** من البداية للنهاية:

```
📩 تلقي webhook من Supabase
   Operation: ...
   Table: ...
   Record: {...}
   Product Name: ...
   Tab Name: ...
✅ تم إرسال الإشعار بنجاح!
   Title: ...
```

**أرسل لي كل السطور بالكامل!**

---

### 2️⃣ افحص المنتج في Supabase:

```sql
SELECT 
  id,
  product_id,
  price,
  expiration_date,
  EXTRACT(DAY FROM (expiration_date - NOW())) as days_remaining,
  CASE 
    WHEN expiration_date IS NULL THEN '❌ لا يوجد تاريخ'
    WHEN expiration_date <= NOW() THEN '❌ منتهي'
    WHEN expiration_date > NOW() + INTERVAL '60 days' THEN '❌ أكثر من 60 يوم'
    ELSE '✅ قارب انتهاء (1-60 يوم)'
  END as status
FROM distributor_products
WHERE id = 'd2dc420f-bdf4-4dd9-8212-279cb74922a9_592_20 ml vial';
```

**أرسل لي النتيجة!**

---

### 3️⃣ تأكد من Deploy:

في Render Dashboard:
- **Events** tab
- شاهد آخر deploy
- **متى تم؟** (يجب أن يكون بعد آخر push)

---

## 🤔 الأسباب المحتملة:

### السبب 1: المنتج ليس قارب انتهاء فعلياً

**إذا كان `expiration_date`:**
- ❌ أكثر من 60 يوم → لن يعتبره قارب انتهاء
- ❌ NULL → لن يعتبره قارب انتهاء
- ❌ منتهي بالفعل (< NOW) → لن يعتبره قارب انتهاء

**الحل:** اختبر بمنتج ينتهي خلال 30 يوم

---

### السبب 2: Deploy لم ينتهي أو فشل

**الحل:** تأكد من Deploy status في Render

---

### السبب 3: خطأ في جلب expiration_date

**للتحقق:** ابحث في Render Logs عن:
```
خطأ في جلب expiration_date: ...
```

إذا كان موجود، معناها مشكلة في الاتصال بـ Supabase.

---

## 🧪 اختبار جديد تماماً:

### أضف منتج تجريبي:

```sql
-- 1. حذف المنتج التجريبي القديم (إذا كان موجود)
DELETE FROM distributor_products WHERE id = 'final_test_expire_price';

-- 2. أضف منتج جديد ينتهي خلال 30 يوم
INSERT INTO distributor_products (
  id,
  distributor_id, 
  product_id,
  package,
  price,
  expiration_date
) VALUES (
  'final_test_expire_price',
  (SELECT id FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products LIMIT 1),
  'Test Box',
  100.00,
  NOW() + INTERVAL '30 days'
);
```

**المتوقع:**
```
⚠️ تم إضافة منتج قريب الصلاحية
[اسم المنتج] - [موزع] - ينتهي خلال 30 يوم
```

---

### حدّث السعر:

```sql
UPDATE distributor_products
SET price = 150.00
WHERE id = 'final_test_expire_price';
```

**المتوقع:**
```
💰⚠️ تحديث سعر منتج على وشك انتهاء صلاحيته
[اسم المنتج] - [موزع]
```

---

### افحص Render Logs:

**يجب أن تشاهد:**
```
📩 تلقي webhook من Supabase
   Tab Name: expire_soon_price  ← يجب أن يكون هذا!
✅ تم إرسال الإشعار بنجاح!
   Title: 💰⚠️ تحديث سعر منتج على وشك انتهاء صلاحيته
```

---

## 📊 جدول التشخيص:

| ما تشاهده في Logs | المشكلة | الحل |
|-------------------|---------|------|
| `Tab Name: price_action` | لم يتعرف على منتج قارب انتهاء | افحص `expiration_date` في SQL |
| `Tab Name: expire_soon_price` | ✅ صحيح! | الكود يعمل، تحقق من الإشعار |
| خطأ في جلب expiration_date | مشكلة اتصال Supabase | تحقق من SUPABASE_URL/KEY |
| لا يوجد logs جديدة | Deploy لم ينتهي | انتظر Deploy |

---

**أرسل لي المعلومات وسأحل المشكلة! 🔍**
