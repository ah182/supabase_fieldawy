# 🔔 دليل إعداد الإشعارات التلقائية للمنتجات

## ✅ ما تم إنجازه

### 1. **Database Triggers** ✅
- إنشاء triggers على جميع جداول المنتجات
- إرسال إشعار تلقائي عند INSERT أو UPDATE

### 2. **Notification Webhook Server** ✅
- سيرفر Node.js لاستقبال الإشعارات من Supabase
- إرسال تلقائي عبر Firebase Cloud Messaging

### 3. **Flutter Navigation** ✅
- معالجة النقر على الإشعار
- الانتقال للتاب المناسب

---

## 🚀 خطوات التشغيل

### 1️⃣ تطبيق SQL Migration

افتح **Supabase Dashboard > SQL Editor**:

```sql
-- انسخ والصق محتوى:
supabase/migrations/20250120_add_product_notification_triggers.sql
```

اضغط **Run** ✅

---

### 2️⃣ تشغيل Notification Server

```bash
cd D:\fieldawy_store

# تشغيل السيرفر
npm start
```

**يجب أن تشاهد:**
```
🚀 Notification webhook server is running on port 3000
📡 Endpoint: http://localhost:3000/api/notify/product-change
```

---

### 3️⃣ اختبار الإشعارات

#### أ) إضافة منتج جديد:

في **Supabase Dashboard > Table Editor**:

```sql
-- مثال: إضافة أداة جراحية جديدة
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Forceps Surgical', 'Medline');
```

**يجب أن يحدث:**
1. ✅ Trigger يرسل notification إلى السيرفر
2. ✅ السيرفر يرسل FCM notification لجميع المستخدمين
3. ✅ يظهر إشعار على جميع الأجهزة: "تم إضافة Forceps Surgical في الأدوات الجراحية"
4. ✅ عند النقر، يفتح تاب الأدوات الجراحية

---

## 📊 الجداول المدعومة

| الجدول | التاب المستهدف | مثال |
|--------|----------------|------|
| `surgical_tools` | Surgical & Diagnostic | أدوات جراحية |
| `distributor_surgical_tools` | Surgical & Diagnostic | أدوات جراحية |
| `distributor_ocr_products` (expiry_date < 60 days) | Expire Soon | منتجات قرب الانتهاء |
| `distributor_ocr_products` (price changed) | Price Action | تغيير السعر |
| `offers` | Offers | عروض |
| `products` | Home | منتجات عامة |

---

## 🔧 تخصيص الإشعارات

### تعديل رسالة الإشعار:

في `notification_webhook_server.js`:

```javascript
const title = `${action} منتج جديد! 🎉`;
const body = `${productName} في تبويب ${tabName}`;
```

### تعديل نوع القناة:

```javascript
let channelId = 'general_channel';
if (type == 'product_update') {
  channelId = 'general_channel';  // أو offers_channel حسب الحاجة
}
```

---

## 🧪 اختبار شامل

### السيناريو 1: إضافة أداة جراحية

```sql
INSERT INTO surgical_tools (tool_name, company, image_url)
VALUES ('Scalpel Blade', 'BD Medical', 'https://example.com/image.jpg');
```

**النتيجة المتوقعة:**
- ✅ إشعار: "تم إضافة Scalpel Blade في الأدوات الجراحية والتشخيصية"
- ✅ Navigation إلى Tab 3 (Surgical)

---

### السيناريو 2: إضافة منتج قرب الانتهاء

```sql
INSERT INTO distributor_ocr_products (
  distributor_id,
  ocr_product_id,
  product_name,
  price,
  expiration_date
) VALUES (
  'your-distributor-uuid',
  'product-uuid',
  'Aspirin 100mg',
  50.00,
  NOW() + INTERVAL '30 days'  -- ينتهي بعد 30 يوم
);
```

**النتيجة المتوقعة:**
- ✅ إشعار: "تم إضافة Aspirin 100mg في قرب الانتهاء"
- ✅ Navigation إلى Tab 2 (Expire Soon)

---

### السيناريو 3: إضافة عرض

```sql
INSERT INTO offers (
  product_name,
  title,
  discount_percentage
) VALUES (
  'Panadol Extra',
  'خصم 20%',
  20
);
```

**النتيجة المتوقعة:**
- ✅ إشعار: "تم إضافة Panadol Extra في العروض"
- ✅ Navigation إلى Tab 4 (Offers)

---

## 📱 مثال على الإشعار

**العنوان:** `تم إضافة منتج جديد! 🎉`

**المحتوى:** `Forceps Surgical في تبويب الأدوات الجراحية والتشخيصية`

**عند النقر:** يفتح التطبيق على تاب الأدوات الجراحية مباشرةً

---

## 🐛 Troubleshooting

### مشكلة: الإشعارات لا تظهر

**الحل:**

1. **تحقق من السيرفر:**
```bash
# هل السيرفر يعمل؟
curl http://localhost:3000/api/notify/product-change
```

2. **تحقق من Triggers:**
```sql
-- عرض جميع triggers
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name LIKE 'trigger_notify%';
```

يجب أن تشاهد 7 triggers!

3. **تحقق من FCM Tokens:**
```sql
SELECT COUNT(*) FROM user_tokens;
```

إذا كان 0، لم يسجل أحد دخول بعد.

4. **تحقق من Topic Subscription:**
في Flutter console، يجب أن تشاهد:
```
✅ تم الاشتراك في topic: all_users
```

---

### مشكلة: Navigation لا يعمل

**الحل:**

تأكد من أن `navigatorKey` موجود في MaterialApp:

```dart
return MaterialApp(
  navigatorKey: navigatorKey,  // ✅ مهم!
  // ...
);
```

---

### مشكلة: BottomNavBar لا يقبل initialIndex

**الحل:**

إذا كانت BottomNavBar لا تدعم initialIndex، استخدم بديل:

```dart
// بدلاً من:
BottomNavBar(initialIndex: tabIndex)

// استخدم:
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => HomeScreen(initialTabIndex: tabIndex),
  ),
);
```

أو عدّل BottomNavBar لإضافة initialIndex parameter.

---

## 📊 مراقبة الإشعارات

### عرض سجل الإشعارات:

```sql
SELECT * FROM notification_logs
ORDER BY sent_at DESC
LIMIT 10;
```

### إحصائيات الإشعارات:

```sql
SELECT * FROM notification_stats;
```

---

## 🔒 الأمان

### في Production:

1. **استخدم Supabase Edge Functions بدلاً من pg_notify**
2. **أضف authentication للـ webhook endpoint**
3. **استخدم HTTPS**
4. **أضف rate limiting**

مثال:

```javascript
app.post("/api/notify/product-change", authenticateRequest, async (req, res) => {
  // معالجة الإشعار
});
```

---

## 📚 الملفات ذات الصلة

- `supabase/migrations/20250120_add_product_notification_triggers.sql` - Database triggers
- `notification_webhook_server.js` - Webhook server
- `lib/main.dart` - Flutter navigation handling
- `lib/services/fcm_token_service.dart` - FCM token management
- `send_notification_supabase.js` - إرسال يدوي للإشعارات

---

## ✅ الملخص

1. ✅ Database triggers تُرسل إشعار تلقائي عند insert/update
2. ✅ Webhook server يستقبل ويرسل عبر FCM
3. ✅ Flutter يعرض الإشعار ويتعامل مع Navigation
4. ✅ جميع المستخدمين يستقبلون الإشعار عبر `all_users` topic
5. ✅ النقر على الإشعار ينقل للتاب الصحيح

**كل شيء جاهز للاختبار! 🚀**
