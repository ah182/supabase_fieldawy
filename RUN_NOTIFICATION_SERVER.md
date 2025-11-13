# تشغيل Server الإشعارات المخصصة

## الحل البسيط - بدون Legacy API! ✅

بدلاً من تفعيل Legacy API، نستخدم Node.js server محلي يشتغل على جهازك.

---

## الخطوات (3 دقائق):

### 1️⃣ تثبيت Dependencies:

```bash
cd D:\fieldawy_store

# إذا لم تكن مثبتة
npm install
```

### 2️⃣ تشغيل Server:

```bash
node notification_server.js
```

**النتيجة:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 Custom Notification Server
📡 Running on: http://localhost:3000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Endpoints:
  POST /send-custom-notification
  GET  /health
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3️⃣ اختبر Dashboard:

1. افتح **Web Admin Dashboard**
2. **Dashboard** tab → **Push Notification Manager**
3. اكتب العنوان والرسالة
4. اختر Target
5. اضغط **Send Notification**

**✅ سيصل الإشعار بالنص الذي كتبته!**

---

## كيف يعمل؟

```
Dashboard (Web) → Node.js Server (localhost:3000) → Firebase Admin SDK → FCM → الأجهزة
```

- ✅ لا يحتاج Legacy API
- ✅ لا يحتاج Edge Functions
- ✅ لا يحتاج Server Key
- ✅ يستخدم Service Account الموجود!

---

## للنشر على Production (اختياري):

### الخيار 1: Render.com (مجاني!)

1. سجل في https://render.com
2. New → Web Service
3. Connect GitHub repo
4. Build Command: `npm install`
5. Start Command: `node notification_server.js`
6. Deploy!

سيعطيك URL مثل: `https://fieldawy-notifications.onrender.com`

### الخيار 2: Railway.app (مجاني!)

1. سجل في https://railway.app
2. New Project → Deploy from GitHub
3. سيكتشف Node.js تلقائياً
4. Deploy!

### الخيار 3: Vercel (مجاني!)

لكن يحتاج تعديل بسيط للكود.

---

## تعديل URL للـ Production:

في `notification_manager_widget.dart`:

```dart
// للتجربة المحلية
final serverUrl = 'http://localhost:3000/send-custom-notification';

// للـ Production
final serverUrl = 'https://your-app.onrender.com/send-custom-notification';
```

---

## Troubleshooting:

### مشكلة: CORS Error في Web
**الحل:** Server مضبوط بالفعل مع `cors()` ✅

### مشكلة: Connection refused
**الحل:** تأكد أن server شغال:
```bash
curl http://localhost:3000/health
```

### مشكلة: Cannot find module 'cors'
**الحل:**
```bash
npm install cors
```

---

## اختبار Server مباشرة:

```bash
curl -X POST http://localhost:3000/send-custom-notification \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test",
    "message": "Hello from curl!",
    "tokens": ["test-token-123"]
  }'
```

---

## المميزات:

- ✅ يعمل فوراً بدون تعقيدات
- ✅ يستخدم Firebase Admin SDK (أحدث API)
- ✅ يدعم Batch requests (500 token/request)
- ✅ Logs واضحة في Console
- ✅ سهل النشر على أي Platform

---

## الخلاصة:

```bash
# شغل Server
node notification_server.js

# افتح Dashboard وجرب!
```

**🎉 الإشعارات ستعمل بالنص الذي تكتبه!**
