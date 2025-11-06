-- =====================================================
-- اختبار INSERT مباشر
-- =====================================================

-- 1. محاولة INSERT مباشر (بدون Function)
INSERT INTO product_views (product_id, product_type)
VALUES ('direct-insert-test', 'regular');

-- 2. التحقق
SELECT * FROM product_views WHERE product_id = 'direct-insert-test';

-- 3. عدد الصفوف
SELECT COUNT(*) FROM product_views;

-- 4. التحقق من RLS
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'product_views';

-- 5. عرض Policies
SELECT 
  policyname,
  cmd,
  permissive,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'product_views';

-- 6. محاولة INSERT مع تعطيل RLS
ALTER TABLE product_views DISABLE ROW LEVEL SECURITY;

INSERT INTO product_views (product_id, product_type)
VALUES ('no-rls-test', 'regular');

SELECT * FROM product_views WHERE product_id = 'no-rls-test';

-- 7. إعادة تفعيل RLS
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

