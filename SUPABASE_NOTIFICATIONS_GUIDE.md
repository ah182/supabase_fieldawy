# 🗄️ دليل Firebase Notifications مع Supabase

## 🎯 المميزات

- ✅ **لا تحتاج إدخال Token يدوياً أبداً**
- ✅ حفظ Tokens تلقائياً في Supabase عند تسجيل الدخول
- ✅ إرسال لجميع المستخدمين دفعة واحدة
- ✅ إرسال لمستخدم محدد
- ✅ تتبع الأجهزة (Android/iOS)
- ✅ تنظيف Tokens القديمة تلقائياً

---

## 📋 خطوات الإعداد

### 1️⃣ تطبيق SQL Migration

افتح Supabase Dashboard > SQL Editor وقم بتنفيذ:

```bash
# الملف موجود في:
supabase/migrations/20250120_create_user_tokens.sql
```

أو استخدم Supabase CLI:
```bash
supabase db push
```

**ماذا سيحدث؟**
- ✅ إنشاء جدول `user_tokens`
- ✅ إضافة RLS policies
- ✅ إنشاء functions مساعدة (upsert_user_token, get_all_active_tokens, إلخ)

---

### 2️⃣ إعداد Supabase في Node.js

افتح `send_notification_supabase.js` وعدّل:

```javascript
const SUPABASE_URL = "https://your-project.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key";
```

