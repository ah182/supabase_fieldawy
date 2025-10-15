-- Fix RLS policies for admin to update user status
-- تصليح صلاحيات RLS للسماح للمدير بتحديث حالة المستخدمين

-- 1. Drop existing update policy if exists
DROP POLICY IF EXISTS "Allow users to update own profile" ON users;
DROP POLICY IF EXISTS "Admin can update all users" ON users;

-- 2. Create policy to allow users to update their own profile
CREATE POLICY "Allow users to update own profile"
ON users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 3. Create policy to allow admin to update any user
-- ملاحظة: يجب أن يكون للمدير role = 'admin' في جدول users
CREATE POLICY "Admin can update all users"
ON users
FOR UPDATE
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

-- 4. Alternative: Allow update if user is authenticated (للتطوير فقط!)
-- إذا لم يكن عندك admin role بعد، استخدم هذا مؤقتاً:
-- DROP POLICY IF EXISTS "Temporary allow all authenticated updates" ON users;
-- CREATE POLICY "Temporary allow all authenticated updates"
-- ON users
-- FOR UPDATE
-- USING (auth.role() = 'authenticated')
-- WITH CHECK (auth.role() = 'authenticated');

-- 5. Verify policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'users'
AND cmd = 'UPDATE'
ORDER BY policyname;
