-- ==========================================
-- اختبار وإصلاح مشكلة عدم زيادة views
-- ==========================================

-- 1️⃣ تحقق من نوع عمود id
-- ==========================================
SELECT 
    table_name,
    column_name, 
    data_type,
    udt_name
FROM information_schema.columns 
WHERE table_name = 'distributor_products' 
AND column_name = 'id';

-- النتيجة المتوقعة:
-- إذا كان integer → data_type = integer
-- إذا كان uuid → data_type = uuid


-- 2️⃣ اختبر UPDATE يدوياً مع أنواع مختلفة
-- ==========================================

-- للـ Integer IDs (مثل 649, 592, 92)
UPDATE distributor_products 
SET views = COALESCE(views, 0) + 1 
WHERE id = 649;

-- تحقق
SELECT id, name, views FROM distributor_products WHERE id = 649;


-- للـ UUID IDs (مثل dea0660b-bbb1-4385-bf1e-454daabe0b6a)
UPDATE distributor_products 
SET views = COALESCE(views, 0) + 1 
WHERE id = 'dea0660b-bbb1-4385-bf1e-454daabe0b6a'::uuid;

-- تحقق
SELECT id, name, views 
FROM distributor_products 
WHERE id = 'dea0660b-bbb1-4385-bf1e-454daabe0b6a'::uuid;


-- 3️⃣ اختبر مع TEXT casting
-- ==========================================

-- Integer ID
UPDATE distributor_products 
SET views = COALESCE(views, 0) + 1 
WHERE id::TEXT = '649';

SELECT id, name, views FROM distributor_products WHERE id::TEXT = '649';


-- UUID ID
UPDATE distributor_products 
SET views = COALESCE(views, 0) + 1 
WHERE id::TEXT = 'dea0660b-bbb1-4385-bf1e-454daabe0b6a';

SELECT id, name, views 
FROM distributor_products 
WHERE id::TEXT = 'dea0660b-bbb1-4385-bf1e-454daabe0b6a';


-- 4️⃣ إصلاح Function - نسخة محسنة
-- ==========================================

DROP FUNCTION IF EXISTS increment_product_views(TEXT);

CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- محاولة UPDATE
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_product_id;
    
    -- حفظ عدد الصفوف المتأثرة
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- Log للتشخيص (اختياري)
    RAISE NOTICE 'Updated % rows for product_id: %', rows_affected, p_product_id;
    
    -- إذا لم يتم تحديث أي صف، جرب بدون casting
    IF rows_affected = 0 THEN
        -- جرب مباشرة للـ integer
        BEGIN
            UPDATE distributor_products 
            SET views = COALESCE(views, 0) + 1 
            WHERE id = p_product_id::INTEGER;
            
            GET DIAGNOSTICS rows_affected = ROW_COUNT;
            RAISE NOTICE 'Updated % rows (as integer) for product_id: %', rows_affected, p_product_id;
        EXCEPTION
            WHEN OTHERS THEN
                -- إذا فشل integer، جرب UUID
                BEGIN
                    UPDATE distributor_products 
                    SET views = COALESCE(views, 0) + 1 
                    WHERE id = p_product_id::UUID;
                    
                    GET DIAGNOSTICS rows_affected = ROW_COUNT;
                    RAISE NOTICE 'Updated % rows (as uuid) for product_id: %', rows_affected, p_product_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE 'Failed to update product_id: %', p_product_id;
                END;
        END;
    END IF;
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;


-- 5️⃣ اختبار Function المحسنة
-- ==========================================

-- للـ Integer
SELECT increment_product_views('649');
SELECT id, name, views FROM distributor_products WHERE id::TEXT = '649';

-- للـ UUID
SELECT increment_product_views('dea0660b-bbb1-4385-bf1e-454daabe0b6a');
SELECT id, name, views 
FROM distributor_products 
WHERE id::TEXT = 'dea0660b-bbb1-4385-bf1e-454daabe0b6a';


-- 6️⃣ بديل أبسط (إذا الأول لم يعمل)
-- ==========================================

DROP FUNCTION IF EXISTS increment_product_views(TEXT);

CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS TABLE(success BOOLEAN, message TEXT)
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
DECLARE
    v_id_type TEXT;
BEGIN
    -- تحديد نوع ID
    SELECT data_type INTO v_id_type
    FROM information_schema.columns 
    WHERE table_name = 'distributor_products' 
    AND column_name = 'id';
    
    -- UPDATE حسب النوع
    IF v_id_type = 'integer' OR v_id_type = 'bigint' THEN
        UPDATE distributor_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE id::TEXT = p_product_id;
    ELSIF v_id_type = 'uuid' THEN
        UPDATE distributor_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE id::TEXT = p_product_id;
    ELSE
        RETURN QUERY SELECT FALSE, 'Unknown id type: ' || v_id_type;
        RETURN;
    END IF;
    
    IF FOUND THEN
        RETURN QUERY SELECT TRUE, 'Views incremented for ' || p_product_id;
    ELSE
        RETURN QUERY SELECT FALSE, 'No product found with id: ' || p_product_id;
    END IF;
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;


-- ==========================================
-- ✅ اختر أحد الحلين أعلاه وطبقه
-- ==========================================
