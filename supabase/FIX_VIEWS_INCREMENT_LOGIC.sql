-- =================================================================
-- FIX VIEWS INCREMENT LOGIC
-- إصلاح منطق زيادة المشاهدات ليتم لكل منتج موزع على حدة
-- =================================================================

-- 1. إعادة تعريف دالة زيادة مشاهدات المنتجات العادية
-- التأكد من استخدام ID الخاص بجدول distributor_products وليس product_id العام
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    -- p_product_id here refers to the 'id' column of distributor_products table
    -- which is unique for each distributor's product entry
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_product_id;
END;
$$;

-- 2. إعادة تعريف دالة زيادة مشاهدات منتجات OCR
CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    -- Here we need both distributor_id and ocr_product_id to identify the row
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id 
    AND ocr_product_id = p_ocr_product_id;
END;
$$;

-- 3. إعادة تعريف دالة زيادة مشاهدات الأدوات الجراحية
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(p_tool_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    -- p_tool_id refers to the 'id' column of distributor_surgical_tools
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_tool_id;
END;
$$;

-- 4. منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO anon;

-- 5. تقرير الحالة
SELECT 'Views functions updated successfully. Now counting per distributor product item.' as status;
