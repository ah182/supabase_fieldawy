# 🔍 تصحيح: الإشعارات لا تعمل من التطبيق

## ✅ ما يعمل:
- SQL command → webhook يُرسل → إشعار يصل

## ❌ ما لا يعمل:
- إضافة من التطبيق → لا يوجد إشعار

---

## 🔍 خطوات الفحص الدقيق

### 1️⃣ تحقق من أن Server لا يزال يعمل

**في Terminal حيث `npm start`:**

هل ما زلت تشاهد:
```
🚀 Notification webhook server is running on port 3000
```

- ✅ نعم → انتقل للخطوة 2
- ❌ لا → شغّل `npm start` مرة أخرى

---

### 2️⃣ تحقق من أن localtunnel لا يزال يعمل

**في Terminal حيث `lt --port 3000`:**

هل ما زلت تشاهد:
```
your url is: https://little-mice-ask.loca.lt
```

- ✅ نعم → انتقل للخطوة 3
- ❌ لا → شغّل `lt --port 3000` مرة أخرى

⚠️ **مهم:** إذا أعدت تشغيل localtunnel، ستحصل على URL جديد!
يجب تحديث جميع webhooks بالـ URL الجديد!

---

### 3️⃣ عند الإضافة من التطبيق - راقب Terminal

**عند إضافة أداة من التطبيق:**

**افتح Terminal (حيث npm start) وراقبه:**

**السيناريو A:** تشاهد رسائل
```
📩 تلقي webhook من Supabase
   Table: distributor_surgical_tools
```

✅ **معناها:** Webhook يصل لكن المشكلة في إرسال الإشعار
→ انتقل للخطوة 4

---

**السيناريو B:** لا تشاهد أي رسائل

❌ **معناها:** Webhook لا يصل أصلاً
→ انتقل للخطوة 5

---

### 4️⃣ إذا Webhook يصل لكن لا يوجد إشعار

**المشكلة:** FCM token issue

**الحل:**

#### أ) تحقق من Tokens في Supabase:

```sql
SELECT COUNT(*) FROM user_tokens WHERE updated_at > NOW() - INTERVAL '1 day';
```

**إذا النتيجة 0:**
- سجّل خروج من التطبيق
- سجّل دخول مرة أخرى
- انتظر حتى تشاهد في console:
  ```
  ✅ تم حفظ FCM Token في Supabase بنجاح
  ```

#### ب) جرب إرسال يدوي:

```bash
node test_notification_direct.js
```

**إذا وصل إشعار:**
✅ FCM يعمل، المشكلة في webhook payload

**إذا لم يصل:**
❌ مشكلة في الاشتراك في topic

---

### 5️⃣ إذا Webhook لا يصل أصلاً

**افحص Webhook Logs في Supabase:**

**الخطوات:**
1. Database > Webhooks
2. اضغط على `distributor_surgical_tools_notifications`
3. اختر **Logs** tab

**السيناريو A:** Logs فارغة
```
No logs found
```

❌ **السبب:** Events غير محددة أو Webhook معطّل

**الحل:**
- تحقق من أن Status = Enabled
- تحقق من أن Events (Insert, Update) محددة
- احذف webhook وأعد إنشاءه

---

**السيناريو B:** Logs موجودة بـ Status 404/500
```
Timestamp             Status
2025-01-08 11:30:00   404
```

❌ **السبب:** URL خطأ

**الحل:**
- تحقق من URL في webhook
- يجب أن ينتهي بـ `/api/notify/product-change`
- تأكد أن localtunnel لا يزال يعمل

---

**السيناريو C:** Logs موجودة بـ Status 200
```
Timestamp             Status
2025-01-08 11:30:00   200
```

✅ **معناها:** Webhook وصل بنجاح!
→ ارجع للخطوة 4

---

## 🧪 اختبار تدريجي

### Test 1: SQL Command

```sql
INSERT INTO distributor_surgical_tools (
  distributor_id,
  distributor_name,
  surgical_tool_id,
  description,
  price
) VALUES (
  auth.uid(),
  'Test Distributor',
  (SELECT id FROM surgical_tools LIMIT 1),
  'SQL Test',
  100.00
);
```

**النتيجة:**
- ✅ يعمل: Webhook + إشعار يصل
- ❌ لا يعمل: مشكلة في webhook configuration

---

### Test 2: من التطبيق

1. افتح التطبيق
2. أضف أداة جراحية
3. **راقب Terminal فوراً**

**النتيجة:**
- ✅ تشاهد `📩 تلقي webhook`: Webhook يعمل
- ❌ لا تشاهد شيء: Webhook لا يصل

---

## 🔧 الحلول الشائعة

### الحل 1: أعد تشغيل كل شيء

```bash
# Terminal 1
Ctrl+C (أوقف npm start)
npm start

# Terminal 2  
Ctrl+C (أوقف localtunnel)
lt --port 3000

# انسخ URL الجديد
# حدّث جميع webhooks بالـ URL الجديد!
```

---

### الحل 2: تحقق من Auth User

**عند إضافة من التطبيق:**

```sql
-- تحقق من أن المستخدم مسجل دخول
SELECT auth.uid();
```

**إذا النتيجة NULL:**
- المستخدم غير مسجل دخول
- سجّل دخول مرة أخرى

---

### الحل 3: فحص Flutter Console

**عند إضافة أداة من التطبيق:**

**افتح Flutter Console (Run/Debug):**

ابحث عن:
```
✅ تم إضافة الأداة بنجاح
```

أو:
```
❌ Error: ...
```

**إذا وجدت خطأ، أرسله لي!**

---

## 📊 Diagnostic Script

**شغّل هذا لفحص كل شيء:**

```bash
# في D:\fieldawy_store

# Test 1: Server يعمل؟
curl http://localhost:3000/api/notify/product-change -X POST -H "Content-Type: application/json" -d "{\"operation\":\"INSERT\",\"table\":\"distributor_surgical_tools\",\"product_name\":\"Test\",\"tab_name\":\"surgical\"}"

# Test 2: localtunnel يعمل؟
curl https://little-mice-ask.loca.lt/api/notify/product-change -X POST -H "Content-Type: application/json" -d "{\"operation\":\"INSERT\",\"table\":\"distributor_surgical_tools\",\"product_name\":\"Test\",\"tab_name\":\"surgical\"}"

# Test 3: FCM يعمل؟
node test_notification_direct.js
```

**إذا كل الاختبارات نجحت:** المشكلة في Supabase webhook

**إذا أحدها فشل:** المشكلة في ذلك الجزء

---

## 🎯 الخطوة التالية

**أخبرني:**

1. **عند الإضافة من التطبيق، هل تشاهد رسائل في Terminal (npm start)?**
   - نعم → ماذا تقول الرسائل؟
   - لا → لا شيء يظهر

2. **هل server + localtunnel لا يزالان يعملان؟**

3. **هل Webhook Logs في Supabase فارغة أو فيها entries؟**

وسأحل المشكلة بدقة! 🔍
