-- ═══════════════════════════════════════════════════════════════
-- حل نهائي وسريع - إصلاح Admin Policy فوراً
-- FINAL FIX: Admin Policy that actually works
-- ═══════════════════════════════════════════════════════════════

-- الخطوة 1: تأكد من RLS مفعّل
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- الخطوة 2: احذف جميع policies القديمة
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Allow users to update own profile" ON users;
DROP POLICY IF EXISTS "Admin can update all users" ON users;
DROP POLICY IF EXISTS "Dev: Allow authenticated updates" ON users;
DROP POLICY IF EXISTS "Temporary allow all authenticated updates" ON users;
DROP POLICY IF EXISTS "Allow read access for authenticated users" ON users;
DROP POLICY IF EXISTS "Admin can delete users" ON users;
DROP POLICY IF EXISTS "Allow user registration" ON users;

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 3: تعيين admin (اختر طريقة واحدة)
-- ═══════════════════════════════════════════════════════════════

-- طريقة 1: بالبريد الإلكتروني
-- ⚠️ غير البريد هنا!
UPDATE users 
SET role = 'admin' 
WHERE email = 'your_email@example.com';

-- طريقة 2: بالـ ID (إذا تعرف ID حسابك)
-- UPDATE users SET role = 'admin' WHERE id = 'your-user-id-here';

-- طريقة 3: شوف جميع المستخدمين واختر واحد
-- SELECT id, email, display_name, role FROM users;

-- تحقق من التعيين:
SELECT 
    id, 
    email, 
    display_name,
    role,
    CASE WHEN role = 'admin' THEN '✅ Admin' ELSE '❌ Not Admin' END as status
FROM users 
ORDER BY created_at DESC 
LIMIT 10;

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 4: إنشاء Policies بسيطة وواضحة
-- ═══════════════════════════════════════════════════════════════

-- Policy 1: القراءة للجميع
CREATE POLICY "read_all"
ON users
FOR SELECT
TO authenticated
USING (true);

-- Policy 2: الإدراج للتسجيل
CREATE POLICY "insert_own"
ON users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Policy 3: التحديث للمستخدم نفسه
CREATE POLICY "update_own"
ON users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 4: التحديث للـ admin (مبسطة بدون WITH CHECK معقدة!)
CREATE POLICY "admin_update_all"
ON users
FOR UPDATE
TO authenticated
USING (
  (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
);

-- Policy 5: الحذف للـ admin فقط
CREATE POLICY "admin_delete_all"
ON users
FOR DELETE
TO authenticated
USING (
  (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
);

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 5: التحقق
-- ═══════════════════════════════════════════════════════════════

-- 1. شوف الـ policies
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN permissive THEN '✅ Permissive'
        ELSE '⚠️ Restrictive'
    END as type
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;

-- 2. شوف الـ admins
SELECT 
    COUNT(*) as admin_count,
    STRING_AGG(email, ', ') as admin_emails
FROM users 
WHERE role = 'admin';

-- 3. اختبر auth.uid() الحالي
SELECT 
    auth.uid() as current_user_id,
    auth.email() as current_email,
    (SELECT role FROM users WHERE id = auth.uid()) as current_role;

-- ═══════════════════════════════════════════════════════════════
-- الخطوة 6: اختبار مباشر (اختياري)
-- ═══════════════════════════════════════════════════════════════

-- جرب تحديث status لأي مستخدم (بعد ما تتأكد أنك admin):
-- UPDATE users 
-- SET account_status = 'approved' 
-- WHERE id = 'some-user-id';
-- 
-- إذا نجح هنا، معناها الـ policy شغالة!

-- ═══════════════════════════════════════════════════════════════
-- إذا لم ينجح؟ استخدم هذا الحل الأخير:
-- ═══════════════════════════════════════════════════════════════

/*
-- حل أخير: Policy بسيطة جداً بدون تعقيدات
DROP POLICY IF EXISTS "admin_update_all" ON users;

CREATE POLICY "admin_update_all"
ON users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users u 
    WHERE u.id = auth.uid() 
    AND u.role = 'admin'
  )
)
WITH CHECK (true);  -- ⚠️ أي تحديث مسموح إذا USING صح

-- أو أبسط:
DROP POLICY IF EXISTS "admin_update_all" ON users;

CREATE POLICY "admin_update_all"
ON users
FOR UPDATE
USING (true)  -- ⚠️ أي مستخدم authenticated يقدر يحدث!
WITH CHECK (true);

-- ملاحظة: هذا للتطوير فقط!
*/

-- ═══════════════════════════════════════════════════════════════
-- ملاحظة نهائية
-- ═══════════════════════════════════════════════════════════════

-- إذا استمرت المشكلة بعد هذا، المشكلة على الأرجح:
-- 1. المستخدم اللي مسجل دخول ليس له role = 'admin'
-- 2. auth.uid() مختلف عن الـ ID اللي عينته admin
-- 3. فيه policy أخرى على جدول تاني بتتعارض

-- الحل النهائي: عطل RLS مؤقتاً:
-- ALTER TABLE users DISABLE ROW LEVEL SECURITY;
