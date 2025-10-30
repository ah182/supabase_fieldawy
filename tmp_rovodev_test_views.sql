-- اختبار سريع للمشاهدات
-- تحقق من وجود عمود views في الجداول
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name IN ('distributor_products', 'distributor_ocr_products', 'products')
AND column_name = 'views';

-- تحقق من وجود الـ functions
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name LIKE '%views%' 
AND routine_schema = 'public';

-- جرب زيادة المشاهدات لمنتج تجريبي
SELECT increment_product_views('733');

-- تحقق من المشاهدات
SELECT id, views FROM distributor_products WHERE id::TEXT = '733' LIMIT 1;