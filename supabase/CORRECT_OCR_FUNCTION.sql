-- ==========================================
-- ✅ OCR Function الصحيحة (كلاهما UUID)
-- ==========================================

DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);

CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- إزالة prefix "ocr_" إذا موجود
    IF p_ocr_product_id LIKE 'ocr_%' THEN
        p_ocr_product_id := substring(p_ocr_product_id from 5);
    END IF;
    
    -- UPDATE: تحويل parameters إلى UUID
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id = p_distributor_id::UUID
    AND ocr_product_id = p_ocr_product_id::UUID;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Silent fail if conversion fails
        NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;


-- ==========================================
-- اختبار
-- ==========================================

-- امسح views
UPDATE distributor_ocr_products SET views = 0;

-- احصل على IDs حقيقية (كـ TEXT)
SELECT 
    distributor_id::TEXT as dist_id,
    ocr_product_id::TEXT as ocr_id,
    views
FROM distributor_ocr_products 
LIMIT 1;

-- استخدم الـ IDs من النتيجة (مثال)
-- SELECT increment_ocr_product_views('abc-123-def-456', 'xyz-789-ghi-012');
-- SELECT increment_ocr_product_views('abc-123-def-456', 'xyz-789-ghi-012');
-- SELECT increment_ocr_product_views('abc-123-def-456', 'xyz-789-ghi-012');

-- تحقق
-- SELECT distributor_id::TEXT, ocr_product_id::TEXT, views 
-- FROM distributor_ocr_products 
-- WHERE ocr_product_id::TEXT = 'xyz-789-ghi-012';

-- يجب أن ترى views = 3 ✅


-- ==========================================
-- ✅ تم!
-- ==========================================
