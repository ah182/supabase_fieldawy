# 🚀 دليل سريع - إرسال إشعارات Firebase

## ✅ الملفات الموجودة بالفعل

- ✅ `fieldawy-store-app-66c0ffe5a54f.json` - Service Account (جاهز)
- ✅ `send_notification.js` - سكريبت إرسال الإشعارات
- ✅ `package.json` - تبعيات Node.js
- ✅ `.gitignore` محدّث (لحماية الملفات الحساسة)

## 🎯 3 خطوات فقط

### 1️⃣ ثبّت المكتبات
```bash
npm install
```

### 2️⃣ احصل على FCM Token
1. شغّل التطبيق
2. ابحث في console عن:
```
═══════════════════════════════════════════════════════════
🔑 FCM TOKEN للاختبار:
═══════════════════════════════════════════════════════════
[انسخ Token من هنا]
═══════════════════════════════════════════════════════════
```
3. افتح `send_notification.js` وضع Token مكان `PASTE_YOUR_FCM_TOKEN_HERE`

### 3️⃣ أرسل إشعار تجريبي
```bash
# إشعار عام (أزرق 🔵)
npm run send:general

# إشعار طلب (أخضر 🟢)
npm run send:order

# إشعار عرض (برتقالي 🟠)
npm run send:offer
```

---

## 📝 مثال على التعديل في send_notification.js

```javascript
// قبل:
const fcmToken = "PASTE_YOUR_FCM_TOKEN_HERE";

// بعد:
const fcmToken = "fDdrjhEKQa6aYpHgaLGmLw:APA91bFXJS...";
```

---

## 🎨 النتيجة المتوقعة

عند إرسال إشعار ناجح:
```
📤 جاري إرسال إشعار من نوع: order...
═══════════════════════════════════════════════════════════
✅ تم إرسال الإشعار بنجاح!
📊 Message ID: 1234567890
📱 النوع: order
📝 العنوان: طلب جديد 📦
📄 المحتوى: لديك طلب جديد رقم #12345 بقيمة 750 ريال
═══════════════════════════════════════════════════════════
```

---

## ❓ مشاكل شائعة

### Token لا يظهر في console
- تأكد أن التطبيق شغال على جهاز حقيقي أو محاكي فيه Google Play Services
- أعد تشغيل التطبيق

### npm: command not found
- ثبّت Node.js من [nodejs.org](https://nodejs.org/)

### فشل إرسال الإشعار
- تأكد من نسخ Token كاملاً
- تأكد أن التطبيق شغال في الخلفية أو مفتوح

---

📚 **للتفاصيل الكاملة:** راجع `FIREBASE_NOTIFICATIONS_GUIDE.md`
