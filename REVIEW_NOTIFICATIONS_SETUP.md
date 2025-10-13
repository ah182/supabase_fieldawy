# 🔔 دليل إعداد إشعارات التقييمات

## 📋 نظرة عامة

سيتم إرسال إشعارات تلقائية لجميع المستخدمين عند:
1. **إضافة طلب تقييم جديد** - يحتوي على اسم المنتج واسم صاحب الطلب
2. **إضافة تعليق جديد** - يحتوي على محتوى التعليق واسم المعلق والتقييم

---

## 🚀 خطوات الإعداد

### 1️⃣ تطبيق SQL Triggers

في Supabase SQL Editor، قم بتنفيذ:

```sql
-- في Supabase Dashboard > SQL Editor
-- افتح الملف: supabase/migrations/ADD_review_notifications_triggers.sql
-- ونفذه
```

**الملف يقوم بـ:**
- ✅ إنشاء function لإرسال webhook عند إضافة طلب تقييم
- ✅ إنشاء function لإرسال webhook عند إضافة تعليق
- ✅ إنشاء triggers تلقائية

---

### 2️⃣ تفعيل pg_net Extension

في Supabase، قم بتفعيل `pg_net` extension لإرسال HTTP requests:

```sql
-- في Supabase Dashboard > SQL Editor
CREATE EXTENSION IF NOT EXISTS pg_net;
```

---

### 3️⃣ تحديث Cloudflare Worker

الملف `cloudflare-webhook/src/index.js` **تم تحديثه** ليدعم:
- ✅ معالجة `review_requests` table
- ✅ معالجة `product_reviews` table
- ✅ إرسال إشعارات مخصصة للتقييمات

**إعادة نشر الـ Worker:**

```bash
cd cloudflare-webhook
npx wrangler deploy
```

---

### 4️⃣ تعيين Webhook URL

بعد نشر الـ Worker، احصل على الـ URL وقم بتعيينه في Supabase:

```sql
-- استبدل YOUR_WORKER_URL بالـ URL الحقيقي
ALTER DATABASE postgres SET app.settings.webhook_url TO 'https://your-worker.workers.dev';
```

**للتحقق:**

```sql
-- للتحقق من الإعداد
SELECT current_setting('app.settings.webhook_url', true);
```

---

## 📱 شكل الإشعارات

### إشعار طلب تقييم جديد:
```
⭐ طلب تقييم جديد
طلب أحمد محمد تقييم دواء باراسيتامول
```

### إشعار تعليق جديد:
```
💬 تعليق جديد (5⭐)
محمد علي: منتج ممتاز وفعال جداً، أنصح به
```

---

## 🧪 اختبار النظام

### اختبار طلب التقييم:
1. افتح التطبيق
2. اضغط على "طلب تقييم لمنتجي"
3. اختر منتج وأرسل الطلب
4. المستخدمون الآخرون يجب أن يستلموا إشعار

### اختبار التعليق:
1. افتح صفحة المنتجات المطلوب تقييمها
2. أضف تقييم مع تعليق
3. المستخدمون الآخرون يجب أن يستلموا إشعار

---

## 🔍 التحقق من الأخطاء

### في Supabase:
```sql
-- عرض آخر الـ notices
SELECT * FROM pg_stat_activity WHERE state = 'active';
```

### في Cloudflare Worker:
1. اذهب لـ Cloudflare Dashboard
2. Workers & Pages > your-worker > Logs
3. راقب الـ console logs

---

## 📊 البيانات المرسلة

### لطلب التقييم:
```json
{
  "type": "new_review_request",
  "review_request_id": "uuid",
  "product_id": "123",
  "product_type": "product"
}
```

### للتعليق:
```json
{
  "type": "new_product_review",
  "review_id": "uuid",
  "review_request_id": "uuid",
  "product_id": "123",
  "product_type": "product",
  "rating": 5
}
```

---

## ⚠️ ملاحظات مهمة

1. **pg_net Extension:**
   - يجب تفعيله في Supabase
   - يستخدم لإرسال HTTP requests من قاعدة البيانات

2. **Webhook URL:**
   - يجب أن يكون accessible من Supabase
   - تأكد أن الـ CORS مفعل في الـ Worker

3. **Firebase Service Account:**
   - متوفر في Cloudflare Worker environment variables
   - ضروري لإرسال FCM notifications

4. **التعليقات الفارغة:**
   - لن يتم إرسال إشعار للتقييمات بدون تعليق
   - فقط التقييمات التي تحتوي على نص

---

## 🎯 الخطوات التالية

1. ✅ تطبيق SQL triggers
2. ✅ تفعيل pg_net
3. ✅ نشر Cloudflare Worker المحدث
4. ✅ تعيين webhook_url
5. ✅ اختبار النظام

**بعد ذلك:**
- راقب الإشعارات على أجهزة مختلفة
- تحقق من الـ logs في Cloudflare
- عدل نصوص الإشعارات حسب الحاجة

---

## 🆘 المساعدة

إذا لم تعمل الإشعارات:

1. **تحقق من pg_net:**
   ```sql
   SELECT * FROM pg_available_extensions WHERE name = 'pg_net';
   ```

2. **تحقق من webhook_url:**
   ```sql
   SELECT current_setting('app.settings.webhook_url', true);
   ```

3. **راقب الـ logs:**
   - Supabase Logs
   - Cloudflare Worker Logs

4. **اختبر الـ Worker مباشرة:**
   ```bash
   curl -X POST https://your-worker.workers.dev \
     -H "Content-Type: application/json" \
     -d '{"type":"INSERT","table":"review_requests","record":{"product_name":"Test","requester_name":"User"}}'
   ```

---

## ✅ جاهز!

النظام الآن جاهز لإرسال إشعارات تلقائية عند إضافة طلبات التقييم والتعليقات! 🎉
