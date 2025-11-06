-- =====================================================
-- فحص تنفيذ Function
-- =====================================================

-- 1. اختبار Function مباشرة
SELECT track_product_view('443', 'regular');

-- 2. التحقق من البيانات
SELECT * FROM product_views WHERE product_id = '443';

-- 3. عرض آخر 10 مشاهدات
SELECT 
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 10;

-- 4. عدد الصفوف الكلي
SELECT COUNT(*) as total_rows FROM product_views;

-- 5. التحقق من أن Function لا ترفع أخطاء
DO $$
DECLARE
  v_error TEXT;
BEGIN
  PERFORM track_product_view('test-error-check', 'regular');
  RAISE NOTICE 'Function executed successfully';
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
  RAISE NOTICE 'Function error: %', v_error;
END $$;

-- 6. التحقق من البيانات مرة أخرى
SELECT * FROM product_views WHERE product_id = 'test-error-check';

