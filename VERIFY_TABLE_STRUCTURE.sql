-- =====================================================
-- التحقق من بنية الجدول
-- =====================================================

-- 1. هل الجدول موجود؟
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_name = 'product_views'
AND table_schema = 'public';

-- 2. ما هي الأعمدة؟
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'product_views'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. ما هي الـ Constraints؟
SELECT 
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'product_views'
AND table_schema = 'public';

-- 4. هل RLS مفعل؟
SELECT 
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'product_views'
AND schemaname = 'public';

-- 5. ما هي الـ Policies؟
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  qual::TEXT as qual,
  with_check::TEXT as with_check
FROM pg_policies
WHERE tablename = 'product_views'
AND schemaname = 'public';

-- 6. من يملك الجدول؟
SELECT 
  tablename,
  tableowner
FROM pg_tables
WHERE tablename = 'product_views'
AND schemaname = 'public';

-- 7. ما هي الصلاحيات؟
SELECT 
  grantee,
  privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'product_views'
AND table_schema = 'public';