**كيف تحصل عليهم؟**
1. افتح [Supabase Dashboard](https://supabase.com/dashboard)
2. اختر مشروعك
3. اذهب إلى **Settings** > **API**
4. انسخ:
   - `URL` → `SUPABASE_URL`
   - `service_role` key → `SUPABASE_SERVICE_ROLE_KEY`

⚠️ **مهم:** استخدم `service_role` key وليس `anon` key!

---

### 3️⃣ تثبيت المكتبات الجديدة

```bash
npm install
```

هذا سيثبت `@supabase/supabase-js`

---

### 4️⃣ إعداد Flutter App

الكود جاهز! يحفظ Token تلقائياً عند:
- ✅ تسجيل الدخول
- ✅ تحديث Token
- ✅ فتح التطبيق

**لا تحتاج أي إعداد إضافي في التطبيق.**

---

## 🚀 الاستخدام

### إرسال لجميع المستخدمين

```bash
# إشعار طلب لجميع المستخدمين
npm run supabase:all:order

# إشعار عرض لجميع المستخدمين
npm run supabase:all:offer

# إشعار عام لجميع المستخدمين
npm run supabase:all:general
```

### إرسال لمستخدم محدد

```bash
# استبدل USER_ID بـ UUID المستخدم من قاعدة البيانات
node send_notification_supabase.js user order abc-123-def-456
```

**كيف تحصل على User ID؟**
1. افتح Supabase Dashboard > Authentication > Users
2. انقر على المستخدم
3. انسخ `UUID`

---

## 📊 كيف يعمل؟

### عند تسجيل الدخول:

1. 🔐 المستخدم يسجل دخوله في التطبيق
2. 🔑 التطبيق يحصل على FCM Token
3. 💾 يحفظ Token في Supabase في جدول `user_tokens`
4. ✅ Token جاهز للاستخدام!

### عند إرسال إشعار:

1. 📤 Node.js script يقرأ جميع Tokens من Supabase
2. 📱 يرسل إشعار لكل token
3. ✅ جميع المستخدمين يستقبلون الإشعار!

---

## 🗂️ جدول user_tokens

### الأعمدة:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | المفتاح الأساسي |
| `user_id` | UUID | ربط مع المستخدم |
| `token` | TEXT | FCM Token (unique) |
| `device_type` | TEXT | Android/iOS/Web |
| `device_name` | TEXT | اسم الجهاز |
| `created_at` | TIMESTAMP | تاريخ الإنشاء |
| `updated_at` | TIMESTAMP | تاريخ التحديث |

### Functions المتاحة:

```sql
-- إضافة أو تحديث token
SELECT upsert_user_token(
  'user-uuid',
  'fcm-token',
  'Android',
  'Samsung Galaxy'
);

-- الحصول على جميع tokens النشطة
SELECT * FROM get_all_active_tokens();

-- الحصول على tokens مستخدم محدد
SELECT * FROM get_user_tokens('user-uuid');

-- تنظيف tokens القديمة (أكثر من 180 يوم)
SELECT cleanup_old_tokens();
```

---

## 🔐 الأمان (RLS Policies)

- ✅ المستخدم يقرأ tokens الخاصة به فقط
- ✅ المستخدم يضيف/يعدل tokens الخاصة به فقط
- ✅ Backend (service_role) يقرأ جميع tokens

---

## 🧪 الاختبار

### 1. اختبار حفظ Token:

1. سجّل دخول في التطبيق
2. افحص console:
```
✅ تم حفظ FCM Token في Supabase بنجاح
   User ID: abc-123...
   Device: Android
```

3. تحقق من Supabase Dashboard:
```sql
SELECT * FROM user_tokens;
```

### 2. اختبار الإرسال:

```bash
# أرسل لجميع المستخدمين
npm run supabase:all:order
```

**النتيجة المتوقعة:**
```
✅ تم الحصول على 5 token من Supabase
📱 سيتم الإرسال إلى 5 جهاز
✅ نجح: 5 | ❌ فشل: 0
```

---

## 📈 مراقبة الأداء

### عرض جميع Tokens:

```sql
SELECT 
  u.email,
  ut.device_type,
  ut.created_at,
  ut.updated_at
FROM user_tokens ut
JOIN auth.users u ON ut.user_id = u.id
ORDER BY ut.created_at DESC;
```

### عدد المستخدمين لكل نوع جهاز:

```sql
SELECT 
  device_type,
  COUNT(*) as count
FROM user_tokens
GROUP BY device_type;
```

### Tokens القديمة (لم تُحدّث خلال 30 يوم):

```sql
SELECT 
  COUNT(*) as old_tokens
FROM user_tokens
WHERE updated_at < NOW() - INTERVAL '30 days';
```

---

## 🔧 Troubleshooting

### مشكلة: "لا توجد tokens محفوظة"

**الحل:**
1. سجّل دخول في التطبيق
2. تأكد من الـ SQL migration تم تطبيقه
3. تحقق من الـ console في التطبيق:
```
✅ تم حفظ FCM Token في Supabase بنجاح
```

### مشكلة: "خطأ في قراءة Tokens من Supabase"

**الحل:**
1. تحقق من `SUPABASE_URL` و `SUPABASE_SERVICE_ROLE_KEY`
2. تأكد من أن `service_role` key وليس `anon`
3. تحقق من الـ RLS policies

### مشكلة: Token لا يُحفظ

**الحل:**
1. تحقق من تسجيل الدخول في Supabase
2. افحص console للأخطاء
3. تحقق من وجود `upsert_user_token` function:
```sql
SELECT * FROM pg_proc WHERE proname = 'upsert_user_token';
```

---

## 🆚 المقارنة مع الحلول الأخرى

| الميزة | Token في ملف | Topics | Supabase |
|--------|--------------|--------|----------|
| إدخال Token يدوياً | مرة واحدة | لا ❌ | لا ❌ |
| عدد الأجهزة | 1 | غير محدود | غير محدود |
| إرسال لمستخدم محدد | ❌ | ❌ | ✅ |
| إرسال لجميع المستخدمين | ❌ | ✅ | ✅ |
| تتبع الأجهزة | ❌ | ❌ | ✅ |
| للإنتاج | ❌ | ✅ | ✅✅✅ |

**🏆 Supabase هو الحل الأكثر احترافية!**

---

## 📚 الملفات المُنشأة

- ✅ `supabase/migrations/20250120_create_user_tokens.sql` - SQL migration
- ✅ `lib/services/fcm_token_service.dart` - خدمة حفظ Tokens
- ✅ `lib/services/fcm_token_provider.dart` - Riverpod provider
- ✅ `send_notification_supabase.js` - سكريبت الإرسال

---

## 🚀 الخطوة التالية

1. ✅ نفّذ SQL migration
2. ✅ أضف Supabase credentials في `send_notification_supabase.js`
3. ✅ ثبّت المكتبات: `npm install`
4. ✅ سجّل دخول في التطبيق
5. ✅ أرسل إشعار: `npm run supabase:all:order`

**🎉 استمتع بإشعارات احترافية بالكامل!**
