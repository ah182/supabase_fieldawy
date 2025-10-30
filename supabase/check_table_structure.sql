-- ==========================================
-- التحقق من بنية جدول distributor_products
-- ==========================================

-- 1️⃣ عرض جميع الأعمدة في الجدول
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'distributor_products'
ORDER BY ordinal_position;

-- 2️⃣ عرض أول صف من الجدول لمعرفة البيانات
SELECT * FROM distributor_products LIMIT 1;

-- 3️⃣ اختبار views column
SELECT id, views FROM distributor_products LIMIT 5;

-- ==========================================
-- بعد معرفة اسم العمود الصحيح، استخدم:
-- ==========================================

-- اختبار Function
SELECT increment_product_views('649');

-- تحقق من الزيادة (استبدل column_name بالاسم الصحيح)
-- SELECT id, product_name, views FROM distributor_products WHERE id = 649;
-- أو
-- SELECT id, title, views FROM distributor_products WHERE id = 649;
-- أو
-- SELECT id, views FROM distributor_products WHERE id = 649;
