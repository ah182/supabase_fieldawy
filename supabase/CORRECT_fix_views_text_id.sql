-- ==========================================
-- ✅ الحل الصحيح النهائي: id هو TEXT
-- ==========================================
-- من schema الجدول:
-- id text not null  ← TEXT وليس INTEGER أو UUID!
-- views integer null default 0  ← موجود
-- ==========================================

-- 1️⃣ حذف Functions القديمة
DROP FUNCTION IF EXISTS increment_product_views(TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(TEXT);


-- 2️⃣ للمنتجات العادية - id هو TEXT
-- ==========================================
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    -- id هو TEXT، لذا نقارن مباشرة!
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id = p_product_id;
END;
$$;


-- 3️⃣ لمنتجات OCR
-- ==========================================
CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id
    AND ocr_product_id = p_ocr_product_id;
END;
$$;


-- 4️⃣ للأدوات الجراحية
-- ==========================================
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(p_tool_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_tool_id;
END;
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

-- اختبر مع TEXT ID
SELECT increment_product_views('649');

-- تحقق من الزيادة
SELECT id, views FROM distributor_products WHERE id = '649';
-- يجب أن ترى views زادت! ✅

-- اختبر مع IDs أخرى
SELECT increment_product_views('592');
SELECT increment_product_views('1129');

-- تحقق
SELECT id, views 
FROM distributor_products 
WHERE id IN ('649', '592', '1129');


-- 7️⃣ عرض المنتجات التي لها مشاهدات
-- ==========================================
SELECT id, product_id, views 
FROM distributor_products 
WHERE views > 0 
ORDER BY views DESC 
LIMIT 10;


-- ==========================================
-- ✅ تم! Function بسيطة تعمل مع TEXT id
-- ==========================================
