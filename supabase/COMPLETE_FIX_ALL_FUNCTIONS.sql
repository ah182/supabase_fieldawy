-- ==========================================
-- ✅ الإصلاح الكامل النهائي لجميع Functions
-- ==========================================

-- 1️⃣ حذف جميع Functions القديمة
-- ==========================================
DROP FUNCTION IF EXISTS increment_product_views(TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(TEXT);


-- 2️⃣ للمنتجات العادية - استخدام product_id
-- ==========================================
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE product_id = p_product_id;
$$;


-- 3️⃣ لمنتجات OCR - مع تحويل النوع الصحيح
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


-- 5️⃣ منح الصلاحيات لجميع Functions
-- ==========================================
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO anon;


-- 6️⃣ اختبار شامل
-- ==========================================

-- اختبار المنتجات العادية
UPDATE distributor_products SET views = 0 WHERE product_id = '649';
SELECT increment_product_views('649');
SELECT increment_product_views('649');
SELECT increment_product_views('649');
SELECT product_id, views FROM distributor_products WHERE product_id = '649';
-- يجب أن ترى views = 3 ✅


-- 7️⃣ اختبار مع IDs متعددة
-- ==========================================
UPDATE distributor_products SET views = 0 WHERE product_id IN ('649', '592', '1129');

SELECT increment_product_views('649');
SELECT increment_product_views('592');
SELECT increment_product_views('1129');

SELECT product_id, views 
FROM distributor_products 
WHERE product_id IN ('649', '592', '1129')
ORDER BY product_id;


-- 8️⃣ عرض جميع المنتجات التي لها مشاهدات
-- ==========================================
SELECT product_id, views 
FROM distributor_products 
WHERE views > 0 
ORDER BY views DESC 
LIMIT 20;


-- ==========================================
-- ✅ تم! جميع Functions جاهزة للعمل
-- ==========================================
