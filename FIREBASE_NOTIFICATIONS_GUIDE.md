# دليل إرسال الإشعارات - Firebase Notifications

## 📋 خطوات الإعداد

### 1. Service Account (✅ موجود بالفعل)

الملف `fieldawy-store-app-66c0ffe5a54f.json` موجود بالفعل في المشروع ويحتوي على بيانات Service Account.

> ⚠️ **تنبيه مهم:** لا تنشر هذا الملف على GitHub أو أي مكان عام!
> 
> لحماية المشروع، أضف الملف في `.gitignore`:
> ```
> fieldawy-store-app-*.json
> *.json
> ```

إذا احتجت إنشاء Service Account جديد:
1. افتح [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `fieldawy-store-app`
3. اضغط على ⚙️ **Project Settings** > **Service accounts**
4. اضغط **Generate new private key**
5. احفظ الملف في مجلد المشروع

### 2. الحصول على FCM Token

1. شغّل التطبيق على جهاز حقيقي أو محاكي
2. ابحث في console عن:
```
═══════════════════════════════════════════════════════════
🔑 FCM TOKEN للاختبار:
═══════════════════════════════════════════════════════════
[FCM TOKEN هنا]
═══════════════════════════════════════════════════════════
```
3. انسخ الـ Token واستبدله في `send_notification.js`

### 3. تثبيت المكتبات المطلوبة

افتح terminal في مجلد المشروع واكتب:

```bash
npm install
```

هذا سيثبت `firebase-admin` الذي يستخدم Service Account للمصادقة.

## 🚀 إرسال الإشعارات

### الطريقة الأولى - باستخدام npm scripts:

```bash
# إشعار عام
npm run send:general

# إشعار طلب جديد
npm run send:order

# إشعار عرض خاص
npm run send:offer
```

### الطريقة الثانية - مباشرة:

```bash
# إشعار عام
node send_notification.js general

# إشعار طلب
node send_notification.js order

# إشعار عرض
node send_notification.js offer
```

## 📱 أنواع الإشعارات

### 1. إشعار طلب جديد (Order)
- **اللون:** 🟢 أخضر
- **القناة:** orders_channel
- **الاستخدام:** عند إضافة طلب جديد

### 2. إشعار عرض خاص (Offer)
- **اللون:** 🟠 برتقالي
- **القناة:** offers_channel
- **الاستخدام:** للعروض والتخفيضات

### 3. إشعار عام (General)
- **اللون:** 🔵 أزرق
- **القناة:** general_channel
- **الاستخدام:** إشعارات عامة ورسائل إدارية

## 🔧 تخصيص الإشعارات

لإضافة نوع جديد من الإشعارات، عدّل ملف `send_notification.js`:

```javascript
const notificationTemplates = {
  // ... الأنواع الموجودة
  
  your_type: {
    notification: {
      title: "عنوان الإشعار",
      body: "محتوى الإشعار",
      sound: "default",
    },
    data: {
      type: "your_type",
      screen: "target_screen",
      custom_field: "custom_value",
    },
  },
};
```

## 🧪 اختبار من Firebase Console

يمكنك أيضاً إرسال إشعارات من Firebase Console مباشرة:

1. افتح Firebase Console > **Cloud Messaging**
2. اضغط **Send your first message**
3. املأ البيانات:
   - **Notification title:** عنوان الإشعار
   - **Notification text:** المحتوى
4. في **Target**، اختر **Single device**
5. الصق FCM Token
6. في **Additional options** > **Custom data**، أضف:
   - Key: `type`, Value: `order` أو `offer` أو `general`
   - Key: `screen`, Value: `orders` أو `offers` أو `home`

## 📊 نتائج الإرسال

### نجاح الإرسال:
```json
{
  "multicast_id": 1234567890,
  "success": 1,
  "failure": 0,
  "canonical_ids": 0,
  "results": [
    {
      "message_id": "0:1234567890"
    }
  ]
}
```

### فشل الإرسال:
```json
{
  "multicast_id": 1234567890,
  "success": 0,
  "failure": 1,
  "results": [
    {
      "error": "InvalidRegistration"
    }
  ]
}
```

## ❓ حل المشاكل الشائعة

### المشكلة: Token غير صحيح
**الحل:** تأكد من نسخ Token كاملاً من console التطبيق

### المشكلة: Service Account غير صحيح
**الحل:** تأكد من وجود ملف `fieldawy-store-app-66c0ffe5a54f.json` في نفس مجلد `send_notification.js`

### المشكلة: الإشعار لا يظهر
**الحل:** 
- تأكد من تفعيل الإشعارات على الجهاز
- تحقق من أن التطبيق ليس في Doze Mode
- على Android 13+، تأكد من منح إذن POST_NOTIFICATIONS

### المشكلة: Module not found 'node-fetch'
**الحل:** نفذ `npm install` في مجلد المشروع

## 🔐 الأمان

- ⚠️ **مهم جداً:** لا تنشر ملف Service Account على GitHub أو أي مكان عام
- 🔒 أضف `*.json` و `fieldawy-store-app-*.json` في `.gitignore`
- 🛡️ هذا المشروع يستخدم Firebase Admin SDK v2 (أحدث وأكثر أماناً من Legacy API)

## 📚 مصادر إضافية

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Messaging Flutter](https://pub.dev/packages/firebase_messaging)
