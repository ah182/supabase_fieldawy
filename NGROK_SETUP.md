# 🔧 تثبيت وإعداد ngrok

## الطريقة 1: تثبيت عبر Chocolatey (الأسرع)

### إذا كان لديك Chocolatey:

```bash
choco install ngrok
```

---

## الطريقة 2: تثبيت يدوي (موصى به)

### الخطوة 1: تحميل ngrok

1. اذهب إلى: https://ngrok.com/download
2. اختر **Windows (64-bit)** 
3. حمّل الملف `ngrok.zip`

---

### الخطوة 2: فك الضغط

1. افتح `ngrok.zip`
2. استخرج `ngrok.exe` إلى مجلد معين، مثلاً:
   ```
   C:\ngrok\ngrok.exe
   ```

---

### الخطوة 3: إضافة ngrok للـ PATH

#### الطريقة الأولى (سريعة):

انسخ `ngrok.exe` إلى مجلد المشروع:

```bash
# في مجلد المشروع
copy C:\path\to\ngrok.exe D:\fieldawy_store\
```

ثم شغّل:
```bash
.\ngrok http 3000
```

---

#### الطريقة الثانية (دائمة):

إضافة للـ PATH:

1. اضغط **Windows + R**
2. اكتب: `sysdm.cpl`
3. اضغط **Enter**
4. اختر **Advanced** tab
5. اضغط **Environment Variables**
6. في **System variables** اختر **Path**
7. اضغط **Edit**
8. اضغط **New**
9. أضف المسار: `C:\ngrok`
10. اضغط **OK** على الكل
11. **أعد فتح CMD/Terminal**

الآن يمكنك:
```bash
ngrok http 3000
```

---

## الطريقة 3: استخدام npx (بدون تثبيت)

```bash
npx ngrok http 3000
```

---

## الطريقة 4: البديل - localtunnel (أسهل!)

### تثبيت:

```bash
npm install -g localtunnel
```

### الاستخدام:

```bash
lt --port 3000
```

**ستحصل على URL مثل:**
```
https://random-name-123.loca.lt
```

استخدمه في Supabase webhooks! ✅

---

## ✅ الخطوات الآن:

### الخيار 1: استخدام localtunnel (الأسهل)

```bash
# Terminal 1: شغّل server
npm start

# Terminal 2: شغّل localtunnel
npm install -g localtunnel
lt --port 3000
```

---

### الخيار 2: استخدام ngrok بعد التثبيت

```bash
# Terminal 1: شغّل server
npm start

# Terminal 2: شغّل ngrok
ngrok http 3000
```

---

## 🧪 اختبار

بعد تشغيل أي من الخيارات:

1. ✅ ستحصل على URL عام
2. ✅ استخدمه في Supabase Webhooks
3. ✅ اختبر بإضافة منتج

---

## 🎯 توصيتي

استخدم **localtunnel** لأنه:
- ✅ أسهل في التثبيت (npm install)
- ✅ لا يحتاج حساب
- ✅ يعمل فوراً

```bash
npm install -g localtunnel
lt --port 3000
```

**Done! 🚀**
