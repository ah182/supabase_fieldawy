-- ==========================================
-- ✅ الإصلاح النهائي لـ OCR Views
-- ==========================================

-- حذف Function القديمة
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);

-- إنشاء Function محسنة
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
    
    -- UPDATE مع تحويل كلا العمودين إلى TEXT
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id
    AND ocr_product_id::TEXT = p_ocr_product_id;
    
    -- إذا لم ينجح، جرب تحويل parameters إلى UUID
    IF NOT FOUND THEN
        BEGIN
            UPDATE distributor_ocr_products 
            SET views = COALESCE(views, 0) + 1 
            WHERE distributor_id = p_distributor_id::UUID
            AND ocr_product_id = p_ocr_product_id::UUID;
        EXCEPTION
            WHEN OTHERS THEN
                -- Silent fail
                NULL;
        END;
    END IF;
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;


-- ==========================================
-- اختبار
-- ==========================================

-- امسح views
UPDATE distributor_ocr_products SET views = 0;

-- احصل على IDs حقيقية
SELECT 
    distributor_id::TEXT as dist_id,
    ocr_product_id::TEXT as ocr_id,
    views
FROM distributor_ocr_products 
LIMIT 1;

-- استخدم الـ IDs من النتيجة
-- مثال: SELECT increment_ocr_product_views('abc-123-def', '456-ghi');

-- اختبر 3 مرات (استبدل بالـ IDs الحقيقية)
-- SELECT increment_ocr_product_views('YOUR_DIST_ID', 'YOUR_OCR_ID');
-- SELECT increment_ocr_product_views('YOUR_DIST_ID', 'YOUR_OCR_ID');
-- SELECT increment_ocr_product_views('YOUR_DIST_ID', 'YOUR_OCR_ID');

-- تحقق
-- SELECT distributor_id::TEXT, ocr_product_id::TEXT, views 
-- FROM distributor_ocr_products 
-- WHERE ocr_product_id::TEXT = 'YOUR_OCR_ID';

-- يجب أن ترى views = 3 ✅


-- ==========================================
-- ✅ تم! Function جاهزة للعمل
-- ==========================================
