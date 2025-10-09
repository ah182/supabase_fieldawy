# 🔍 تشخيص سريع: Render لا يرسل إشعارات

## ✅ Checklist سريع

افحص كل نقطة بالترتيب:

---

## 1️⃣ هل Render Service يعمل؟

**في Render Dashboard:**

**افتح service الخاص بك > شاهد Status**

**يجب أن تشاهد:**
```
🟢 Live
```

**إذا شاهدت:**
- 🔴 **Failed** → افحص Logs (الخطوة 2)
- 🟡 **Building** → انتظر حتى ينتهي

---

## 2️⃣ افحص Logs في Render

**في Render Dashboard:**

**اذهب إلى Logs tab**

**ابحث عن:**

### ✅ رسائل النجاح:
```
🚀 Notification webhook server is running on port 10000
```

### ❌ رسائل الخطأ:

**خطأ 1: Cannot find module**
```
Error: Cannot find module 'express'
```
**الحل:**
- `package.json` غير صحيح
- أضف `"type": "module"` في package.json
- تأكد من `dependencies` موجودة

---

**خطأ 2: Service Account**
```
Error: Could not load the default credentials
```
**الحل:**
- Service account غير موجود
- أضف Environment Variable (الخطوة 5)

---

**خطأ 3: Port Error**
```
Error: listen EADDRINUSE: address already in use
```
**الحل:**
- تأكد من `const PORT = process.env.PORT || 3000;`

---

## 3️⃣ اختبر URL مباشرة

**في المتصفح، افتح:**
```
https://your-app-name.onrender.com/api/notify/product-change
```

**يجب أن تشاهد:**
```
Cannot GET /api/notify/product-change
```
أو
```
Method Not Allowed
```

**✅ هذا جيد!** معناها الـ endpoint موجود.

**❌ إذا شاهدت:**
```
Application failed to respond
```
**معناها:** Service لا يعمل → ارجع للخطوة 2

---

## 4️⃣ افحص Webhook في Supabase

**في Supabase:**

**Database > Webhooks > اختر webhook > Logs**

**يجب أن تشاهد entries عند إضافة منتج**

### إذا Logs فارغة:

**السبب 1:** Webhook غير مُفعّل
- تحقق من Status = **Enabled**

**السبب 2:** Events غير محددة
- تحقق من ☑️ Insert و ☑️ Update محددة

**السبب 3:** الجدول خطأ
- عند إضافة أداة من التطبيق، الجدول هو `distributor_surgical_tools`
- تأكد من وجود webhook لهذا الجدول

---

### إذا Logs موجودة:

**افحص Status Code:**

**Status 200:** ✅ Webhook وصل بنجاح
- المشكلة في إرسال FCM
- ارجع للخطوة 5

**Status 404:** ❌ URL خطأ
- تحقق من URL في webhook
- يجب أن ينتهي بـ `/api/notify/product-change`

**Status 500:** ❌ خطأ في Server
- افحص Render Logs
- ربما Service Account غير موجود

**Status 503:** ⏱️ Service نائم (Cold Start)
- انتظر 30-60 ثانية وأعد المحاولة

---

## 5️⃣ Service Account File

**المشكلة الأكثر شيوعاً!**

**في Render Dashboard:**

**Settings > Environment Variables**

### الخيار A: Environment Variable (موصى به)

**أضف:**
```
Key: FIREBASE_SERVICE_ACCOUNT
Value: {"type":"service_account","project_id":"fieldawy-store-app",...}
```

**انسخ محتوى `fieldawy-store-app-66c0ffe5a54f.json` كله!**

---

### الخيار B: رفع الملف مع الكود

**تأكد أن الملف موجود على GitHub:**

```bash
# في D:\fieldawy_store
git add fieldawy-store-app-66c0ffe5a54f.json
git commit -m "Add service account"
git push
```

⚠️ **تأكد أن Repository على GitHub Private!**

---

