# تشخيص مشكلة وصول الإشعارات لكل المستخدمين

## المشكلة
الإشعار بيوصل للموزع اللي باعته بس، مش بيوصل لباقي المستخدمين.

## خطوات التشخيص

### 1. تأكد من اشتراك المستخدمين في Topic
على كل جهاز مستخدم، شغل التطبيق وافتح logcat:
```bash
adb logcat | grep "all_users"
```

لازم تشوف:
```
✅ تم الاشتراك في topic: all_users
```

### 2. تأكد من FCM Tokens
على كل جهاز، لازم يظهر:
```
🔑 FCM TOKEN للاختبار:
[token هنا]
✅ تم الحصول على FCM Token بنجاح
```

### 3. اختبر إرسال إشعار لكل المستخدمين

#### الطريقة 1: من خلال Firebase Console
1. روح Firebase Console → Cloud Messaging
2. اختار "Send test message"
3. في Topic اكتب: `all_users`
4. اكتب رسالة اختبارية
5. اضغط Send

**النتيجة المتوقعة:** كل الأجهزة المشتركة في `all_users` لازم تستقبل الإشعار.

#### الطريقة 2: اختبار من Node.js
استخدم السكريبت ده:

```javascript
// test_topic_notification.js
const admin = require('firebase-admin');
const serviceAccount = require('./fieldawy-store-app-66c0ffe5a54f.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function sendTestNotification() {
  const message = {
    notification: {
      title: '🧪 Test Notification',
      body: 'هذا إشعار تجريبي لكل المستخدمين'
    },
    data: {
      screen: 'home',
      type: 'test'
    },
    topic: 'all_users'
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('✅ تم إرسال الإشعار بنجاح:', response);
  } catch (error) {
    console.error('❌ فشل إرسال الإشعار:', error);
  }
}

sendTestNotification();
```

شغله:
```bash
node test_topic_notification.js
```

### 4. فحص Background Handler
على كل جهاز، لما يجي إشعار والتطبيق مقفول، لازم يظهر في logs:
```
📋 Background notification check:
   User ID: [user-id]
   Distributor ID: None/[id]
📩 إشعار في الخلفية:
   العنوان: [title]
   المحتوى: [body]
```

### 5. فحص Notification Preferences
على جهاز أي مستخدم، شغل ده في debug console:
```dart
final prefs = await NotificationPreferencesService.getPreferences();
print('Notification Preferences: $prefs');
```

لازم يطلع:
```dart
{
  price_action: true,
  expire_soon: true,
  offers: true,
  surgical_tools: true
}
```

## الأسباب المحتملة

### 1. المستخدمين مش مشتركين في Topic
**الحل:** تأكد إن كل مستخدم لما يفتح التطبيق، بيشترك تلقائياً في `all_users`.

### 2. FCM Tokens مش متحفظة
**الحل:** تأكد إن الـ tokens بتتحفظ في Supabase في جدول `user_tokens`.

تقدر تفحص من Supabase Dashboard:
```sql
SELECT * FROM user_tokens WHERE token IS NOT NULL;
```

### 3. الإعدادات معطلة عند بعض المستخدمين
**الحل:** فحص `notification_preferences` table:
```sql
SELECT * FROM notification_preferences;
```

### 4. التطبيق مش شغال في Background
**التأكد:** الأجهزة التانية لازم يكون التطبيق شغال (foreground أو background).

### 5. مشكلة في الـ Cloudflare Worker
**الفحص:** شوف logs الـ Worker:
- روح Cloudflare Dashboard → Workers → notification-webhook
- شوف Logs
- لازم يظهر:
```
✅ FCM message sent successfully
```

## الحل المقترح

إذا كانت المشكلة إن الموزع بيستقبل إشعار نفسه، ممكن نضيف filter:

```dart
// في _shouldShowNotification
if (distributorId != null) {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  if (currentUserId == distributorId) {
    // Don't show notification to the distributor who sent it
    print('⏭️ تخطي إشعار - المرسل هو المستقبل');
    return false;
  }
}
```

## اختبار نهائي

1. افتح التطبيق على 3 أجهزة مختلفة (أو استخدم emulators)
2. سجل دخول بحسابات مختلفة على كل جهاز
3. من جهاز واحد (موزع)، أضف منتج جديد
4. شوف لو الإشعار وصل للجهازين التانيين

**النتيجة المتوقعة:** كل الأجهزة تستقبل الإشعار (حتى الموزع اللي باعته - إلا لو عملنا filter).
