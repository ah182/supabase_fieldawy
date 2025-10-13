# ⚡ إصلاح عاجل للإشعارات

## المشكلة
التعليقات بتتضاف بنجاح لكن **مفيش إشعارات**

---

## ✅ الحل السريع (3 خطوات)

### الخطوة 1️⃣: في Supabase SQL Editor

نفذ الملف:
```
D:\fieldawy_store\supabase\migrations\QUICK_FIX_enable_notifications.sql
```

أو انسخ والصق المحتوى مباشرة.

---

### الخطوة 2️⃣: تعيين Webhook URL

بعد تنفيذ الملف، **لازم** تعيين الـ webhook URL!

```sql
-- استبدل بـ URL الـ Cloudflare Worker الخاص بك
ALTER DATABASE postgres SET app.settings.webhook_url TO 'https://your-worker.workers.dev';
```

**كيف تحصل على الـ URL؟**

#### إذا كان Worker منشور:
1. اذهب لـ [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Workers & Pages
3. اختر الـ worker بتاعك
4. انسخ الـ URL (مثلاً: `https://notifications-abc123.workers.dev`)

#### إذا لم يكن منشور:
```bash
cd D:\fieldawy_store\cloudflare-webhook
npx wrangler deploy
```

بعد النشر، هيظهر الـ URL في الـ terminal.

---

### الخطوة 3️⃣: اختبار

1. أضف تعليق جديد مع نص (مش بس نجوم)
2. راقب الـ **Logs** في Supabase:
   - Database → Logs
   - ابحث عن: `Webhook sent for product_review`

---

## 🔍 التحقق من المشكلة

### فحص سريع في Supabase:

```sql
-- 1. فحص pg_net
SELECT * FROM pg_extension WHERE extname = 'pg_net';
-- لو فاضي → نفذ: CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. فحص webhook_url
SELECT current_setting('app.settings.webhook_url', true);
-- لو NULL → عين الـ URL بالأمر فوق

-- 3. فحص الـ triggers
SELECT trigger_name, event_object_table, event_manipulation
FROM information_schema.triggers
WHERE trigger_name LIKE '%notify%';
-- لازم تشوف trigger_notify_new_product_review
```

---

## 🚨 الأسباب الشائعة

### ❌ السبب 1: pg_net غير مفعل
**الحل:**
```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
```

### ❌ السبب 2: webhook_url غير معرف
**الحل:**
```sql
ALTER DATABASE postgres SET app.settings.webhook_url TO 'https://your-worker.workers.dev';
```

### ❌ السبب 3: Worker غير منشور أو URL خطأ
**الحل:**
```bash
cd cloudflare-webhook
npx wrangler deploy
```

### ❌ السبب 4: التعليق فارغ
الإشعارات بتتبعث **فقط** لو فيه نص في التعليق (مش بس نجوم)

---

## 📱 الإشعار المتوقع

لما تضيف تعليق، المفروض تشوف:

```
⭐ تم تقييم [اسم المنتج]
Fieldawy Store (5⭐): التعليق هنا...
```

---

## 🔧 الـ Logs المهمة

### في Supabase (Database → Logs):
```
✅ Webhook sent for product_review: d01617a2-...
   Product: دواء باراسيتامول, Reviewer: Fieldawy Store
```

### في Cloudflare Worker (Workers → Logs):
```
📩 Received webhook from Supabase
   Type: INSERT
   Table: product_reviews
⭐ تم تقييم دواء باراسيتامول
✅ Notification sent successfully!
```

---

## ✅ قائمة التحقق

- [ ] نفذت `QUICK_FIX_enable_notifications.sql` في Supabase
- [ ] فعلت pg_net extension
- [ ] عينت webhook_url بالـ URL الصحيح
- [ ] نشرت Cloudflare Worker
- [ ] أضفت تعليق **مع نص** (مش بس نجوم)
- [ ] راقبت الـ Logs في Supabase
- [ ] راقبت الـ Logs في Cloudflare

---

## 🆘 لو لسه مش شغال

نفذ ملف الـ DEBUG:
```sql
-- في Supabase SQL Editor
-- نفذ: DEBUG_review_notifications.sql
```

وشاركني النتائج!

---

## 🎯 نقطة مهمة

**الإشعارات بتتبعث فقط لو:**
1. ✅ فيه **تعليق نصي** (مش بس نجوم)
2. ✅ pg_net مفعل
3. ✅ webhook_url معرف وصحيح
4. ✅ Cloudflare Worker شغال

**الإشعارات مش بتتبعث لو:**
- ❌ تقييم بس نجوم بدون تعليق
- ❌ حذف تعليق
- ❌ تحديث تعليق

---

## ⚡ الحل الأسرع

إذا كنت مستعجل:

```sql
-- 1. في Supabase
CREATE EXTENSION IF NOT EXISTS pg_net;
ALTER DATABASE postgres SET app.settings.webhook_url TO 'https://YOUR_WORKER_URL';

-- 2. نفذ: QUICK_FIX_enable_notifications.sql

-- 3. اختبر بإضافة تعليق
```

🎉 جاهز!
