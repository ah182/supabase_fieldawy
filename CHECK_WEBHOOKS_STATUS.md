# 🔍 فحص حالة Webhooks

## المشكلة

الإشعارات **بتتكرر** و**فيه إشعارات فارغة** لما التطبيق يكون:
- ❌ مغلق
- ❌ في الـ background

لكن **لما التطبيق مفتوح** - كل شيء تمام! ✅

---

## 💡 السبب

لما التطبيق **مغلق**:
- Android notification system بيعرض الـ `notification` payload مباشرة
- كل webhook = إشعار جديد
- لو فيه مصدرين (Database Webhooks + SQL Triggers) = إشعارين!

لما التطبيق **مفتوح**:
- Flutter بيستقبل `data` payload ويتعامل معاه
- Flutter بيفلتر ومش بيعرض إلا اللي عايزه

---

## ✅ الفحص الشامل

### 1️⃣ فحص Database Webhooks

**في Supabase Dashboard:**

1. اذهب لـ **Database** → **Webhooks**
2. **يجب أن تكون القائمة فارغة!**

**إذا شفت:**
- `reviewrequests` → **احذفه فوراً** ❌
- `productreviews` → **احذفه فوراً** ❌
- أي webhook آخر للتقييمات → **احذفه** ❌

---

### 2️⃣ فحص SQL Triggers

في **Supabase SQL Editor**:

```sql
-- عدد الـ Triggers
SELECT COUNT(*) as trigger_count
FROM information_schema.triggers
WHERE trigger_name LIKE '%notify%';
-- يجب أن يكون: 2 فقط
```

```sql
-- قائمة الـ Triggers
SELECT 
  trigger_name,
  event_object_table,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_name LIKE '%notify%'
ORDER BY event_object_table;

-- يجب أن ترى:
-- trigger_notify_new_review_request | review_requests | INSERT
-- trigger_notify_new_product_review  | product_reviews  | INSERT
```

**إذا شفت أكثر من 2:**
- ⚠️ فيه triggers مكررة!
- الحل: نفذ `FIX_DUPLICATE_AND_EMPTY_NOTIFICATIONS.sql`

---

### 3️⃣ فحص شرط التعليق في الـ Trigger

```sql
-- التحقق من شرط التعليق
SELECT 
  trigger_name,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trigger_notify_new_product_review';

-- يجب أن يحتوي على:
-- WHEN (NEW.comment IS NOT NULL AND trim(NEW.comment) <> '')
```

---

### 4️⃣ اختبار مباشر

```sql
-- اختبار: إضافة تقييم بدون تعليق
INSERT INTO product_reviews (
  review_request_id,
  product_id,
  product_type,
  user_id,
  rating
) VALUES (
  (SELECT id FROM review_requests WHERE status = 'active' LIMIT 1),
  'test',
  'product',
  auth.uid(),
  5
);

-- راقب الـ Logs
-- يجب أن ترى:
-- ⏭️ Skipping notification - no comment
-- ولا يجب أن يُرسل webhook!
```

---

## 🎯 الحل حسب النتيجة

### إذا Database Webhooks موجودة:
**هذا هو السبب الرئيسي!**

```
مستخدم يضيف تعليق:
  1. Database Webhook → إشعار
  2. SQL Trigger → إشعار
  = إشعارين! ❌
```

**الحل:**
1. احذف كل Database Webhooks
2. اترك SQL Triggers فقط

---

### إذا عدد Triggers > 2:
**فيه triggers مكررة!**

**الحل:**
```sql
-- نفذ الملف:
FIX_DUPLICATE_AND_EMPTY_NOTIFICATIONS.sql
```

---

### إذا الـ Trigger مفيهوش شرط التعليق:
**هذا سبب الإشعارات الفارغة!**

**الحل:**
```sql
-- نفذ الملف:
FIX_DUPLICATE_AND_EMPTY_NOTIFICATIONS.sql
```

---

## 📊 سيناريو التشخيص

### سيناريو 1: التكرار
```
عدد Database Webhooks: 2
عدد SQL Triggers: 2
النتيجة: 4 webhooks لكل تعليق = 4 إشعارات! 😱

الحل: احذف Database Webhooks
```

### سيناريو 2: الإشعارات الفارغة
```
Trigger بدون شرط التعليق
تقييم بالنجوم فقط → webhook → إشعار فارغ

الحل: إضافة شرط WHEN (NEW.comment IS NOT NULL)
```

---

## ✅ الحل النهائي المضمون

### الخطوة 1: حذف Database Webhooks

**في Supabase Dashboard:**
- Database → Webhooks → **احذف الكل**

### الخطوة 2: تنظيف SQL Triggers

```sql
-- في Supabase SQL Editor
-- نفذ: FIX_DUPLICATE_AND_EMPTY_NOTIFICATIONS.sql
```

### الخطوة 3: التحقق

```sql
-- يجب أن يكون العدد = 0
SELECT COUNT(*) FROM information_schema.triggers 
WHERE event_object_table IN ('review_requests', 'product_reviews')
  AND trigger_name NOT LIKE '%notify%';

-- يجب أن يكون العدد = 2
SELECT COUNT(*) FROM information_schema.triggers 
WHERE trigger_name LIKE '%notify%';
```

### الخطوة 4: اختبار نهائي

1. **أغلق التطبيق تماماً**
2. من جهاز آخر:
   - أضف **تعليق** → **يجب أن يظهر إشعار واحد** ✅
   - أضف **تقييم بدون تعليق** → **لا يظهر إشعار** ✅
3. **لا تكرار** ✅

---

## 🆘 إذا لم يحل

نفذ هذا وشاركني النتيجة:

```sql
-- معلومات شاملة
SELECT 
  'Database Webhooks' as source,
  'Check manually in Dashboard' as status
UNION ALL
SELECT 
  'SQL Triggers',
  COUNT(*)::text || ' triggers found'
FROM information_schema.triggers
WHERE trigger_name LIKE '%notify%';
```

وأيضاً:
1. screenshot من Database → Webhooks
2. عدد الإشعارات اللي بتظهر لكل تعليق

---

## 🎉 النتيجة المتوقعة

بعد الإصلاح:
- ✅ إشعار **واحد فقط** لكل تعليق
- ✅ **لا إشعارات** للتقييمات بدون تعليق
- ✅ يعمل مع التطبيق **مغلق** و **مفتوح**
- ✅ يعمل في الـ **background**

**كل شيء يجب أن يكون متناسق!** 🚀
