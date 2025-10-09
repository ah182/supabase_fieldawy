# 🔧 إصلاح خطأ RLS - Column Name

## ❌ الخطأ

```
ERROR: 42703: column "uid" does not exist
HINT: Perhaps you meant to reference the column "users.id"
```

## 💡 السبب

في جدول `users`، اسم العمود هو **`id`** وليس **`uid`**.

الخطأ كان في:
```sql
SELECT 1 FROM users
WHERE uid = auth.uid()  -- ❌ خطأ
```

## ✅ الحل

تم تصحيح جميع الـ policies:
```sql
SELECT 1 FROM users
WHERE id = auth.uid()  -- ✅ صحيح
```

---

## 🔄 إعادة التطبيق

### الخطوة 1: حذف Policies القديمة (إذا تم تطبيقها)

```sql
-- حذف policies من user_tokens
DROP POLICY IF EXISTS "Users can view their own tokens" ON user_tokens;
DROP POLICY IF EXISTS "Users can insert their own tokens" ON user_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON user_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON user_tokens;
DROP POLICY IF EXISTS "Admins can view all tokens" ON user_tokens;

-- حذف policies من notification_logs
DROP POLICY IF EXISTS "Authenticated users can view notification logs" ON notification_logs;
DROP POLICY IF EXISTS "System can insert notification logs" ON notification_logs;
DROP POLICY IF EXISTS "Admins can update notification logs" ON notification_logs;
DROP POLICY IF EXISTS "Admins can delete notification logs" ON notification_logs;
```

---

### الخطوة 2: تطبيق Migration المُصحّح

في **Supabase Dashboard > SQL Editor**:

```sql
-- انسخ والصق محتوى:
supabase/migrations/20250120_add_rls_notifications_views.sql

-- اضغط Run ✅
```

---

## 🧪 التحقق من النجاح

### Test 1: التحقق من Policies

```sql
-- عرض جميع policies على user_tokens
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_tokens';
```

**يجب أن تشاهد 5 policies:**
1. Users can view their own tokens
2. Users can insert their own tokens
3. Users can update their own tokens
4. Users can delete their own tokens
5. Admins can view all tokens

---

### Test 2: اختبار Policy (مستخدم عادي)

```sql
-- كمستخدم عادي
SELECT * FROM user_tokens;

-- ✅ يجب أن يرى tokens الخاصة به فقط
```

---

### Test 3: اختبار Admin Policy

```sql
-- كـ Admin (user with role = 'admin')
SELECT * FROM user_tokens;

-- ✅ يجب أن يرى جميع tokens
```

---

## 📊 الفرق بين `users.id` و `auth.uid()`

| | `users.id` | `auth.uid()` |
|---|------------|--------------|
| **النوع** | عمود في جدول users | دالة Supabase |
| **الاستخدام** | في JOIN و WHERE للربط | للحصول على ID المستخدم الحالي |
| **مثال** | `users.id = auth.uid()` | `user_id = auth.uid()` |

### مثال صحيح:

```sql
-- ✅ صحيح
CREATE POLICY "example"
ON user_tokens
FOR SELECT
USING (
  user_id = auth.uid()  -- المستخدم الحالي
  OR
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()  -- ✅ عمود users.id
    AND role = 'admin'
  )
);
```

---

## ✅ ما تم إصلاحه

في الملف `20250120_add_rls_notifications_views.sql`:

### قبل ❌:
```sql
WHERE uid = auth.uid()  -- خطأ!
```

### بعد ✅:
```sql
WHERE id = auth.uid()  -- صحيح!
```

تم التصحيح في 3 مواضع:
1. ✅ Policy: "Admins can view all tokens" على user_tokens
2. ✅ Policy: "Admins can update notification logs" على notification_logs
3. ✅ Policy: "Admins can delete notification logs" على notification_logs

---

## 🎯 الآن

1. ✅ حذف policies القديمة (إن وجدت)
2. ✅ طبّق الـ migration المُصحّح
3. ✅ اختبر Policies

**المشكلة محلولة! 🚀**
