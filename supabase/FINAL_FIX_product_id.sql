-- ==========================================
-- ✅ الحل النهائي الصحيح: استخدام product_id
-- ==========================================
-- المشكلة: Flutter يرسل product_id (مثل "649")
-- لكن Function تبحث في id (مثل "uuid_674_100ml")
-- الحل: تعديل Function لتبحث في product_id
-- ==========================================

-- 1️⃣ حذف Functions القديمة
DROP FUNCTION IF EXISTS increment_product_views(TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(TEXT);


-- 2️⃣ للمنتجات العادية - ابحث في product_id
-- ==========================================
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE product_id = p_product_id;  -- ✅ استخدام product_id بدلاً من id
$$;


-- 3️⃣ لمنتجات OCR
-- ==========================================
CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id
    AND ocr_product_id::TEXT = p_ocr_product_id;
$$;


-- 4️⃣ للأدوات الجراحية
-- ==========================================
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(p_tool_id TEXT)
RETURNS void 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_tool_id;
$$;


-- 5️⃣ منح الصلاحيات
-- ==========================================
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO anon;


-- 6️⃣ اختبار
-- ==========================================

-- امسح views أولاً
UPDATE distributor_products SET views = 0 WHERE product_id = '649';

-- اختبر Function مع product_id
SELECT increment_product_views('649');
SELECT increment_product_views('649');
SELECT increment_product_views('649');

-- تحقق من الزيادة (استخدم product_id)
SELECT id, product_id, views 
FROM distributor_products 
WHERE product_id = '649';

-- يجب أن ترى views = 3 ✅


-- 7️⃣ اختبار شامل مع IDs متعددة
-- ==========================================

-- امسح views
UPDATE distributor_products SET views = 0 WHERE product_id IN ('649', '592', '1129');

-- اختبر
SELECT increment_product_views('649');
SELECT increment_product_views('592');
SELECT increment_product_views('1129');

-- تحقق
SELECT id, product_id, views 
FROM distributor_products 
WHERE product_id IN ('649', '592', '1129');

-- يجب أن ترى كل منهم views = 1 ✅


-- 8️⃣ عرض المنتجات التي لها مشاهدات
-- ==========================================
SELECT id, product_id, views 
FROM distributor_products 
WHERE views > 0 
ORDER BY views DESC 
LIMIT 10;


-- ==========================================
-- ✅ تم! Function الآن تعمل مع product_id
-- ==========================================
