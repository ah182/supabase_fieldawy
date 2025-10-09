# 🚀 نشر على Render - خطوة بخطوة

## 📋 المتطلبات

- حساب GitHub (لو مش موجود هنعمله)
- الكود الحالي (عندك بالفعل ✅)

---

## الخطوة 1: تجهيز الملفات (5 دقائق)

### 1.1 إنشاء ملف `.gitignore`

**افتح:** `D:\fieldawy_store\.gitignore`

**إذا موجود، تأكد أنه يحتوي على:**
```
node_modules/
.env
*.log
.DS_Store
fieldawy-store-app-66c0ffe5a54f.json
```

**إذا غير موجود، أنشئه!**

---

### 1.2 تعديل `package.json`

**افتح:** `D:\fieldawy_store\package.json`

**تأكد من وجود:**
```json
{
  "name": "fieldawy-store-notifications",
  "version": "1.0.0",
  "type": "module",
  "main": "notification_webhook_server.js",
  "scripts": {
    "start": "node notification_webhook_server.js"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "@supabase/supabase-js": "^2.39.0",
    "express": "^4.18.2"
  }
}
```

---

### 1.3 تعديل `notification_webhook_server.js`

**افتح:** `D:\fieldawy_store\notification_webhook_server.js`

**في آخر السطر حيث:**
```javascript
const PORT = process.env.PORT || 3000;
```

**تأكد أنه كذا بالضبط!** ✅

---

## الخطوة 2: رفع الكود على GitHub (10 دقائق)

### 2.1 إنشاء Repository على GitHub

**1. اذهب إلى:** https://github.com

**2. سجّل دخول (أو أنشئ حساب)**

**3. اضغط على `+` في الأعلى**

**4. اختر `New repository`**

**5. املأ البيانات:**
```
Repository name: fieldawy-store-notifications
Description: Notification server for Fieldawy Store
Privacy: Private ✅ (مهم!)
```

**6. اضغط `Create repository`**

---

### 2.2 رفع الكود

**افتح Command Prompt في مجلد المشروع:**

```bash
cd D:\fieldawy_store
```

**نفّذ هذه الأوامر واحدة تلو الأخرى:**

```bash
# 1. تهيئة Git
git init

# 2. إضافة remote
git remote add origin https://github.com/YOUR_USERNAME/fieldawy-store-notifications.git
# استبدل YOUR_USERNAME باسمك على GitHub!

# 3. إضافة الملفات
git add package.json
git add notification_webhook_server.js
git add fieldawy-store-app-66c0ffe5a54f.json

# 4. عمل commit
git commit -m "Initial commit - notification server"

# 5. رفع الكود
git branch -M main
git push -u origin main
```

**إذا طلب username/password:**
- Username: اسمك على GitHub
- Password: **Personal Access Token** (ليس كلمة المرور!)

**للحصول على Token:**
1. GitHub > Settings > Developer settings
2. Personal access tokens > Tokens (classic)
3. Generate new token
4. اختر `repo` scope
5. انسخ الـ token واستخدمه كـ password

---

## الخطوة 3: إنشاء حساب على Render (3 دقائق)

**1. اذهب إلى:** https://render.com

**2. اضغط `Get Started`**

**3. سجّل دخول بـ GitHub:**
- اضغط `Sign in with GitHub`
- وافق على الأذونات

✅ **تم إنشاء الحساب!**

---

## الخطوة 4: نشر التطبيق (5 دقائق)

### 4.1 إنشاء Web Service

**1. في Render Dashboard، اضغط `New +`**

**2. اختر `Web Service`**

**3. ربط GitHub:**
- إذا أول مرة، اضغط `Connect GitHub`
- وافق على الأذونات

**4. اختر Repository:**
- ابحث عن `fieldawy-store-notifications`
- اضغط `Connect`

---

### 4.2 إعدادات النشر

**املأ البيانات:**

```
Name: fieldawy-notifications
Region: Frankfurt (EU Central) ← الأقرب
Branch: main
Runtime: Node
Build Command: npm install
Start Command: npm start
```

**Plan:**
- اختر **Free** ✅

---

### 4.3 Environment Variables (مهم جداً!)

**اضغط `Advanced`**

**أضف Environment Variable:**

**الخيار 1: رفع Service Account كـ Environment Variable (موصى به)**

```
Key: FIREBASE_SERVICE_ACCOUNT
Value: [انسخ محتوى fieldawy-store-app-66c0ffe5a54f.json كله هنا]
```

**ثم عدّل `notification_webhook_server.js`:**

