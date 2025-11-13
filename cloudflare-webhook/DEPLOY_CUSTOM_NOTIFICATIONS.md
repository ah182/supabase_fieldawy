# نشر الإشعارات المخصصة على Cloudflare Worker

## ✅ تم إضافة Endpoint جديد!

تم إضافة `/send-custom-notification` لـ Cloudflare Worker الموجود.

---

## 🚀 النشر (دقيقتين):

### 1️⃣ نشر التحديثات:

```bash
cd D:\fieldawy_store\cloudflare-webhook

# نشر Worker
npm run deploy

# أو
wrangler publish
```

### 2️⃣ احصل على Worker URL:

بعد النشر، سيظهر لك URL مثل:
```
https://fieldawy-notifications.YOUR_ACCOUNT.workers.dev
```

أو إذا كان لديك Custom Domain:
```
https://notifications.yourdomain.com
```

### 3️⃣ تحديث Dashboard:

في `notification_manager_widget.dart`، عدّل السطر:

```dart
// غيّر هذا:
final serverUrl = 'https://fieldawy-notifications.YOUR_ACCOUNT.workers.dev/send-custom-notification';

// بالـ URL الحقيقي
final serverUrl = 'https://YOUR_ACTUAL_WORKER_URL/send-custom-notification';
```

### 4️⃣ اختبر الآن:

1. **Build Web Dashboard:**
   ```bash
   flutter build web --release
   ```

2. **افتح Dashboard** وجرب إرسال إشعار!

---

## 📋 Endpoints المتاحة:

| Endpoint | Method | الوظيفة |
|---------|---------|---------|
| `/` | POST | Webhook من Supabase (إشعارات تلقائية) |
| `/send-custom-notification` | POST | إشعارات مخصصة من Dashboard |
| `/health` | GET | Health check |

---

## 🧪 اختبار Endpoint:

```bash
curl -X POST https://YOUR_WORKER_URL/send-custom-notification \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test",
    "message": "Hello from Cloudflare!",
    "tokens": ["test-token-123"]
  }'
```

**النتيجة المتوقعة:**
```json
{
  "success": 0,
  "failure": 1,
  "total": 1
}
```

---

## 🔧 معلومات تقنية:

### كيف يعمل؟

```
Dashboard (Web)
    ↓ POST /send-custom-notification
Cloudflare Worker
    ↓ Get Firebase Access Token
Firebase FCM HTTP v1 API
    ↓
📱 أجهزة المستخدمين (batch: 500 at a time)
```

### المميزات:

- ✅ **عالمي:** يعمل من أي مكان
- ✅ **سريع:** Cloudflare Edge Network
- ✅ **مجاني:** ضمن Free Tier (100k requests/day)
- ✅ **آمن:** CORS مضبوط + HTTPS
- ✅ **Batch Support:** 500 token في المرة
- ✅ **نفس Worker:** مع إشعارات المنتجات

---

## 📊 Logs (في Cloudflare Dashboard):

```
📤 Sending custom notification to 25 devices
📝 Title: عرض خاص
📄 Message: خصم 50%
  Batch 1: ✅ 23 ❌ 2
✅ Success: 23, ❌ Failed: 2
```

---

## 🔐 Environment Variables المطلوبة:

تأكد من وجود هذه في Cloudflare Worker:

```bash
# في Cloudflare Dashboard → Workers → Settings → Variables
FIREBASE_SERVICE_ACCOUNT = { "type": "service_account", ... }
```

(موجودة بالفعل من setup السابق) ✅

---

## 💰 التكلفة:

### Cloudflare Workers Free Tier:
- ✅ **100,000 requests/day** مجاناً
- ✅ **10ms CPU time/request**
- ✅ **Unlimited outbound requests**

### إذا أرسلت 1000 إشعار/يوم:
```
1000 إشعار ÷ 500 (batch) = 2 requests
Cost: $0.00 (مجاني!)
```

---

## 🎯 الخلاصة:

```bash
# خطوة واحدة فقط:
cd cloudflare-webhook
npm run deploy
```

**ثم عدّل URL في Dashboard وخلاص! 🎉**

---

## ملاحظات:

- ✅ Worker شغال بالفعل للإشعارات التلقائية
- ✅ أضفنا endpoint جديد فقط
- ✅ لا يحتاج server محلي
- ✅ يعمل من أي مكان في العالم!

**جاهز للنشر! 🚀**
