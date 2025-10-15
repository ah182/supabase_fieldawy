-- ═══════════════════════════════════════════════════════════════
-- URGENT FIX: Allow Admin to Update User Status
-- إصلاح عاجل: السماح للمدير بتحديث حالة المستخدمين
-- ═══════════════════════════════════════════════════════════════

-- الحل السريع للتطوير: السماح لأي مستخدم مسجل بالتحديث
-- TEMPORARY: Allow any authenticated user to update (FOR DEVELOPMENT ONLY)

-- 1. حذف أي policies موجودة للـ UPDATE
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Allow users to update own profile" ON users;
DROP POLICY IF EXISTS "Admin can update all users" ON users;
DROP POLICY IF EXISTS "Temporary allow all authenticated updates" ON users;

-- 2. إنشاء policy جديدة للتطوير (مؤقتة!)
-- Create temporary policy for development
CREATE POLICY "Dev: Allow authenticated updates"
ON users
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 3. للتأكد من أن RLS مفعّل
-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 4. عرض الـ policies الحالية
-- Show current policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    CASE 
        WHEN qual IS NULL THEN 'No restriction'
        ELSE 'Has restriction'
    END as using_clause,
    CASE 
        WHEN with_check IS NULL THEN 'No restriction'
        ELSE 'Has restriction'
    END as with_check_clause
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;

-- ═══════════════════════════════════════════════════════════════
-- ⚠️ ملاحظة مهمة / IMPORTANT NOTE
-- ═══════════════════════════════════════════════════════════════
-- هذا الحل للتطوير فقط!
-- This is a DEVELOPMENT-ONLY solution!
-- 
-- للإنتاج، استخدم واحد من الحلول التالية:
-- For production, use one of these solutions:
--
-- خيار 1: استخدام role = 'admin'
-- Option 1: Use role = 'admin'
/*
UPDATE users SET role = 'admin' WHERE email = 'your_admin@example.com';

CREATE POLICY "Admin can update all users"
ON users FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'admin'
  )
);
*/

-- خيار 2: استخدام is_admin column
-- Option 2: Use is_admin column
/*
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
UPDATE users SET is_admin = TRUE WHERE email = 'your_admin@example.com';

CREATE POLICY "Admins can update all users"
ON users FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND is_admin = TRUE
  )
);
*/

-- ═══════════════════════════════════════════════════════════════
