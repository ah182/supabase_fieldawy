# الخطوات النهائية للنشر - الدومين الجديد

## 📌 الدومين الحالي:
```
https://fieldawy-store-app.web.app
```

---

## ✅ الخطوات:

### 1️⃣ **النشر على Firebase:**

```bash
firebase deploy --only hosting
```

**انتظر حتى ينتهي...**

---

### 2️⃣ **تحديث Supabase URLs (مهم جداً!):**

#### الخطوات:
1. اذهب إلى: https://supabase.com/dashboard
2. افتح مشروعك: `fieldawy-store`
3. **Authentication → URL Configuration**

#### **Site URL:**
```
https://fieldawy-store-app.web.app
```

#### **Redirect URLs (أضف كلهم):**
```
http://localhost:*/**
http://127.0.0.1:*/**
https://fieldawy-store-app.web.app/**
https://rkukzuwerbvmueuxadul.supabase.co/**
fieldawy://
fieldawy://auth/callback
com.fieldawy.app://
com.fieldawy.app://auth/callback
```

#### **اضغط Save**

---

### 3️⃣ **اختبار Dashboard:**

افتح: https://fieldawy-store-app.web.app

#### تحقق من:
- [ ] الصفحة تفتح بدون أخطاء ✅
- [ ] لا توجد رسالة "env file missing" ✅
- [ ] تسجيل الدخول يعمل ✅
- [ ] البيانات تظهر ✅
- [ ] جميع التابات تعمل ✅

---

## 🔍 إذا مازالت المشكلة موجودة:

### افتح Developer Console (F12):

في المتصفح:
1. اضغط `F12`
2. اذهب إلى **Console** tab
3. ابحث عن الأخطاء

### الأخطاء المحتملة:

#### ❌ "env file missing":
**الحل:**
```bash
# تأكد من وجود env.js
Test-Path build\web\env.js

# إذا False:
Copy-Item web\env.js build\web\env.js -Force

# أعد النشر
firebase deploy --only hosting
```

#### ❌ "SUPABASE_URL is undefined":
**الحل:**
- تأكد من `window.ENV` في Console
- في Console اكتب: `window.ENV`
- يجب أن ترى الـ SUPABASE_URL و ANON_KEY

---

## 🛠️ الحل الأضمن:

إذا المشكلة مستمرة، استخدم hardcoded values:

### عدل `lib/core/supabase/supabase_init.dart`:

```dart
class SupaKeys {
  static String get url {
    if (kIsWeb) {
      // For Web: hardcoded (temporary)
      return 'https://rkukzuwerbvmueuxadul.supabase.co';
    }
    return dotenv.env['SUPABASE_URL'] ?? '';
  }
  
  static String get anon {
    if (kIsWeb) {
      // For Web: hardcoded (temporary)
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrdWt6dXdlcmJ2bXVldXhhZHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc4NTcwODcsImV4cCI6MjA3MzQzMzA4N30.Rs69KRvvB8u6A91ZXIzkmWebO_IyavZXJrO-SXa2_mc';
    }
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }
}
```

ثم:
```bash
flutter build web --release
firebase deploy --only hosting
```

---

## 📊 Checklist نهائي:

- [ ] `flutter build web --release` تم ✅
- [ ] `build/web/env.js` موجود ✅
- [ ] `build/web/index.html` يحتوي على `<script src="env.js">` ✅
- [ ] `firebase deploy --only hosting` نجح ✅
- [ ] Supabase URLs محدثة للدومين الجديد ✅
- [ ] Dashboard يفتح بدون أخطاء ✅

---

## 🎉 بعد النجاح:

Dashboard الآن live على:
```
https://fieldawy-store-app.web.app
```

### لا تنسى:
1. ✅ حفظ الرابط
2. ✅ اختبار جميع الوظائف
3. ✅ مشاركة الرابط مع Admins فقط!

---

**جرب النشر الآن! 🚀**
