# 🚀 دليل سريع: تفعيل إشعارات المنتجات

## ✅ ما تم إنجازه:

- ✅ Firebase Cloud Messaging يعمل
- ✅ التطبيق يستقبل الإشعارات
- ✅ Test notification يصل (test_notification_direct.js)
- ✅ Notification server جاهز
- ✅ Webhooks تم إضافتها في Supabase

## ❌ المشكلة:

Webhooks لا تصل للـ server عند إضافة منتجات

---

## 🔍 التشخيص

### الفحص 1: هل Server يعمل؟

**افتح Terminal 1:**
```bash
cd D:\fieldawy_store
npm start
```

**يجب أن تشاهد:**
```
🚀 Notification webhook server is running on port 3000
📡 Endpoint: http://localhost:3000/api/notify/product-change
```

✅ إذا شاهدته: Server يعمل  
❌ إذا لم تشاهده: شغّل npm start

---

### الفحص 2: هل localtunnel يعمل؟

**افتح Terminal 2 (جديد):**
```bash
lt --port 3000
```

**يجب أن تشاهد:**
```
your url is: https://random-name-123.loca.lt
```

✅ إذا شاهدته: Tunnel يعمل  
❌ إذا لم تشاهده: شغّل lt --port 3000

---

### الفحص 3: Verification (مهم جداً!)

**الخطوة الأساسية التي قد تكون مفقودة:**

1. افتح localtunnel URL في المتصفح:
   ```
   https://your-random-name.loca.lt
   ```

2. ستشاهد صفحة:
   ```
   Friendly Reminder
   
   This page is used by someone you know
   Click to Continue
   
   Tunnel Password: xxx.xxx.xxx.xxx
   ```

3. اضغط **"Click to Continue"**

4. أدخل الـ IP المعروض (مثل: `123.45.67.89`)

5. اضغط **Submit**

6. ستفتح الصفحة وتشاهد:
   ```
   Notification Webhook Server
   Listening for product notifications...
   ```

**✅ الآن فقط Webhooks ستعمل!**

بدون هذه الخطوة، Supabase لن يستطيع إرسال webhooks!

---

### الفحص 4: اختبار Webhook

**بعد عمل Verification، اختبر:**

```sql
-- في Supabase SQL Editor
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Test After Verification', 'Test Co');
```

**يجب أن تشاهد في Terminal 1:**
```
📩 تلقي webhook من Supabase
   Operation: INSERT
   Table: surgical_tools
   Product Name: Test After Verification
✅ تم إرسال الإشعار بنجاح!
```

**وعلى جهازك:**
```
إشعار: تم إضافة Test After Verification في الأدوات الجراحية والتشخيصية
```

---

## 🐛 إذا ما زال لا يعمل:

### المشكلة 1: Server لا يستقبل شيء

**التشخيص:**
```bash
# في terminal جديد
curl http://localhost:3000/api/notify/product-change \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"operation\":\"INSERT\",\"table\":\"surgical_tools\",\"product_name\":\"Test\",\"tab_name\":\"surgical\"}"
```

**إذا شاهدت في server terminal:**
```
📩 تلقي webhook من Supabase
```
✅ Server يعمل، المشكلة في tunnel أو Supabase

**إذا لم تشاهد شيء:**
❌ Server لا يعمل، شغّل `npm start`

---

### المشكلة 2: Verification لم يتم

**الحل:**
1. افتح localtunnel URL في browser
2. أكمل verification
3. أعد اختبار webhook

---

### المشكلة 3: Webhook URL خطأ

**في Supabase > Database > Webhooks:**

تحقق من URL:
```
✅ صحيح: https://abc-123.loca.lt/api/notify/product-change
❌ خطأ:   https://abc-123.loca.lt
❌ خطأ:   http://abc-123.loca.lt/api/notify/product-change (http بدلاً من https)
```

---

### المشكلة 4: Webhook معطّل

**في Supabase Webhooks:**

Status يجب أن يكون:
- ✅ **Enabled** (أخضر)
- ❌ **Disabled** (رمادي)

إذا كان Disabled، اضغط عليه واختر **Enable**

---

## 📊 Supabase Webhook Logs

**للتأكد إذا كان Supabase يُرسل webhook أم لا:**

1. في Supabase Dashboard
2. اذهب إلى **Database** > **Webhooks**
3. اضغط على webhook (مثل `surgical_tools_webhook`)
4. اختر **Logs** tab

**ستشاهد:**
- ✅ **Status: 200** → Webhook وصل بنجاح
- ❌ **Status: 404/500** → هناك خطأ
- ❌ **لا توجد logs** → Webhook لم يُطلق أصلاً

---

## 🎯 الخطوات النهائية (مرتبة)

### 1. شغّل Server
```bash
cd D:\fieldawy_store
npm start
```
✅ اترك Terminal مفتوح

### 2. شغّل Tunnel
```bash
# في terminal جديد
lt --port 3000
```
✅ اترك Terminal مفتوح
✅ انسخ URL

### 3. عمل Verification
- افتح URL في browser
- أكمل verification

### 4. تحديث Webhooks (إذا لزم)
- في Supabase > Webhooks
- تأكد URL صحيح

### 5. اختبار
```sql
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Final Test', 'Test');
```

### 6. انتظر النتيجة
- شاهد Terminal (server)
- شاهد جهازك

---

## ✅ النتيجة المتوقعة

**عند إضافة منتج:**
1. Supabase يُطلق webhook
2. Webhook يصل لـ localtunnel
3. localtunnel يوصله لـ server المحلي
4. Server يُرسل FCM notification
5. إشعار يظهر على جهازك 🎉

---

## 💡 ملاحظة للـ Production

**للتطوير:**
✅ استخدم localtunnel (مؤقت)

**للإنتاج:**
استخدم واحد من هذه:
- ✅ Supabase Edge Functions
- ✅ Deploy server على Railway/Heroku
- ✅ استخدام ngrok مع domain ثابت

---

## 🆘 إذا ما زال لا يعمل

**أرسل لي screenshot من:**

1. Terminal حيث `npm start`
2. Terminal حيث `lt --port 3000`
3. Supabase Webhook Configuration
4. Supabase Webhook Logs

وسأساعدك! 🚀
