-- ==========================================
-- تشخيص شامل لمشكلة OCR Views
-- ==========================================

-- 1️⃣ هل يوجد بيانات في الجدول؟
-- ==========================================
SELECT COUNT(*) as total_rows 
FROM distributor_ocr_products;

-- إذا كانت 0 → لا توجد بيانات للاختبار!


-- 2️⃣ عرض أول 3 صفوف
-- ==========================================
SELECT 
    id::TEXT,
    distributor_id::TEXT,
    ocr_product_id::TEXT,
    distributor_name,
    price,
    views
FROM distributor_ocr_products 
LIMIT 3;


-- 3️⃣ اختبار UPDATE يدوي بـ UUIDs حقيقية
-- ==========================================
-- احصل على UUID حقيقي أولاً
DO $$
DECLARE
    v_dist_id UUID;
    v_ocr_id UUID;
    v_rows_affected INTEGER;
BEGIN
    -- احصل على أول صف
    SELECT distributor_id, ocr_product_id 
    INTO v_dist_id, v_ocr_id
    FROM distributor_ocr_products 
    LIMIT 1;
    
    IF v_dist_id IS NULL THEN
        RAISE NOTICE 'No data found in table!';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Testing with distributor_id: %, ocr_product_id: %', v_dist_id, v_ocr_id;
    
    -- امسح views
    UPDATE distributor_ocr_products SET views = 0;
    
    -- اختبار UPDATE يدوي
    UPDATE distributor_ocr_products 
    SET views = 777
    WHERE distributor_id = v_dist_id
    AND ocr_product_id = v_ocr_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RAISE NOTICE 'Manual UPDATE affected % rows', v_rows_affected;
END $$;

-- تحقق من النتيجة
SELECT distributor_id::TEXT, ocr_product_id::TEXT, views 
FROM distributor_ocr_products 
WHERE views = 777;

-- إذا رأيت views = 777 → UPDATE يدوي يعمل ✅
-- إذا لم ترَ شيء → مشكلة في RLS أو constraints


-- 4️⃣ اختبار Function مع logging
-- ==========================================
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);

CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS TABLE(success BOOLEAN, message TEXT, rows_affected INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rows INTEGER := 0;
    v_original_ocr_id TEXT := p_ocr_product_id;
BEGIN
    -- إزالة prefix "ocr_" إذا موجود
    IF p_ocr_product_id LIKE 'ocr_%' THEN
        p_ocr_product_id := substring(p_ocr_product_id from 5);
        RAISE NOTICE 'Removed ocr_ prefix: % -> %', v_original_ocr_id, p_ocr_product_id;
    END IF;
    
    -- محاولة UPDATE
    BEGIN
        UPDATE distributor_ocr_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE distributor_id = p_distributor_id::UUID
        AND ocr_product_id = p_ocr_product_id::UUID;
        
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        
        IF v_rows > 0 THEN
            RETURN QUERY SELECT TRUE, 'Updated successfully'::TEXT, v_rows;
        ELSE
            RETURN QUERY SELECT FALSE, 'No rows found with given IDs'::TEXT, 0;
        END IF;
        
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN QUERY SELECT FALSE, 'Invalid UUID format'::TEXT, 0;
        WHEN OTHERS THEN
            RETURN QUERY SELECT FALSE, 'Error: ' || SQLERRM, 0;
    END;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;


-- 5️⃣ اختبار Function
-- ==========================================
-- امسح views
UPDATE distributor_ocr_products SET views = 0;

-- احصل على IDs حقيقية
SELECT 
    distributor_id::TEXT as dist_id,
    ocr_product_id::TEXT as ocr_id
FROM distributor_ocr_products 
LIMIT 1;

-- اختبر Function (استبدل بالـ IDs الحقيقية من النتيجة)
-- SELECT * FROM increment_ocr_product_views('DIST_ID', 'OCR_ID');
-- SELECT * FROM increment_ocr_product_views('DIST_ID', 'OCR_ID');
-- SELECT * FROM increment_ocr_product_views('DIST_ID', 'OCR_ID');

-- تحقق
-- SELECT distributor_id::TEXT, ocr_product_id::TEXT, views 
-- FROM distributor_ocr_products 
-- WHERE ocr_product_id::TEXT = 'OCR_ID';


-- 6️⃣ البحث عن OCR products في Flutter code
-- ==========================================
-- تحقق من الـ IDs التي يرسلها Flutter
-- في Console يجب أن ترى:
-- 🔵 [Dialog] Incrementing views for product: ocr_XXXX, surgical: false

-- XXXX هو الـ ID المرسل
-- ابحث عنه في الجدول:
-- SELECT * FROM distributor_ocr_products WHERE ocr_product_id::TEXT LIKE '%XXXX%';


-- ==========================================
-- ملخص التشخيص:
-- ==========================================
-- ✅ الخطوة 1: إذا كانت total_rows = 0 → لا توجد بيانات!
-- ✅ الخطوة 3: إذا لم يظهر views = 777 → مشكلة في RLS
-- ✅ الخطوة 5: استخدم IDs حقيقية واختبر Function
--    - إذا success = true → Function تعمل ✅
--    - إذا success = false → راجع message للسبب
