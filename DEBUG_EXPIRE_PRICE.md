# 🔍 تصحيح: إشعار تحديث سعر منتج قارب انتهاء

## ❌ المشكلة:

يظهر:
```
💰 تم تحديث سعر منتج
COLIPRIM Inj.
```

بدلاً من:
```
💰⚠️ تحديث سعر منتج على وشك انتهاء صلاحيته
```

---

## 🔍 الفحص المطلوب:

### 1️⃣ افحص Render Logs:

**في Render Dashboard:**
1. اذهب إلى **Logs** tab
2. ابحث عن آخر webhook تم استقباله
3. انسخ ولصق هذه السطور:

```
📩 تلقي webhook من Supabase
   Operation: UPDATE
   Table: distributor_products
   Record: ...
   Product Name: ...
   Tab Name: ...  ← هذا السطر مهم جداً!
✅ تم إرسال الإشعار بنجاح!
   Title: ...
```

**أرسل لي قيمة `Tab Name`!**

---

### 2️⃣ افحص المنتج في Supabase:

```sql
-- افحص تاريخ انتهاء المنتج
SELECT 
  id,
  product_id,
  price,
  expiration_date,
  CASE 
    WHEN expiration_date IS NULL THEN 'لا يوجد تاريخ انتهاء'
    WHEN expiration_date <= NOW() THEN 'منتهي بالفعل'
    WHEN expiration_date > NOW() + INTERVAL '60 days' THEN 'أكثر من 60 يوم'
    ELSE 'قارب على الانتهاء'
  END as status,
  EXTRACT(DAY FROM (expiration_date - NOW())) as days_left
FROM distributor_products
WHERE id = 'id_of_product_you_updated';  -- ضع ID المنتج الذي حدثته
```

**أرسل لي النتيجة!**

---

## 🎯 الأسباب المحتملة:

### السبب 1: المنتج ليس قارب انتهاء

**إذا كان `expiration_date`:**
- ❌ `NULL` (لا يوجد تاريخ) → لن يُعتبر قارب انتهاء
- ❌ أكثر من 60 يوم → لن يُعتبر قارب انتهاء
- ❌ منتهي بالفعل (أقل من NOW) → لن يُعتبر قارب انتهاء
- ✅ بين 1-60 يوم → يُعتبر قارب انتهاء

---

### السبب 2: الكود لم يُحدث على Render

**للتحقق:**

في Render Logs، ابحث عن:
```
==> Deploying...
==> Your service is live 🎉
```

**وشاهد التوقيت** - يجب أن يكون بعد آخر push على GitHub.

---

### السبب 3: Webhook payload لا يحتوي على `old_record`

**للتحقق:**

في Render Logs، ابحث عن:
```
Record: {"id":"...","price":...,"expiration_date":"..."}
```

**يجب أن يحتوي على:**
- ✅ `expiration_date`
- ✅ تاريخ الانتهاء أقل من 60 يوم

---

## 🧪 اختبار دقيق:

### Test 1: أضف منتج جديد ينتهي خلال 30 يوم

```sql
INSERT INTO distributor_products (
  id,
  distributor_id, 
  product_id,
  package,
  price,
  expiration_date
) VALUES (
  'debug_expire_test',
  (SELECT id FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products WHERE name LIKE '%COLIPRIM%' LIMIT 1),
  'Box',
  100.00,
  NOW() + INTERVAL '30 days'
);
```

**المتوقع:**
```
⚠️ تم إضافة منتج قريب الصلاحية
COLIPRIM - [موزع] - ينتهي خلال 30 يوم
```

---

### Test 2: حدّث السعر

```sql
UPDATE distributor_products
SET price = 150.00
WHERE id = 'debug_expire_test';
```

**المتوقع:**
```
💰⚠️ تحديث سعر منتج على وشك انتهاء صلاحيته
COLIPRIM - [موزع]
```

---

### Test 3: افحص Render Logs

**يجب أن تشاهد:**
```
📩 تلقي webhook من Supabase
   Operation: UPDATE
   Table: distributor_products
   Product Name: COLIPRIM - [موزع]
   Tab Name: expire_soon  ← مهم جداً!
✅ تم إرسال الإشعار بنجاح!
   Title: 💰⚠️ تحديث سعر منتج على وشك انتهاء صلاحيته
```

---

## 📊 جدول التشخيص:

| Tab Name في Logs | النتيجة | السبب |
|------------------|---------|-------|
| `expire_soon` | ✅ صحيح | المنتج قارب انتهاء والكود يعمل |
| `price_action` | ❌ خطأ | المنتج **ليس** قارب انتهاء |
| `home` | ❌ خطأ | لا يوجد `expiration_date` |

---

## 🎯 الخطوات التالية:

**أرسل لي:**

1. **Render Logs** (السطور من 📩 إلى ✅)
2. **نتيجة SQL** (فحص expiration_date للمنتج)
3. **Screenshot** من الإشعار على الجهاز

**وسأحدد المشكلة بالضبط! 🔍**
