# اختبار الإشعارات المخصصة

## ✅ تم التعديل!

تم إصلاح URL في Dashboard ليشمل `/send-custom-notification`

---

## 🚀 خطوات النشر (دقيقة واحدة):

### 1️⃣ نشر Cloudflare Worker:

**Option A: استخدام .bat file**
```bash
# اضغط دبل كليك على:
cloudflare-webhook\DEPLOY_NOW.bat
```

**Option B: من Terminal**
```bash
cd D:\fieldawy_store\cloudflare-webhook
wrangler publish
```

---

### 2️⃣ اختبار Worker:

```bash
# Health check
curl https://notification-webhook.ah3181997-1e7.workers.dev/health
```

**يجب أن ترى:**
```json
{"status":"ok","service":"fieldawy-notifications"}
```

---

### 3️⃣ اختبار الإشعارات:

```bash
curl -X POST https://notification-webhook.ah3181997-1e7.workers.dev/send-custom-notification ^
  -H "Content-Type: application/json" ^
  -d "{\"title\":\"Test\",\"message\":\"Hello!\",\"tokens\":[\"test-token\"]}"
```

**يجب أن ترى:**
```json
{"success":0,"failure":1,"total":1}
```
(failure=1 لأن test-token غير حقيقي)

---

### 4️⃣ اختبار من Dashboard:

1. افتح **Web Admin Dashboard**
2. **Dashboard** tab → **Push Notification Manager**
3. اكتب:
   - Title: "اختبار"
   - Message: "هذا اختبار للإشعارات المخصصة"
   - Target: All Users
4. اضغط **Send Notification**

**✅ يجب أن ترى:**
```
✅ Notification sent! ✅ X sent, ❌ Y failed
```

---

## 🐛 Troubleshooting:

### مشكلة: "No record in payload"

**السبب:** URL لا يحتوي على `/send-custom-notification`

**الحل:** ✅ تم إصلاحه! تأكد من:
```dart
final serverUrl = 'https://notification-webhook.ah3181997-1e7.workers.dev/send-custom-notification';
//                                                                         ^^^^^^^^^^^^^^^^^^^^^^^^
//                                                                         مهم جداً!
```

---

### مشكلة: "FIREBASE_SERVICE_ACCOUNT not configured"

**الحل:** أضف Service Account في Cloudflare:
```bash
wrangler secret put FIREBASE_SERVICE_ACCOUNT
# الصق محتوى ملف fieldawy-store-app-66c0ffe5a54f.json
```

---

### مشكلة: "Failed to get access token"

**الحل:** تأكد من Service Account صحيح:
```bash
# اعرض secrets
wrangler secret list

# يجب أن ترى:
# FIREBASE_SERVICE_ACCOUNT
```

---

## 📊 الـ Logs:

### في Cloudflare Dashboard:

1. افتح https://dash.cloudflare.com
2. Workers & Pages
3. notification-webhook
4. Logs

**سترى:**
```
📤 Sending custom notification to 25 devices
📝 Title: اختبار
📄 Message: هذا اختبار
  Batch 1: ✅ 23 ❌ 2
✅ Success: 23, ❌ Failed: 2
```

---

## ✅ الخلاصة:

```bash
# خطوة واحدة فقط:
cd cloudflare-webhook
wrangler publish

# ثم جرب من Dashboard!
```

**🎉 الإشعارات ستعمل بالنص المخصص!**
