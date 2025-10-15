-- ═══════════════════════════════════════════════════════════════
-- الحل النهائي: تعطيل RLS مؤقتاً للتطوير
-- FINAL SOLUTION: Disable RLS temporarily for development
-- ═══════════════════════════════════════════════════════════════

-- ⚠️ تحذير: هذا للتطوير المحلي فقط!
-- WARNING: This is for LOCAL DEVELOPMENT ONLY!

-- 1. تعطيل RLS على جدول users
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 2. التحقق من الحالة
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'users';

-- 3. يجب أن ترى: rowsecurity = false

-- ═══════════════════════════════════════════════════════════════
-- بعد الانتهاء من التطوير، أعد تفعيل RLS:
-- After development, re-enable RLS:
-- ═══════════════════════════════════════════════════════════════
/*
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- ثم أضف policies آمنة
CREATE POLICY "Admin can update all users"
ON users FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'admin'
  )
);
*/
