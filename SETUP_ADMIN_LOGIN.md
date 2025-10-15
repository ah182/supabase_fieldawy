# 🔐 إعداد Admin Login الحقيقي - خطوة بخطوة

## ✅ الخطوة 1: تحديث الكود (تم!) ✓

تم تحديث `main.dart` لاستخدام `AdminLoginRealScreen` الجديد.

---

## 🔨 الخطوة 2: إنشاء حساب Admin في Supabase

### **الطريقة 1: من خلال SQL (الأسهل)** ⚡

1. **افتح Supabase Dashboard:**
   - اذهب إلى: https://supabase.com/dashboard
   - افتح مشروعك
   - من القائمة اليسرى → **SQL Editor**

2. **انسخ والصق هذا الكود:**

⚠️ **مهم جداً:** غير **البريد** و **الباسورد** في السطرين 4 و 5!

```sql
-- إنشاء حساب Admin جديد (نسخة مصلحة)
DO $$
DECLARE
  admin_email TEXT := 'admin@fieldawy.com';  -- ⚠️ غير هذا!
  admin_password TEXT := 'Admin@123456';     -- ⚠️ غير هذا!
  admin_name TEXT := 'Admin';
  new_user_id UUID;
BEGIN
  -- 1. إنشاء مستخدم في auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    admin_email,
    crypt(admin_password, gen_salt('bf')),
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('display_name', admin_name),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO new_user_id;

  -- 2. إضافة المستخدم لجدول users مع role = admin
  INSERT INTO public.users (
    id,
    email,
    display_name,
    role,
    account_status,
    created_at,
    updated_at
  ) VALUES (
    new_user_id,
    admin_email,
    admin_name,
    'admin',
    'approved',
    NOW(),
    NOW()
  );

  RAISE NOTICE '✅ Admin created: % (ID: %)', admin_email, new_user_id;
  
EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE '⚠️ User already exists: %', admin_email;
  WHEN OTHERS THEN
    RAISE EXCEPTION '❌ Error: %', SQLERRM;
END $$;

-- تحقق من الإنشاء
SELECT 
    id, 
    email, 
    display_name, 
    role, 
    account_status,
    '✅ Admin Created!' as status
FROM public.users 
WHERE role = 'admin';
```

3. **اضغط Run** ▶️

4. **يجب أن ترى رسالة:**
   ```
   Admin user created successfully: admin@fieldawy.com
   ```

---

### **الطريقة 2: تحويل مستخدم موجود لـ Admin** 🔄

إذا عندك مستخدم موجود وتريد تحويله لـ admin:

```sql
-- شوف جميع المستخدمين
SELECT id, email, display_name, role 
FROM users 
ORDER BY created_at DESC 
LIMIT 10;

-- اختر ID المستخدم اللي تريد تعيينه admin
UPDATE users 
SET 
    role = 'admin',
    account_status = 'approved'
WHERE email = 'your_email@example.com';  -- ⚠️ ضع بريدك!

-- تحقق
SELECT id, email, role, account_status 
FROM users 
WHERE role = 'admin';
```

---

## 🔐 الخطوة 3: إعداد RLS Policies

```sql
-- 1. تفعيل RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 2. حذف policies القديمة
DROP POLICY IF EXISTS "Dev: Allow authenticated updates" ON users;
DROP POLICY IF EXISTS "Admin can update all users" ON users;
DROP POLICY IF EXISTS "read_all" ON users;
DROP POLICY IF EXISTS "update_own" ON users;
DROP POLICY IF EXISTS "admin_update_all" ON users;

-- 3. إنشاء policies جديدة

-- Policy 1: القراءة للجميع
CREATE POLICY "read_all"
ON users FOR SELECT TO authenticated
USING (true);

-- Policy 2: المستخدمين يحدثوا بياناتهم
CREATE POLICY "update_own"
ON users FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 3: Admin يحدث أي حد
CREATE POLICY "admin_update_all"
ON users FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
);

-- Policy 4: Admin يحذف أي حد
CREATE POLICY "admin_delete_all"
ON users FOR DELETE TO authenticated
USING (
  (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
);

-- Policy 5: للتسجيل
CREATE POLICY "insert_own"
ON users FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);

-- تحقق من Policies
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY cmd, policyname;
```

---

## 🧪 الخطوة 4: اختبار Login

### **في التطبيق:**

