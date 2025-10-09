# ✅ إعداد Webhooks النهائي

## 🎉 النظام يعمل!

✅ FCM يرسل الإشعارات بنجاح
✅ التطبيق يستقبل الإشعارات
✅ Topic subscription يعمل

**الآن:** نحتاج فقط ربط Webhooks!

---

## 🚀 الخطوات النهائية

### 1️⃣ تأكد من تشغيل Server + Tunnel

**Terminal 1:**
```bash
cd D:\fieldawy_store
npm start
```

**Terminal 2:**
```bash
lt --port 3000
```

**احتفظ بالـ URL!** مثل:
```
https://random-name-abc123.loca.lt
```

---

### 2️⃣ إعداد Webhooks في Supabase

افتح **Supabase Dashboard** > **Database** > **Webhooks**

---

#### Webhook 1: Products

اضغط **Create a new hook**:

- **Name:** `products_notifications`
- **Schema:** `public`
- **Table:** `products`
- **Events:** 
  - ✅ Insert
  - ✅ Update
- **Type:** `HTTP Request`
- **Method:** `POST`
- **URL:** 
  ```
  https://your-url.loca.lt/api/notify/product-change
  ```
  (استبدل `your-url` بالـ URL الخاص بك)

- **HTTP Headers:**
  ```json
  {
    "Content-Type": "application/json"
  }
  ```

- **HTTP Params:** (اتركه فارغ)

- **Timeout:** `5000`

اضغط **Confirm** ✅

---

#### Webhook 2: Distributor Products

نفس الخطوات لكن:
- **Name:** `distributor_products_notifications`
- **Table:** `distributor_products`
- **URL:** نفس URL السابق

---

#### Webhook 3: Surgical Tools

- **Name:** `surgical_tools_notifications`
- **Table:** `surgical_tools`
- **URL:** نفس URL السابق

---

#### Webhook 4: Distributor Surgical Tools

- **Name:** `distributor_surgical_tools_notifications`
- **Table:** `distributor_surgical_tools`
- **URL:** نفس URL السابق

---

#### Webhook 5: Offers

- **Name:** `offers_notifications`
- **Table:** `offers`
- **URL:** نفس URL السابق

---

### 3️⃣ اختبار Webhooks

**في Supabase SQL Editor:**

```sql
-- اختبار 1: إضافة منتج
INSERT INTO products (name, company) 
VALUES ('Test Webhook Product', 'Test Co');
```

**يجب أن تشاهد:**

1. **في Terminal 1 (server):**
```
📩 تلقي webhook من Supabase
   Operation: INSERT
   Table: products
   Product Name: Test Webhook Product
   Tab Name: home
✅ تم إرسال الإشعار بنجاح!
```

2. **إشعار على جهازك:** 
```
تم إضافة Test Webhook Product في الرئيسية
```

---

## 🐛 إذا لم تشاهد رسائل في Terminal:

### السبب 1: Webhook URL خطأ

**تحقق:**
1. URL ينتهي بـ `/api/notify/product-change` ✅
2. URL يبدأ بـ `https://` ✅
3. localtunnel لا يزال يعمل ✅

---

### السبب 2: localtunnel يطلب verification

**الحل:**

1. افتح URL في المتصفح:
   ```
   https://your-url.loca.lt
   ```

2. اضغط **Click to Continue**

3. أدخل IP المعروض

4. الآن Webhooks ستعمل!

---

### السبب 3: Webhook معطّل

**التحقق:**

في **Supabase > Webhooks**:
- تأكد أن Status = **Enabled** ✅
- إذا كان Disabled، اضغط **Enable**

---

## 🧪 اختبارات شاملة

### Test 1: إضافة منتج عادي
```sql
INSERT INTO products (name, company) VALUES ('Panadol', 'GSK');
```
**المتوقع:** إشعار "تم إضافة Panadol في الرئيسية"

---

### Test 2: تحديث سعر
```sql
-- أضف منتج
INSERT INTO distributor_products (id, distributor_id, product_id, package, price)
VALUES ('test_price', (SELECT id FROM users LIMIT 1), (SELECT id FROM products LIMIT 1), 'Box', 100);

-- حدّث السعر
UPDATE distributor_products SET price = 150 WHERE id = 'test_price';
```
**المتوقع:** إشعار "تم تحديث منتج في تغيير السعر"

---

### Test 3: إضافة أداة جراحية
```sql
INSERT INTO surgical_tools (tool_name, company) VALUES ('Forceps', 'Medline');
```
**المتوقع:** إشعار "تم إضافة Forceps في الأدوات الجراحية والتشخيصية"

---

### Test 4: إضافة عرض
```sql
INSERT INTO offers (product_id, is_ocr, user_id, price, expiration_date, description)
VALUES ((SELECT id::text FROM products LIMIT 1), false, auth.uid(), 50, NOW() + INTERVAL '7 days', 'خصم 20%');
```
**المتوقع:** إشعار "تم إضافة خصم 20% في العروض"

---

## 📊 مراقبة Webhooks

### في Supabase Dashboard:

1. اذهب إلى **Database** > **Webhooks**
2. اضغط على أي webhook
3. اختر **Logs** tab
4. سترى:
   - ✅ **Success** (200): Webhook عمل بنجاح
   - ❌ **Failed** (4xx/5xx): هناك مشكلة

---

## ✅ الخلاصة

### ما يعمل الآن:
- ✅ Firebase Cloud Messaging
- ✅ Topic Notifications
- ✅ Notification Server
- ✅ التطبيق يستقبل الإشعارات

### ما نحتاج إعداده:
- ⏳ Supabase Database Webhooks (5 webhooks)

### بعد الإعداد:
- ✅ إضافة/تحديث أي منتج → إشعار تلقائي
- ✅ تحديث سعر → إشعار "تغيير السعر"
- ✅ منتج قرب الانتهاء → إشعار "قرب الانتهاء"
- ✅ إضافة عرض → إشعار "العروض"
- ✅ إضافة أداة جراحية → إشعار "الأدوات الجراحية"

---

## 🎯 خطوتك التالية

1. ✅ تأكد من أن server + tunnel يعملان
2. ✅ أضف 5 webhooks في Supabase
3. ✅ اختبر بـ:
   ```sql
   INSERT INTO products (name, company) VALUES ('Test', 'Test');
   ```
4. ✅ يجب أن يصلك إشعار! 🎉

---

**أخبرني عندما تنتهي من إضافة webhooks وسنختبر معاً! 🚀**
