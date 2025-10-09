# 🔍 تصحيح: الإشعارات لا تظهر

## ✅ الفحوصات الأساسية

### 1️⃣ التحقق من Notification Server

**في Terminal 1 (حيث npm start يعمل):**

هل تشاهد رسائل مثل هذه؟
```
📩 تلقي webhook من Supabase
   Operation: INSERT
   Table: products
```

- ✅ **نعم:** Server يستقبل webhooks
- ❌ **لا:** Webhooks لا تصل للـ server (راجع الخطوة 2)

---

### 2️⃣ التحقق من Webhook URL

**في Supabase Dashboard > Database > Webhooks:**

تحقق من URL:
```
✅ صحيح: https://random-name.loca.lt/api/notify/product-change
❌ خطأ: https://random-name.loca.lt (بدون /api/notify/product-change)
```

---

### 3️⃣ التحقق من FCM Tokens

**في Supabase SQL Editor:**

```sql
SELECT COUNT(*) as token_count FROM user_tokens;
```

**النتيجة:**
- ✅ **أكثر من 0:** يوجد tokens
- ❌ **0:** لا توجد tokens (راجع الخطوة 4)

---

### 4️⃣ التحقق من Topic Subscription

**في Flutter Console (عند فتح التطبيق):**

يجب أن تشاهد:
```
✅ تم الاشتراك في topic: all_users
```

- ✅ **موجود:** التطبيق مشترك
- ❌ **غير موجود:** راجع الخطوة 5

---

### 5️⃣ التحقق من Firebase Service Account

**ملف:** `fieldawy-store-app-66c0ffe5a54f.json`

تحقق من:
- ✅ الملف موجود في المجلد الرئيسي
- ✅ الملف يحتوي على `project_id`
- ✅ الملف يحتوي على `private_key`

---

## 🔧 الحلول حسب المشكلة

### مشكلة 1: Server لا يستقبل webhooks

**الحل:**

#### أ) اختبر localtunnel يدوياً:

```bash
curl https://your-url.loca.lt/api/notify/product-change \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"operation":"INSERT","table":"products","product_name":"Test","tab_name":"home"}'
```

إذا عمل، المشكلة في Supabase webhooks.

#### ب) تحقق من Supabase Webhook Logs:

1. اذهب إلى **Database** > **Webhooks**
2. اضغط على webhook
3. اختر **Logs**
4. افحص الأخطاء

---

### مشكلة 2: لا توجد FCM Tokens

**السبب:** لم يتم حفظ token بعد تسجيل الدخول.

**الحل:**

#### أ) سجّل خروج ثم دخول مرة أخرى:

في التطبيق:
1. سجّل خروج
2. سجّل دخول
3. افحص Console للرسائل:
   ```
   🔐 تم تسجيل الدخول - جاري حفظ FCM Token...
   ✅ تم حفظ FCM Token في Supabase بنجاح
   ```

#### ب) تحقق من حفظ Token:

```sql
SELECT * FROM user_tokens ORDER BY created_at DESC LIMIT 1;
```

يجب أن تشاهد:
- `token`: FCM token طويل
- `device_type`: Android
- `device_name`: اسم جهازك

---

### مشكلة 3: Server يستقبل لكن لا يُرسل

**افحص Console للأخطاء:**

```
❌ خطأ في إرسال الإشعار: ...
```

**الأخطاء الشائعة:**

#### خطأ 1: "Invalid token"
```
❌ خطأ في إرسال الإشعار: Requested entity was not found
```

**الحل:** Token قديم أو غير صالح
```sql
-- احذف tokens القديمة
DELETE FROM user_tokens WHERE updated_at < NOW() - INTERVAL '30 days';
```

#### خطأ 2: "Service account error"
```
❌ خطأ: Could not load the default credentials
```

**الحل:** تحقق من ملف service account

---

### مشكلة 4: الإشعارات تُرسل لكن لا تظهر

**الأسباب المحتملة:**

#### أ) التطبيق ليس مشترك في topic

**الحل:**

في `lib/main.dart`، تأكد من:
```dart
await FirebaseMessaging.instance.subscribeToTopic('all_users');
print('✅ تم الاشتراك في topic: all_users');
```

#### ب) Notification Channels غير مُعدّة

**الحل:** أعد تشغيل التطبيق (Hot Restart)

---

## 🧪 اختبار شامل

### Test 1: اختبار Server محلياً

```bash
# في terminal
curl http://localhost:3000/api/notify/product-change \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"operation":"INSERT","table":"products","product_name":"Test","tab_name":"home"}'
```

**النتيجة المتوقعة:**
```json
{"success":true,"message":"Notification sent"}
```

---

### Test 2: إرسال يدوي عبر topic

```bash
npm run topic:general
```

**النتيجة المتوقعة:**
- ✅ إشعار يظهر على جميع الأجهزة المشتركة في `all_users`

---

### Test 3: إرسال عبر Supabase script

```bash
npm run supabase:all:general
```

**النتيجة المتوقعة:**
- ✅ يجلب tokens من Supabase
- ✅ يُرسل لكل token

---

## 📊 Checklist كامل

قبل أن تعمل الإشعارات، تأكد من:

### Backend:
- [ ] ✅ `npm start` يعمل بدون أخطاء
- [ ] ✅ `lt --port 3000` يعمل ويعطي URL
- [ ] ✅ Supabase webhooks مُعدّة صح
- [ ] ✅ Service account file موجود

### Database:
- [ ] ✅ `SELECT COUNT(*) FROM user_tokens;` أكثر من 0
- [ ] ✅ Tokens حديثة (created_at قريب)

### Flutter App:
- [ ] ✅ Firebase initialized
- [ ] ✅ Topic subscription: `all_users`
- [ ] ✅ Notification channels created
- [ ] ✅ FCMTokenService يحفظ token عند تسجيل الدخول

### Testing:
- [ ] ✅ `curl localhost:3000/...` يعمل
- [ ] ✅ `npm run topic:general` يُرسل إشعار
- [ ] ✅ إضافة منتج في Supabase يُرسل webhook

---

## 🎯 السيناريو الكامل (خطوة بخطوة)

### 1. تشغيل Server:
```bash
cd D:\fieldawy_store
npm start
```

### 2. تشغيل Tunnel:
```bash
# في terminal جديد
lt --port 3000
```

### 3. نسخ URL وتحديث Webhooks في Supabase

### 4. في التطبيق:
- سجّل دخول
- انتظر حتى تشاهد في console:
  ```
  ✅ تم حفظ FCM Token في Supabase بنجاح
  ✅ تم الاشتراك في topic: all_users
  ```

### 5. اختبار:
```bash
npm run topic:general
```

**يجب أن يظهر إشعار!** 🎉

### 6. إذا ظهر إشعار في الخطوة 5:
```sql
-- اختبر webhook
INSERT INTO products (name, company) VALUES ('Test', 'Test Co');
```

**يجب أن يظهر إشعار!** 🎉

---

## 🆘 إذا ما زال لا يعمل

**أرسل لي:**

1. **Console output من server:**
```
📩 تلقي webhook...
```

2. **نتيجة:**
```sql
SELECT COUNT(*) FROM user_tokens;
```

3. **نتيجة:**
```bash
npm run topic:general
```

4. **Flutter console عند تسجيل الدخول**

وسأساعدك! 🚀
