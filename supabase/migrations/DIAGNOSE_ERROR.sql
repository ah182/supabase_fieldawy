-- =====================================================
-- تشخيص الخطأ: column "product_type" does not exist
-- =====================================================

-- 1. التحقق من الجداول الموجودة
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'distributor_products',
  'distributor_ocr_products',
  'distributor_surgical_tools',
  'offers',
  'courses',
  'books',
  'product_views'
)
ORDER BY table_name;

-- 2. التحقق من أعمدة distributor_products
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'distributor_products'
ORDER BY ordinal_position;

-- 3. التحقق من أعمدة distributor_ocr_products
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'distributor_ocr_products'
ORDER BY ordinal_position;

-- 4. التحقق من أعمدة distributor_surgical_tools
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'distributor_surgical_tools'
ORDER BY ordinal_position;

-- 5. التحقق من أعمدة offers
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'offers'
ORDER BY ordinal_position;

-- 6. البحث عن أي عمود اسمه product_type
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE column_name = 'product_type'
AND table_schema = 'public';

-- 7. التحقق من وجود جدول product_views
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables
  WHERE table_name = 'product_views'
  AND table_schema = 'public'
) as product_views_exists;

-- 8. إذا كان product_views موجوداً، عرض أعمدته
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'product_views'
AND table_schema = 'public'
ORDER BY ordinal_position;

