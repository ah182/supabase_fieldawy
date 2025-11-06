-- =====================================================
-- اختبار بسيط جداً
-- =====================================================

-- 1. حذف بيانات الاختبار القديمة
DELETE FROM product_views WHERE product_id LIKE 'test-%';

-- 2. اختبار Function
SELECT track_product_view('test-001', 'regular');

-- 3. التحقق من البيانات
SELECT 
  id,
  product_id,
  user_id,
  user_role,
  product_type,
  viewed_at
FROM product_views 
WHERE product_id = 'test-001';

-- 4. عدد الصفوف الكلي
SELECT COUNT(*) as total_rows FROM product_views;

-- 5. آخر 5 مشاهدات
SELECT 
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 5;

