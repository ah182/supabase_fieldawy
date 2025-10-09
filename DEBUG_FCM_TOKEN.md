# 🔍 تصحيح مشكلة عدم حفظ FCM Token

## ✅ الخطوات المُنفذة

1. ✅ إضافة import للـ FCMTokenService في main.dart
2. ✅ إضافة استدعاء `_setupFCMTokenService()` في `_initializeApp`
3. ✅ إعداد مستمع لـ auth state changes
4. ✅ حفظ Token تلقائياً عند تسجيل الدخول

---

## 🧪 خطوات الاختبار

### 1️⃣ التحقق من SQL Migration

افتح Supabase Dashboard > SQL Editor وشغّل:

```sql
-- التحقق من وجود الجدول
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_name = 'user_tokens'
) as table_exists;
```

**النتيجة المتوقعة:** `table_exists: true`

**إذا كانت false:**
- نفّذ محتوى `supabase/migrations/20250120_create_user_tokens.sql`

---

### 2️⃣ التحقق من Functions

```sql
SELECT proname as function_name
FROM pg_proc
WHERE proname IN (
  'upsert_user_token',
  'get_all_active_tokens',
  'get_user_tokens',
  'cleanup_old_tokens'
);
```

**النتيجة المتوقعة:** يجب أن تظهر 4 functions

---

### 3️⃣ التحقق من RLS Policies

```sql
SELECT policyname
FROM pg_policies
WHERE tablename = 'user_tokens';
```

**النتيجة المتوقعة:** يجب أن تظهر 4 policies

---

### 4️⃣ اختبار الحفظ من التطبيق

#### أ) أعد تشغيل التطبيق:

```bash
flutter run
```

#### ب) افحص Console عند تسجيل الدخول:

**يجب أن تشاهد:**

```
🔐 تم تسجيل الدخول - جاري حفظ FCM Token...
🔑 تم الحصول على FCM Token: xyz...
✅ تم حفظ FCM Token في Supabase بنجاح
   User ID: abc-123...
   Device: Android
```

**إذا لم تشاهد هذه الرسائل:**
- تحقق من أن Supabase مهيأ بشكل صحيح
- تحقق من أن المستخدم مسجل دخول بالفعل

---

### 5️⃣ التحقق من قاعدة البيانات

افتح Supabase Dashboard > SQL Editor:

```sql
-- عرض جميع Tokens
SELECT 
  ut.user_id,
  ut.token,
  ut.device_type,
  ut.created_at
FROM user_tokens ut
ORDER BY ut.created_at DESC;
```

**يجب أن تظهر البيانات!**

---

## 🐛 الأخطاء الشائعة وحلولها

### ❌ الخطأ: "Function upsert_user_token does not exist"

**السبب:** SQL migration لم يتم تطبيقه

**الحل:**
1. افتح Supabase Dashboard > SQL Editor
2. الصق محتوى `supabase/migrations/20250120_create_user_tokens.sql`
3. اضغط Run

---

### ❌ الخطأ: "permission denied for table user_tokens"

**السبب:** RLS policies غير صحيحة أو service_definer مفقود

**الحل:**
```sql
-- تحقق من أن function عندها security definer
SELECT proname, prosecdef
FROM pg_proc
WHERE proname = 'upsert_user_token';
-- prosecdef يجب أن يكون true
```

إذا كان false، أعد إنشاء الدالة مع `security definer`:
```sql
CREATE OR REPLACE FUNCTION upsert_user_token(...)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- مهم!
AS $$
...
$$;
```

---

### ❌ الخطأ: "لا توجد رسائل في console"

**السبب:** FCMTokenService لم يتم استدعاؤه

**الحل:**
1. تأكد من أن `_setupFCMTokenService()` موجودة في `_initializeApp`
2. أعد تشغيل التطبيق بالكامل (Hot Restart)

---

### ❌ Token يُحفظ لكن user_id = null

**السبب:** المستخدم غير مسجل دخول في Supabase auth

**الحل:**
```dart
// تحقق من حالة المستخدم
print('Current user: ${Supabase.instance.client.auth.currentUser?.id}');
```

إذا كان null:
- تأكد من تسجيل الدخول بشكل صحيح
- تحقق من أن Supabase.initializeApp تم استدعاؤه

---

## 🔬 اختبار متقدم

### اختبار يدوي للدالة:

```sql
-- استبدل USER_UUID بـ UUID المستخدم من auth.users
SELECT upsert_user_token(
  'YOUR_USER_UUID'::uuid,
  'test-token-12345',
  'Android',
  'Test Device'
);

-- تحقق من الحفظ
SELECT * FROM user_tokens WHERE token = 'test-token-12345';
```

---

## 📊 Console Logs المتوقعة

### عند فتح التطبيق (مستخدم مسجل دخول):

```
🔐 Firebase initialization
✅ تم الحصول على FCM Token بنجاح
💾 سيتم حفظه في Supabase بعد تسجيل الدخول
✅ تم الاشتراك في topic: all_users
...
👤 المستخدم مسجل دخول - جاري حفظ FCM Token...
🔑 تم الحصول على FCM Token: abc123...
✅ تم حفظ FCM Token في Supabase بنجاح
   User ID: uuid-here
   Device: Android
```

### عند تسجيل دخول جديد:

```
🔐 تم تسجيل الدخول - جاري حفظ FCM Token...
🔑 تم الحصول على FCM Token: xyz789...
✅ تم حفظ FCM Token في Supabase بنجاح
   User ID: uuid-here
   Device: Android
```

---

## ✅ الحل النهائي

إذا اتبعت الخطوات وما زالت المشكلة موجودة:

### 1. تحقق من الترتيب:

```dart
Future<void> _initializeApp() async {
  // 1. Supabase أولاً
  await initSupabase();
  
  // 2. ثم FCM
  _setupFCMTokenService();
  
  // 3. باقي الإعدادات
  unawaited(StorageService().cleanupTempImages());
}
```

### 2. أعد تشغيل التطبيق بالكامل:

```bash
flutter clean
flutter pub get
flutter run
```

### 3. سجّل خروج ثم دخول مرة أخرى

### 4. افحص console بدقة

---

## 📞 للدعم الإضافي

إذا استمرت المشكلة، شارك:
1. ✅ Console logs كاملة
2. ✅ نتيجة `SELECT * FROM user_tokens;`
3. ✅ نتيجة `SELECT * FROM pg_proc WHERE proname = 'upsert_user_token';`
4. ✅ أي أخطاء تظهر

---

**🔧 الكود محدّث الآن - أعد تشغيل التطبيق!**