1. **شغل Flutter:**
   ```bash
   flutter run -d chrome --web-port=61228
   ```

2. **افتح Admin Login:**
   ```
   http://localhost:61228/admin/login
   ```

3. **سجل دخول:**
   - Email: `admin@fieldawy.com` (أو اللي كتبته)
   - Password: `Admin@123456` (أو اللي كتبته)

4. **يجب أن تشاهد:**
   ```
   ✅ Login successful
   ✅ Redirecting to dashboard...
   ```

---

## ❌ إذا ظهر خطأ؟

### **خطأ 1: Invalid email or password**

**الحل:**
```sql
-- تحقق من الحساب في Supabase
SELECT email FROM auth.users WHERE email = 'admin@fieldawy.com';

-- إذا مش موجود، أعد تشغيل الخطوة 2
```

---

### **خطأ 2: Access denied - Admin only!**

**الحل:**
```sql
-- تحقق من role
SELECT id, email, role FROM users WHERE email = 'admin@fieldawy.com';

-- إذا role ليس admin:
UPDATE users 
SET role = 'admin', user_type = 'admin' 
WHERE email = 'admin@fieldawy.com';
```

---

### **خطأ 3: Update failed بعد Login**

**الحل:**
```sql
-- تحقق من auth.uid() الحالي
SELECT 
    auth.uid() as current_id,
    (SELECT role FROM users WHERE id = auth.uid()) as current_role;

-- يجب أن ترى: current_role = 'admin'

-- إذا لا:
UPDATE users SET role = 'admin' WHERE id = auth.uid();
```

---

## 🔍 الخطوة 5: التحقق من كل شيء

### **اختبار 1: تسجيل الدخول**
```
✅ افتح: http://localhost:61228/admin/login
✅ سجل دخول ببيانات Admin
✅ يجب أن تنتقل لـ /admin/dashboard
```

### **اختبار 2: إحصائيات Dashboard**
```
✅ يجب أن ترى: Total Users, Doctors Count, etc.
✅ الأرقام تظهر صحيحة
```

### **اختبار 3: تحديث Status**
```
✅ اذهب لـ Users Management
✅ غير status لأي مستخدم
✅ يجب أن يشتغل بدون أخطاء!
```

### **اختبار 4: RLS يعمل**
```sql
-- في Supabase SQL Editor:
-- سجل دخول كـ admin أولاً في التطبيق، ثم:
SELECT 
    auth.uid() as my_id,
    auth.email() as my_email,
    (SELECT role FROM users WHERE id = auth.uid()) as my_role;

-- يجب أن ترى: my_role = 'admin' ✅
```

---

## 📊 ملخص الخطوات

| الخطوة | الوصف | الحالة |
|--------|-------|--------|
| 1 | تحديث main.dart | ✅ تم |
| 2 | إنشاء حساب admin | ⏳ يدوي |
| 3 | إعداد RLS policies | ⏳ يدوي |
| 4 | اختبار login | ⏳ يدوي |
| 5 | اختبار dashboard | ⏳ يدوي |

---

## 🎯 التسلسل الصحيح

```
1. شغل SQL (الخطوة 2) في Supabase
   ↓
2. شغل SQL (الخطوة 3) في Supabase
   ↓
3. شغل Flutter app
   ↓
4. افتح /admin/login
   ↓
5. سجل دخول
   ↓
6. جرب تحديث status
   ↓
7. ✅ كل شيء يعمل!
```

---

## 💡 نصائح مهمة

1. **احفظ بيانات Admin:**
   - Email: admin@fieldawy.com
   - Password: Admin@123456
   - احفظهم في مكان آمن!

2. **للأمان:**
   - غير الباسورد لشيء قوي
   - لا تشارك البيانات مع أحد
   - استخدم environment variables للإنتاج

3. **للتطوير:**
   - يمكنك إنشاء أكثر من admin
   - كل admin يسجل دخول بحساب منفصل

---

## 🚀 ابدأ الآن!

**الخطوة التالية:**
افتح Supabase SQL Editor وشغل كود الخطوة 2!

```sql
-- نسخ والصق من الخطوة 2 أعلاه
-- غير البريد والباسورد
-- اضغط Run ▶️
```

**بعدها شغل Flutter:**
```bash
flutter run -d chrome --web-port=61228
```

**واختبر Login! 🎉**
