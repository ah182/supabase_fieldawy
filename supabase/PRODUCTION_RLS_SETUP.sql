-- ═══════════════════════════════════════════════════════════════
-- Production RLS Setup - إعداد RLS للإنتاج بشكل آمن
-- ═══════════════════════════════════════════════════════════════

-- الخطوة 1: تفعيل RLS على جدول users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- الخطوة 2: حذف أي policies قديمة
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Allow users to update own profile" ON users;
DROP POLICY IF EXISTS "Admin can update all users" ON users;
DROP POLICY IF EXISTS "Temporary allow all authenticated updates" ON users;
DROP POLICY IF EXISTS "Dev: Allow authenticated updates" ON users;
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON users;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON users;

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 3: تعيين نفسك كـ admin
-- ═══════════════════════════════════════════════════════════════
-- ⚠️ مهم جداً: ضع بريدك الإلكتروني هنا!

UPDATE users 
SET role = 'admin' 
WHERE email = 'YOUR_EMAIL@example.com';  -- ⚠️ غير هذا لبريدك الحقيقي!

-- للتحقق من نجاح التعيين:
SELECT id, email, role, display_name 
FROM users 
WHERE role = 'admin';

-- يجب أن ترى صفك مع role = 'admin'

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 4: إنشاء Policies آمنة
-- ═══════════════════════════════════════════════════════════════

-- Policy 1: السماح بقراءة جميع المستخدمين (للـ authenticated users)
CREATE POLICY "Allow read access for authenticated users"
ON users
FOR SELECT
TO authenticated
USING (true);

-- Policy 2: السماح للمستخدمين بتحديث ملفهم الشخصي فقط
CREATE POLICY "Users can update own profile"
ON users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 3: السماح للـ admin بتحديث جميع المستخدمين
CREATE POLICY "Admin can update all users"
ON users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() 
    AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() 
    AND role = 'admin'
  )
);

-- Policy 4: السماح للـ admin بحذف المستخدمين
CREATE POLICY "Admin can delete users"
ON users
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() 
    AND role = 'admin'
  )
);

-- Policy 5: السماح بإنشاء مستخدمين جدد (للتسجيل)
CREATE POLICY "Allow user registration"
ON users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 5: التحقق من الـ Policies
-- ═══════════════════════════════════════════════════════════════

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    CASE 
        WHEN qual IS NULL THEN '✅ No restriction'
        ELSE '⚠️ Has restriction'
    END as using_clause,
    CASE 
        WHEN with_check IS NULL THEN '✅ No restriction'
        ELSE '⚠️ Has restriction'
    END as with_check_clause
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;

-- يجب أن ترى 5 policies:
-- 1. Allow read access for authenticated users (SELECT)
-- 2. Users can update own profile (UPDATE)
-- 3. Admin can update all users (UPDATE)
-- 4. Admin can delete users (DELETE)
-- 5. Allow user registration (INSERT)

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 6: اختبار الـ Policies
-- ═══════════════════════════════════════════════════════════════

-- اختبار 1: هل RLS مفعّل؟
SELECT 
    tablename,
    CASE 
        WHEN rowsecurity THEN '🔒 RLS Enabled ✅'
        ELSE '🔓 RLS Disabled ⚠️'
    END as security_status
FROM pg_tables
WHERE tablename = 'users';

-- اختبار 2: من هم الـ admins؟
SELECT 
    id,
    email,
    display_name,
    role,
    CASE 
        WHEN role = 'admin' THEN '✅ Admin'
        ELSE '👤 Regular User'
    END as user_type
FROM users
WHERE role = 'admin';

-- ═══════════════════════════════════════════════════════════════
-- ملاحظات مهمة
-- ═══════════════════════════════════════════════════════════════

-- ✅ RLS الآن مفعّل ومؤمّن
-- ✅ فقط الـ admin يستطيع تحديث/حذف أي مستخدم
-- ✅ المستخدمين العاديين يستطيعون تحديث ملفهم الشخصي فقط
-- ✅ الجميع يستطيع قراءة بيانات المستخدمين (للتطبيق)

-- ⚠️ إذا نسيت تعيين admin في الخطوة 3، لن تستطيع التحديث!
-- الحل: أعد تشغيل الخطوة 3 مع بريدك الصحيح

-- 🔐 للأمان الإضافي، يمكنك إضافة عمود is_admin:
/*
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
UPDATE users SET is_admin = TRUE WHERE role = 'admin';

-- ثم استخدم is_admin بدلاً من role في الـ policies
*/

-- ═══════════════════════════════════════════════════════════════
