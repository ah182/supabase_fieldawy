# إعداد نظام الإشعارات المخصصة من Dashboard

## المشكلة التي تم حلها ✅
- **قبل:** كان الكود يحفظ البيانات فقط، لكن لا يرسل الإشعار فعلياً
- **الإشعارات الواصلة:** كانت من triggers تلقائية لتحديث المنتجات فقط
- **الآن:** يمكنك إرسال إشعارات مخصصة بالعنوان والنص الذي تكتبه! 🎉

---

## الخطوات السريعة (10 دقائق)

### 1️⃣ احصل على Firebase Server Key

1. افتح [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: **fieldawy-store-app**
3. اذهب لـ **Project Settings** ⚙️
4. تبويب **Cloud Messaging**
5. انسخ **Server Key** (يبدأ بـ `AAAA...`)

---

### 2️⃣ نشر Edge Function في Supabase

```bash
# في terminal في مجلد المشروع
cd D:\fieldawy_store

# تسجيل دخول Supabase CLI (مرة واحدة فقط)
npx supabase login

# ربط المشروع (مرة واحدة فقط)
npx supabase link --project-ref rkukzuwerbvmueuxadul

# نشر Edge Function
npx supabase functions deploy send-custom-notification
```

---

### 3️⃣ إضافة Firebase Server Key في Supabase

```bash
# في terminal
npx supabase secrets set FIREBASE_SERVER_KEY=YOUR_FIREBASE_SERVER_KEY_HERE
```

**أو عبر Dashboard:**
1. افتح [Supabase Dashboard](https://supabase.com/dashboard)
2. اذهب لـ **Edge Functions** → **Settings**
3. أضف Secret:
   - Key: `FIREBASE_SERVER_KEY`
   - Value: `AAAA....` (الـ Server Key من Firebase)

---

### 4️⃣ اختبار الإشعارات

1. افتح **Web Admin Dashboard**
2. تبويب **Dashboard** → قسم **Push Notification Manager**
3. اختر Target (All / Role / Governorate)
4. اكتب العنوان والرسالة
5. اضغط **Send Notification**
6. ✅ **النتيجة:** سيصل الإشعار بنفس النص الذي كتبته!

---

## كيف يعمل النظام الآن؟

### **قبل الإصلاح:**
```
Dashboard → حفظ في Database فقط ❌
Triggers → إرسال إشعار "تحديث منتج" تلقائياً 📦
```

### **بعد الإصلاح:**
```
Dashboard → Edge Function → Firebase FCM → إرسال الإشعار بالنص المخصص ✅
```

---

## الملفات المعدلة

### 1. **Supabase Edge Function:**
```
D:\fieldawy_store\supabase\functions\send-custom-notification\index.ts
```

### 2. **Widget محدث:**
```
D:\fieldawy_store\lib\features\admin_dashboard\presentation\widgets\notification_manager_widget.dart
```

---

## Troubleshooting

### مشكلة: "Function not found"
```bash
# التأكد من نشر Edge Function
npx supabase functions list

# إعادة النشر
npx supabase functions deploy send-custom-notification
```

### مشكلة: "Unauthorized"
```bash
# التأكد من إضافة FIREBASE_SERVER_KEY
npx supabase secrets list

# إضافة Secret إذا لم يكن موجود
npx supabase secrets set FIREBASE_SERVER_KEY=YOUR_KEY
```

### مشكلة: "No users found"
- تأكد أن المستخدمين لديهم tokens مسجلة في جدول `user_tokens`
- افتح تطبيق الموبايل وسجل دخول لإنشاء token

---

## التحقق من الإشعارات المرسلة

### في Supabase:
```sql
-- عرض آخر 10 إشعارات تم إرسالها
SELECT * FROM notifications_sent 
ORDER BY sent_at DESC 
LIMIT 10;
```

### في Edge Function Logs:
1. افتح **Supabase Dashboard**
2. **Edge Functions** → **send-custom-notification**
3. تبويب **Logs**
4. سترى:
   ```
   Sending notification to 25 devices
   Success: 23, Failed: 2
   ```

---

## أنواع الـ Targets

### 1. **All Users** (كل المستخدمين)
- يرسل لجميع من لديهم التطبيق

### 2. **By Role** (حسب الدور)
- **Doctor**: الأطباء فقط
- **Distributor**: الموزعين فقط
- **Company**: الشركات فقط

### 3. **By Governorate** (حسب المحافظة)
- يرسل لمستخدمين في محافظة معينة
- مثال: Cairo, Alexandria, Giza

---

## الإحصائيات

بعد الإرسال سترى:
```
✅ Notification sent! ✅ 23 sent, ❌ 2 failed
```

- **Sent**: عدد الأجهزة التي استلمت الإشعار
- **Failed**: أجهزة لم تستلم (tokens منتهية أو التطبيق محذوف)

---

## التكلفة 💰

### Supabase Edge Functions:
- ✅ **2 Million invocations/month** (مجاني!)
- ✅ **100 GB bandwidth** (مجاني!)

### Firebase FCM:
- ✅ **Unlimited notifications** (مجاني تماماً!)

### الخلاصة:
**مجاني 100% للأبد! 🎉**

---

## أمثلة على الاستخدام

### إشعار عن عرض:
```
Title: عرض خاص 🎉
Message: خصم 50% على جميع المنتجات لمدة 24 ساعة!
Target: All Users
```

### إشعار للأطباء:
```
Title: منتجات جديدة
Message: تم إضافة 15 منتج طبي جديد للكتالوج
Target: By Role → Doctor
```

### إشعار لمحافظة:
```
Title: خدمة التوصيل
Message: التوصيل المجاني متاح الآن في محافظة القاهرة!
Target: By Governorate → Cairo
```

---

## الخلاصة ✅

الآن يمكنك:
- ✅ إرسال إشعارات مخصصة بأي عنوان ورسالة
- ✅ استهداف مجموعات محددة (All / Role / Governorate)
- ✅ تتبع عدد الإشعارات المرسلة والفاشلة
- ✅ حفظ تاريخ الإشعارات في قاعدة البيانات

**ابدأ الإرسال الآن! 🚀**
