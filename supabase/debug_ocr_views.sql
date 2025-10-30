-- ==========================================
-- تشخيص مشكلة OCR views
-- ==========================================

-- 1️⃣ عرض بنية جدول OCR
-- ==========================================
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'distributor_ocr_products'
ORDER BY ordinal_position;


-- 2️⃣ عرض أول 5 صفوف من الجدول
-- ==========================================
SELECT * FROM distributor_ocr_products LIMIT 5;


-- 3️⃣ عرض أنواع البيانات للأعمدة المهمة
-- ==========================================
SELECT 
    distributor_id,
    pg_typeof(distributor_id) as distributor_id_type,
    ocr_product_id,
    pg_typeof(ocr_product_id) as ocr_product_id_type,
    views
FROM distributor_ocr_products 
LIMIT 1;


-- 4️⃣ اختبار UPDATE يدوي
-- ==========================================
-- احصل على أول صف
DO $$
DECLARE
    v_dist_id TEXT;
    v_ocr_id TEXT;
BEGIN
    SELECT distributor_id::TEXT, ocr_product_id 
    INTO v_dist_id, v_ocr_id
    FROM distributor_ocr_products 
    LIMIT 1;
    
    RAISE NOTICE 'distributor_id: %, ocr_product_id: %', v_dist_id, v_ocr_id;
    
    -- جرب UPDATE يدوي
    UPDATE distributor_ocr_products 
    SET views = 999
    WHERE distributor_id::TEXT = v_dist_id
    AND ocr_product_id = v_ocr_id;
    
    RAISE NOTICE 'Updated rows: %', FOUND;
END $$;

-- تحقق من النتيجة
SELECT distributor_id, ocr_product_id, views 
FROM distributor_ocr_products 
WHERE views = 999;


-- 5️⃣ اختبار Function الحالية
-- ==========================================
-- امسح views أولاً
UPDATE distributor_ocr_products SET views = 0;

-- احصل على IDs حقيقية
SELECT 
    distributor_id::TEXT as dist_id,
    ocr_product_id as ocr_id
FROM distributor_ocr_products 
LIMIT 1;

-- استخدم الـ IDs من النتيجة في:
-- SELECT increment_ocr_product_views('DISTRIBUTOR_ID', 'OCR_PRODUCT_ID');

-- تحقق
-- SELECT distributor_id, ocr_product_id, views 
-- FROM distributor_ocr_products 
-- WHERE ocr_product_id = 'OCR_PRODUCT_ID';


-- 6️⃣ إعادة إنشاء Function بشكل مبسط
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
DECLARE
    v_rows_affected INTEGER;
BEGIN
    -- امسح الـ prefix "ocr_" إذا كان موجوداً
    IF p_ocr_product_id LIKE 'ocr_%' THEN
        p_ocr_product_id := substring(p_ocr_product_id from 5);
    END IF;
    
    -- جرب UPDATE مع تحويل كلا الـ IDs إلى TEXT
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id
    AND ocr_product_id::TEXT = p_ocr_product_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RAISE NOTICE 'OCR Views: Updated % rows for dist:% ocr:%', 
        v_rows_affected, p_distributor_id, p_ocr_product_id;
    
    -- إذا لم ينجح، جرب تحويل parameters إلى UUID
    IF v_rows_affected = 0 THEN
        BEGIN
            UPDATE distributor_ocr_products 
            SET views = COALESCE(views, 0) + 1 
            WHERE distributor_id = p_distributor_id::UUID
            AND ocr_product_id = p_ocr_product_id::UUID;
            
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            RAISE NOTICE 'OCR Views (UUID): Updated % rows', v_rows_affected;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'OCR Views Error: %', SQLERRM;
        END;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;


-- 7️⃣ اختبار Function الجديدة
-- ==========================================
UPDATE distributor_ocr_products SET views = 0;

-- احصل على IDs حقيقية
SELECT 
    distributor_id::TEXT as dist_id,
    ocr_product_id as ocr_id,
    views
FROM distributor_ocr_products 
LIMIT 1;

-- استخدم الـ IDs هنا (استبدل DIST_ID و OCR_ID بالقيم الحقيقية)
-- SELECT increment_ocr_product_views('DIST_ID', 'OCR_ID');
-- SELECT distributor_id, ocr_product_id, views FROM distributor_ocr_products WHERE ocr_product_id = 'OCR_ID';


-- ==========================================
-- تعليمات الاستخدام:
-- ==========================================
-- 1. شغل الخطوات 1-4 لفهم بنية الجدول
-- 2. شغل الخطوة 6 لإعادة إنشاء Function
-- 3. شغل الخطوة 7 واستخدم IDs حقيقية للاختبار