## 6️⃣ اختبار خطوة بخطوة

### Test 1: Test من SQL

**في Supabase SQL Editor:**
```sql
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Render Test', 'Test Company');
```

**افحص:**
1. ✅ Supabase Webhook Logs → يجب أن تشاهد entry
2. ✅ Render Logs → يجب أن تشاهد `📩 تلقي webhook`
3. ✅ جهازك → يجب أن يصل إشعار

**أي خطوة فشلت؟**
- الخطوة 1 فشلت → Webhook في Supabase المشكلة
- الخطوة 2 فشلت → Render لا يستقبل
- الخطوة 3 فشلت → FCM المشكلة

---

### Test 2: Test FCM مباشرة

**على الكمبيوتر:**
```bash
cd D:\fieldawy_store
node test_notification_direct.js
```

**هل وصل إشعار؟**
- ✅ نعم → FCM يعمل، المشكلة في webhook
- ❌ لا → التطبيق غير مشترك في topic

---

## 7️⃣ Cold Start (مهم!)

**Render Free Tier:**
- بعد 15 دقيقة بلا استخدام، Service ينام
- أول webhook يأخذ **30-60 ثانية** للاستيقاظ

**الحل المؤقت:**
- انتظر دقيقة وأعد المحاولة
- أو انتقل لـ Paid Plan

---

## 🎯 السيناريوهات الشائعة

### السيناريو 1: Service لا يبدأ

**الأعراض:**
- Status = Failed/Error
- Logs تظهر أخطاء

**الحل:**
1. افحص `package.json` صحيح
2. تأكد من `"type": "module"`
3. أضف Service Account كـ Environment Variable

---

### السيناريو 2: Webhook لا يصل

**الأعراض:**
- Render Logs فارغة
- Supabase Webhook Logs فارغة

**الحل:**
1. تحقق من Webhook Status = Enabled
2. تحقق من Events محددة
3. تحقق من الجدول صحيح

---

### السيناريو 3: Webhook يصل لكن لا إشعار

**الأعراض:**
- Render Logs تظهر `📩 تلقي webhook`
- لكن لا إشعار

**الحل:**
1. افحص FCM Service Account
2. اختبر `node test_notification_direct.js`
3. تأكد من الاشتراك في topic

---

## 🛠️ خطوات الإصلاح السريعة

### إذا كان Service لا يعمل:

```bash
# 1. تأكد من package.json صحيح
# 2. أضف Service Account في Render Environment Variables
# 3. أعد Deploy:

cd D:\fieldawy_store
git add .
git commit -m "Fix configuration"
git push
```

**في Render:**
- Manual Deploy > Deploy latest commit

---

### إذا كان Webhook لا يصل:

**في Supabase:**
1. احذف webhook القديم
2. أضف webhook جديد:
   - Table: `distributor_surgical_tools`
   - Events: ✅ Insert, ✅ Update
   - URL: `https://your-app.onrender.com/api/notify/product-change`
   - Status: Enabled

---

## 📸 معلومات مطلوبة

**إذا ما زال لا يعمل، أرسل لي:**

### 1. من Render Logs (آخر 20 سطر):
```
[نسخ ولصق]
```

### 2. من Supabase Webhook Logs:
```
Status: [200/404/500]
Response: [...]
```

### 3. Render Service Status:
- [ ] 🟢 Live
- [ ] 🔴 Failed
- [ ] 🟡 Building

### 4. هل أضفت Service Account؟
- [ ] نعم، كـ Environment Variable
- [ ] نعم، رفعته مع الكود
- [ ] لا

---

## 🎯 Quick Debug Command

**شغّل هذا على الكمبيوتر:**

```bash
# Test 1: FCM يعمل؟
node test_notification_direct.js

# Test 2: Render يستجيب؟
curl https://your-app.onrender.com/api/notify/product-change
```

---

**أرسل لي نتائج الفحوصات وسأساعدك! 🔍**