```javascript
// في البداية، استبدل:
const serviceAccount = JSON.parse(
  readFileSync("./fieldawy-store-app-66c0ffe5a54f.json", "utf8")
);

// بهذا:
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT 
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  : JSON.parse(readFileSync("./fieldawy-store-app-66c0ffe5a54f.json", "utf8"));
```

---

**الخيار 2: رفع الملف مع الكود (أسهل لكن أقل أماناً)**

**لا تحتاج Environment Variable، لكن:**
- تأكد أن Repository على GitHub **Private** ✅

---

### 4.4 إطلاق النشر

**اضغط `Create Web Service`**

**انتظر 2-3 دقائق...**

**ستشاهد Logs:**
```
==> Installing dependencies
==> npm install
==> Starting service
🚀 Notification webhook server is running on port 10000
```

✅ **تم النشر بنجاح!**

---

## الخطوة 5: الحصول على URL (1 دقيقة)

**في Render Dashboard:**

**ستشاهد في الأعلى:**
```
https://fieldawy-notifications.onrender.com
```

📋 **انسخ هذا الـ URL!**

---

## الخطوة 6: تحديث Webhooks في Supabase (5 دقائق)

**1. افتح Supabase Dashboard**

**2. Database > Webhooks**

**3. لكل webhook (surgical_tools, distributor_surgical_tools, إلخ):**

**اضغط على webhook > Edit**

**حدّث URL إلى:**
```
https://fieldawy-store-notifications.onrender.com//api/notify/product-change
```

**احفظ ✅**

---

## الخطوة 7: اختبار! (2 دقيقة)

### Test 1: اختبار من SQL

**في Supabase SQL Editor:**

```sql
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Render Test', 'Test Company');
```

**انتظر 2-3 ثواني...**

✅ **يجب أن يصل إشعار!**

---

### Test 2: فحص Logs في Render

**في Render Dashboard:**

**اذهب إلى `Logs` tab**

**يجب أن تشاهد:**
```
📩 تلقي webhook من Supabase
   Operation: INSERT
   Table: surgical_tools
   Product Name: Render Test
   Tab Name: surgical
✅ تم إرسال الإشعار بنجاح!
```

---

### Test 3: من التطبيق

**1. افتح التطبيق**

**2. أضف أداة جراحية**

**3. يجب أن يصل إشعار! 🎉**

---

## ✅ تم بنجاح!

**الآن لديك:**
- ✅ Server يعمل 24/7
- ✅ URL ثابت: `https://fieldawy-notifications.onrender.com`
- ✅ لا يحتاج تشغيل الكمبيوتر
- ✅ مجاني تماماً!

---

## 🎯 مميزات Render Free Tier

- ✅ **750 ساعة/شهر مجاناً**
- ✅ **Auto-deploy** من GitHub
- ✅ **SSL مجاني**
- ✅ **Logs مجانية**

---

## 🔧 التحديثات المستقبلية

**عند تعديل الكود:**

```bash
cd D:\fieldawy_store

git add .
git commit -m "Update notification logic"
git push
```

✅ **Render سيعيد النشر تلقائياً!**

---

## ⚠️ ملاحظة مهمة: Cold Start

**Render Free Tier:**
- بعد 15 دقيقة بدون استخدام، Server ينام
- أول webhook بعدها سيأخذ 30-60 ثانية للاستيقاظ

**الحل:**
- ارفع لـ Paid Plan ($7/شهر)
- أو استخدم Render Cron Job لإيقاظه كل 10 دقائق (مجاني)

---

## 🆘 حل المشاكل

### مشكلة: Build failed

**افحص Logs في Render:**
- هل `package.json` صحيح؟
- هل جميع dependencies موجودة؟

---

### مشكلة: Service not starting

**افحص Logs:**
- هل `npm start` يعمل؟
- هل `PORT` صحيح؟

---

### مشكلة: Webhook لا يصل

**تحقق من:**
- URL في Supabase صحيح؟
- Render service يعمل؟ (افحص Status)
- Logs في Render تظهر شيء؟

---

## 📊 Monitoring

**لمراقبة النظام:**

**1. Render Dashboard:**
- افحص Logs بانتظام
- تحقق من CPU/Memory usage

**2. Supabase Webhook Logs:**
- افحص Status codes
- تحقق من Response time

---

## 🎉 مبروك!

**نظام الإشعارات الآن:**
- ✅ يعمل في الإنتاج
- ✅ يرسل إشعارات تلقائياً
- ✅ URL ثابت
- ✅ مجاني!

**استمتع! 🚀**
