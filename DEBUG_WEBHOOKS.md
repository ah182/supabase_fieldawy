# 🔍 تصحيح: Webhooks لا تصل

## ✅ ما يعمل:
- SQL query نجح
- FCM notifications تعمل (اختبرنا بـ test_notification_direct.js)

## ❌ ما لا يعمل:
- Webhooks لا تصل للـ server

---

## 🔍 الفحوصات:

### 1️⃣ هل Server يعمل؟

**في Terminal حيث npm start:**

يجب أن تشاهد:
```
🚀 Notification webhook server is running on port 3000
📡 Endpoint: http://localhost:3000/api/notify/product-change
```

- ✅ **موجود:** Server يعمل
- ❌ **غير موجود:** شغّل `npm start`

---

### 2️⃣ هل localtunnel يعمل؟

**في Terminal حيث lt:**

يجب أن تشاهد:
```
your url is: https://abc-123.loca.lt
```

- ✅ **موجود:** Tunnel يعمل
- ❌ **غير موجود:** شغّل `lt --port 3000`

---

### 3️⃣ هل Webhooks مُضافة في Supabase؟

**الفحص:**
1. افتح **Supabase Dashboard**
2. اذهب إلى **Database** > **Webhooks**
3. هل ترى webhooks مُضافة؟

- ✅ **نعم:** انتقل للخطوة 4
- ❌ **لا:** يجب إضافتها!

---

### 4️⃣ هل Webhook URL صحيح؟

**في Supabase Webhooks:**

يجب أن يكون URL:
```
https://abc-123.loca.lt/api/notify/product-change
```

**تحقق من:**
- ✅ يبدأ بـ `https://`
- ✅ ينتهي بـ `/api/notify/product-change`
- ✅ نفس URL الذي أعطاه localtunnel

---

### 5️⃣ هل Webhook enabled؟

**في Supabase Webhooks:**

تحقق من Status:
- ✅ **Enabled:** جيد
- ❌ **Disabled:** فعّله!

---

## 🐛 المشكلة الشائعة: Webhooks غير مُضافة!

**السبب الأكثر احتمالاً:** 
لم يتم إضافة webhooks في Supabase بعد!

---

## ✅ الحل: إضافة Webhooks الآن

### الخطوة 1: احصل على URL من localtunnel

**في Terminal 2:**
```bash
lt --port 3000
```

**انسخ URL مثل:**
```
https://funny-cats-123.loca.lt
```

---

### الخطوة 2: أضف Webhook في Supabase

1. افتح **Supabase Dashboard**
2. اذهب إلى **Database** > **Webhooks**
3. اضغط **Create a new hook**
4. املأ:

```
Name: surgical_tools_webhook
Schema: public
Table: surgical_tools
Events: ✅ Insert  ✅ Update
Type: HTTP Request
Method: POST
URL: https://funny-cats-123.loca.lt/api/notify/product-change
Timeout: 5000

HTTP Headers (اضغط Add header):
Key: Content-Type
Value: application/json
```

5. اضغط **Confirm**

---

### الخطوة 3: اختبر!

```sql
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Webhook Test 2', 'Test Company');
```

**يجب أن تشاهد:**

**في Terminal 1 (server):**
```
📩 تلقي webhook من Supabase
   Operation: INSERT
   Table: surgical_tools
   Product Name: Webhook Test 2
   Tab Name: surgical
✅ تم إرسال الإشعار بنجاح!
```

**على جهازك:**
```
تم إضافة Webhook Test 2 في الأدوات الجراحية والتشخيصية
```

---

## 🧪 اختبار localtunnel بدون Supabase

**اختبار يدوي:**

```bash
curl https://your-url.loca.lt/api/notify/product-change \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"operation":"INSERT","table":"surgical_tools","product_name":"Test","tab_name":"surgical"}'
```

**إذا عمل:**
- ✅ localtunnel + server يعملان
- ❌ المشكلة في Supabase webhooks

**إذا لم يعمل:**
- ❌ localtunnel أو server لا يعمل

---

## 📊 Checklist سريع:

قبل أن تعمل webhooks:

- [ ] `npm start` يعمل في Terminal 1
- [ ] `lt --port 3000` يعمل في Terminal 2
- [ ] Webhook مُضاف في Supabase لجدول `surgical_tools`
- [ ] Webhook URL = `https://xxx.loca.lt/api/notify/product-change`
- [ ] Webhook Status = Enabled
- [ ] Webhook Events = Insert + Update

---

## 💡 ملاحظة مهمة

**أول مرة تفتح localtunnel URL:**

قد يطلب منك verification:
1. افتح `https://your-url.loca.lt` في browser
2. اضغط **Click to Continue**
3. أدخل IP المعروض
4. الآن webhooks ستعمل!

---

## 🎯 الخطوة التالية

**أخبرني:**
1. هل `npm start` يعمل الآن؟
2. هل `lt --port 3000` يعمل؟
3. هل أضفت webhook في Supabase؟

وسنحل المشكلة! 🚀
