# 🧪 اختبار تسجيل حسابين على نفس الجهاز

## ✅ التعديلات المُنفذة

### 1. تعديل الجدول:
- ❌ إزالة `UNIQUE` constraint على `token` وحده
- ✅ إضافة `UNIQUE` constraint على `(user_id, token)` معاً
- ✅ نفس token يمكن استخدامه من أكثر من حساب

### 2. تحديث Functions:
- ✅ `upsert_user_token` - يعمل على (user_id, token)
- ✅ `delete_user_token` - يحذف token لمستخدم محدد فقط
- ✅ `get_users_by_token` - لرؤية كم حساب على نفس الجهاز

---

## 🧪 خطوات الاختبار

### 1️⃣ تطبيق SQL Migration

افتح **Supabase Dashboard > SQL Editor** والصق محتوى:
```
supabase/migrations/20250120_fix_user_tokens_multiple_users.sql
```

ثم اضغط **Run**

---

### 2️⃣ اختبار السيناريو

#### أ) تسجيل الدخول بالحساب الأول:

1. افتح التطبيق
2. سجّل دخول بـ `user1@example.com`
3. افحص Console:
```
✅ تم حفظ FCM Token في Supabase بنجاح
   User ID: abc-123-user1
   Device: Android
   Device Name: Samsung SM-G991B
```

4. افحص Database:
```sql
SELECT user_id, token, device_name FROM user_tokens;
```

**النتيجة:**
| user_id | token | device_name |
|---------|-------|-------------|
| abc-123-user1 | xyz...token | Samsung SM-G991B |

---

#### ب) تسجيل الدخول بالحساب الثاني (نفس الجهاز):

1. سجّل خروج من الحساب الأول
2. سجّل دخول بـ `user2@example.com`
3. افحص Console:
```
✅ تم حفظ FCM Token في Supabase بنجاح
   User ID: def-456-user2
   Device: Android
   Device Name: Samsung SM-G991B
```

4. افحص Database:
```sql
SELECT user_id, token, device_name FROM user_tokens;
```

**النتيجة:**
| user_id | token | device_name |
|---------|-------|-------------|
| abc-123-user1 | xyz...token | Samsung SM-G991B |
| def-456-user2 | xyz...token | Samsung SM-G991B |

**✅ نفس Token، مستخدمين مختلفين!** 🎉

---

## 📊 SQL Queries للاختبار

### 1. عرض جميع Tokens مع تفاصيل المستخدمين:

```sql
SELECT 
  u.email,
  ut.user_id,
  ut.token,
  ut.device_type,
  ut.device_name,
  ut.created_at
FROM user_tokens ut
JOIN auth.users u ON ut.user_id = u.id
ORDER BY ut.token, ut.created_at;
```

---

### 2. عرض Tokens المشتركة بين أكثر من مستخدم:

```sql
SELECT 
  token,
  device_name,
  COUNT(*) as user_count,
  ARRAY_AGG(user_id) as user_ids
FROM user_tokens
GROUP BY token, device_name
HAVING COUNT(*) > 1;
```

**يجب أن تشاهد:**
| token | device_name | user_count | user_ids |
|-------|-------------|------------|----------|
| xyz...token | Samsung SM-G991B | 2 | {abc-123, def-456} |

---

### 3. استخدام دالة get_users_by_token:

```sql
-- استبدل YOUR_TOKEN بـ token حقيقي
SELECT * FROM get_users_by_token('YOUR_TOKEN_HERE');
```

**النتيجة:**
| user_id | device_type | device_name | created_at |
|---------|-------------|-------------|------------|
| abc-123-user1 | Android | Samsung SM-G991B | 2025-01-20... |
| def-456-user2 | Android | Samsung SM-G991B | 2025-01-20... |

---

### 4. عد عدد الأجهزة لمستخدم:

```sql
-- استبدل USER_ID بـ UUID المستخدم
SELECT get_user_devices_count('YOUR_USER_ID_HERE');
```

---

## 📱 إرسال إشعارات

### لإرسال لجميع الحسابات على نفس الجهاز:

عند إرسال notification لـ token معين، **سيصل لجميع الحسابات** المسجلة بنفس الجهاز!

```bash
# في send_notification_supabase.js سيرسل للجميع تلقائياً
npm run supabase:all:order
```

---

## 🔒 الأمان

### السيناريو: حذف Token عند تسجيل الخروج

**قبل التعديل (❌ مشكلة):**
- لو user1 سجّل خروج، كان هيحذف token من الجدول
- user2 على نفس الجهاز مش هيستقبل notifications! ❌

**بعد التعديل (✅ صحيح):**
- لو user1 سجّل خروج، هيحذف token الخاص بـ user1 فقط
- user2 على نفس الجهاز هيستمر يستقبل notifications! ✅

```dart
// الآن deleteToken تحذف للمستخدم الحالي فقط
await fcmService.deleteToken(token);
```

---

## 🧪 سيناريو الاختبار الكامل

### الخطوات:

1. ✅ تطبيق SQL migration
2. ✅ أعد تشغيل التطبيق
3. ✅ سجّل دخول بالحساب الأول
4. ✅ تحقق من حفظ token في database
5. ✅ سجّل خروج
6. ✅ سجّل دخول بالحساب الثاني
7. ✅ تحقق من حفظ token للحساب الثاني
8. ✅ افحص database - يجب أن تشاهد نفس token مرتين لمستخدمين مختلفين
9. ✅ أرسل notification - يجب أن يصل للجميع

---

## 📊 النتيجة المتوقعة في Database

```sql
SELECT 
  ut.user_id,
  u.email,
  ut.token,
  ut.device_name,
  ut.created_at
FROM user_tokens ut
JOIN auth.users u ON ut.user_id = u.id
ORDER BY ut.token, ut.created_at;
```

| user_id | email | token | device_name | created_at |
|---------|-------|-------|-------------|------------|
| abc-123 | user1@example.com | xyz...token | Samsung SM-G991B | 2025-01-20 10:00:00 |
| def-456 | user2@example.com | xyz...token | Samsung SM-G991B | 2025-01-20 10:05:00 |

---

## ✅ الفوائد

1. ✅ نفس الجهاز يمكن استخدامه من أكثر من حساب
2. ✅ تسجيل الخروج من حساب لا يؤثر على الحسابات الأخرى
3. ✅ كل حساب يحتفظ بـ token الخاص به
4. ✅ إرسال notifications يصل لجميع الحسابات المسجلة

---

## 🐛 Troubleshooting

### مشكلة: "duplicate key value violates unique constraint"

**السبب:** SQL migration لم يتم تطبيقه

**الحل:**
1. نفّذ migration في Supabase SQL Editor
2. تحقق من الـ constraint:
```sql
SELECT constraint_name 
FROM information_schema.table_constraints 
WHERE table_name = 'user_tokens' 
  AND constraint_type = 'UNIQUE';
```

يجب أن تشاهد: `user_tokens_user_id_token_key` ✅

---

**الآن جرب السيناريو! 🚀**
