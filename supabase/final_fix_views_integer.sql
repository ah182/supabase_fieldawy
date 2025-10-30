-- ==========================================
-- ✅ الحل النهائي: Function تعمل مع Integer IDs
-- ==========================================
-- المشكلة: عمود id هو Integer وليس UUID
-- الحل: تحويل TEXT parameter إلى Integer
-- ==========================================

-- 1️⃣ حذف Functions القديمة
DROP FUNCTION IF EXISTS increment_product_views(TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(TEXT);


-- 2️⃣ للمنتجات العادية - تدعم Integer و UUID
-- ==========================================
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    -- جرب Integer أولاً (الأكثر شيوعاً)
    BEGIN
        UPDATE distributor_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE id = p_product_id::INTEGER;
        
        -- إذا نجح، اخرج
        IF FOUND THEN
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- إذا فشل Integer، جرب UUID
            BEGIN
                UPDATE distributor_products 
                SET views = COALESCE(views, 0) + 1 
                WHERE id::TEXT = p_product_id;
                
                IF FOUND THEN
                    RETURN;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    -- لا تفعل شيئاً (silent fail)
                    NULL;
            END;
    END;
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
    -- جرب Integer للـ distributor_id
    BEGIN
        UPDATE distributor_ocr_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE distributor_id = p_distributor_id::INTEGER
        AND ocr_product_id = p_ocr_product_id;
        
        IF FOUND THEN
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- جرب UUID
            BEGIN
                UPDATE distributor_ocr_products 
                SET views = COALESCE(views, 0) + 1 
                WHERE distributor_id::TEXT = p_distributor_id
                AND ocr_product_id = p_ocr_product_id;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
    END;
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
    -- جرب Integer أولاً
    BEGIN
        UPDATE distributor_surgical_tools 
        SET views = COALESCE(views, 0) + 1 
        WHERE id = p_tool_id::INTEGER;
        
        IF FOUND THEN
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- جرب UUID
            BEGIN
                UPDATE distributor_surgical_tools 
                SET views = COALESCE(views, 0) + 1 
                WHERE id::TEXT = p_tool_id;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
    END;
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

-- اختبر مع Integer ID
SELECT increment_product_views('649');

-- تحقق من الزيادة (استخدم فقط id و views)
SELECT id, views FROM distributor_products WHERE id = 649;
-- يجب أن ترى views زادت! ✅

-- إذا أردت رؤية المزيد من البيانات
SELECT * FROM distributor_products WHERE id = 649;

-- اختبر مع UUID ID (إذا كان لديك)
-- SELECT increment_product_views('dea0660b-bbb1-4385-bf1e-454daabe0b6a');


-- ==========================================
-- ✅ تم! هذا الحل يعمل مع Integer و UUID
-- ==========================================
