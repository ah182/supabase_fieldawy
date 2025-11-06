-- =====================================================
-- تشخيص مشكلة عدم إضافة بيانات في product_views
-- =====================================================

-- =====================================================
-- 1. التحقق من وجود الجدول
-- =====================================================
SELECT 
  table_name,
  (SELECT COUNT(*) FROM product_views) as row_count
FROM information_schema.tables
WHERE table_name = 'product_views';

-- =====================================================
-- 2. التحقق من بنية الجدول
-- =====================================================
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'product_views'
ORDER BY ordinal_position;

-- =====================================================
-- 3. التحقق من RLS Policies
-- =====================================================
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'product_views';

-- =====================================================
-- 4. التحقق من وجود Function
-- =====================================================
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_name = 'track_product_view';

-- =====================================================
-- 5. اختبار إدراج مباشر (بدون Function)
-- =====================================================
INSERT INTO product_views (product_id, product_type)
VALUES ('direct-test-001', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'direct-test-001';

-- =====================================================
-- 6. اختبار Function
-- =====================================================
SELECT track_product_view('function-test-001', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'function-test-001';

-- =====================================================
-- 7. اختبار مع user_id
-- =====================================================
-- هذا سيفشل إذا لم تكن مسجل دخول، لكنه يجب أن يسجل على الأقل
SELECT track_product_view('user-test-001', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'user-test-001';

-- =====================================================
-- 8. عرض جميع البيانات
-- =====================================================
SELECT 
  id,
  product_id,
  user_id,
  user_role,
  product_type,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC;

-- =====================================================
-- 9. التحقق من Grants
-- =====================================================
SELECT 
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'track_product_view';

-- =====================================================
-- 10. اختبار الأخطاء
-- =====================================================
-- محاولة استدعاء Function بمعاملات خاطئة
DO $$
BEGIN
  PERFORM track_product_view('error-test', 'invalid-type');
  RAISE NOTICE 'Function executed without error';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error: %', SQLERRM;
END $$;

-- =====================================================
-- 11. تنظيف بيانات الاختبار
-- =====================================================
-- DELETE FROM product_views WHERE product_id LIKE '%-test-%';

