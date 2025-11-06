-- تحسين الأسماء تلقائياً عند البحث
-- Auto-improve search names on insert

-- 1. دالة لتحسين اسم المنتج من جداول الموزع فقط
-- Function to improve product name from distributor tables only
CREATE OR REPLACE FUNCTION auto_improve_search_term(
    p_search_term TEXT,
    p_search_type VARCHAR(50) DEFAULT 'products',
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    improved_name TEXT,
    improvement_score INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_improved_name TEXT;
    v_score INTEGER;
    v_clean_term TEXT;
    v_user_id UUID;
BEGIN
    -- تنظيف المصطلح
    v_clean_term := LOWER(TRIM(p_search_term));
    v_improved_name := p_search_term;
    v_score := 0;

    -- استخدام user_id من المعامل أو من الجلسة الحالية
    v_user_id := COALESCE(p_user_id, auth.uid());

    -- البحث في جدول distributor_products (منتجات الموزع)
    IF p_search_type IN ('products', 'general') AND v_user_id IS NOT NULL THEN
        SELECT dp.name, 100
        INTO v_improved_name, v_score
        FROM distributor_products dp
        WHERE dp.distributor_id = v_user_id
          AND LOWER(dp.name) LIKE '%' || v_clean_term || '%'
        ORDER BY
            CASE
                WHEN LOWER(dp.name) = v_clean_term THEN 1
                WHEN LOWER(dp.name) LIKE v_clean_term || '%' THEN 2
                WHEN LOWER(dp.name) LIKE '%' || v_clean_term || '%' THEN 3
                ELSE 4
            END,
            LENGTH(dp.name) ASC
        LIMIT 1;

        IF v_score > 0 THEN
            RETURN QUERY SELECT v_improved_name, v_score;
            RETURN;
        END IF;
    END IF;

    -- البحث في جدول distributor_ocr_products (منتجات OCR للموزع)
    IF v_user_id IS NOT NULL THEN
        SELECT dop.product_name, 95
        INTO v_improved_name, v_score
        FROM distributor_ocr_products dop
        WHERE dop.distributor_id = v_user_id
          AND LOWER(dop.product_name) LIKE '%' || v_clean_term || '%'
        ORDER BY
            CASE
                WHEN LOWER(dop.product_name) = v_clean_term THEN 1
                WHEN LOWER(dop.product_name) LIKE v_clean_term || '%' THEN 2
                WHEN LOWER(dop.product_name) LIKE '%' || v_clean_term || '%' THEN 3
                ELSE 4
            END,
            LENGTH(dop.product_name) ASC
        LIMIT 1;

        IF v_score > 0 THEN
            RETURN QUERY SELECT v_improved_name, v_score;
            RETURN;
        END IF;
    END IF;

    -- البحث في جدول vet_supplies (للأدوية البيطرية)
    IF p_search_type IN ('vet_supplies', 'general') THEN
        SELECT vs.name, 90
        INTO v_improved_name, v_score
        FROM vet_supplies vs
        WHERE LOWER(vs.name) LIKE '%' || v_clean_term || '%'
        ORDER BY
            CASE
                WHEN LOWER(vs.name) = v_clean_term THEN 1
                WHEN LOWER(vs.name) LIKE v_clean_term || '%' THEN 2
                WHEN LOWER(vs.name) LIKE '%' || v_clean_term || '%' THEN 3
                ELSE 4
            END,
            LENGTH(vs.name) ASC
        LIMIT 1;

        IF v_score > 0 THEN
            RETURN QUERY SELECT v_improved_name, v_score;
            RETURN;
        END IF;
    END IF;

    -- إذا لم نجد شيء، نرجع الاسم الأصلي
    RETURN QUERY SELECT p_search_term, 0;
END;
$$;

-- 2. تحديث دالة log_search_activity لتحسين الاسم تلقائياً
-- Update log_search_activity to auto-improve names
CREATE OR REPLACE FUNCTION log_search_activity(
    p_user_id UUID,
    p_search_term TEXT,
    p_search_type VARCHAR(50) DEFAULT 'general',
    p_search_location TEXT DEFAULT NULL,
    p_result_count INTEGER DEFAULT 0,
    p_session_id TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    search_id BIGINT;
    v_improved_name TEXT;
    v_improvement_score INTEGER;
BEGIN
    -- تحسين اسم المصطلح تلقائياً (مع تمرير user_id)
    SELECT improved_name, improvement_score
    INTO v_improved_name, v_improvement_score
    FROM auto_improve_search_term(p_search_term, p_search_type, p_user_id);

    -- تسجيل عملية البحث مع الاسم المحسّن
    INSERT INTO search_tracking (
        user_id,
        search_term,
        search_type,
        search_location,
        result_count,
        session_id,
        improved_name,
        improvement_score,
        last_improved_at
    )
    VALUES (
        p_user_id,
        LOWER(TRIM(p_search_term)),
        p_search_type,
        p_search_location,
        p_result_count,
        p_session_id,
        v_improved_name,
        v_improvement_score,
        NOW()
    )
    RETURNING id INTO search_id;

    RETURN search_id;
END;
$$;

-- 3. إعطاء صلاحيات
-- Grant permissions
GRANT EXECUTE ON FUNCTION auto_improve_search_term TO authenticated;
GRANT EXECUTE ON FUNCTION log_search_activity TO authenticated;

-- 4. تحديث السجلات القديمة (اختياري)
-- Update old records (optional)
DO $$
DECLARE
    v_record RECORD;
    v_improved_name TEXT;
    v_score INTEGER;
BEGIN
    FOR v_record IN
        SELECT DISTINCT search_term, search_type, user_id
        FROM search_tracking
        WHERE improved_name IS NULL
        LIMIT 50
    LOOP
        SELECT improved_name, improvement_score
        INTO v_improved_name, v_score
        FROM auto_improve_search_term(v_record.search_term, v_record.search_type, v_record.user_id);

        IF v_score > 0 THEN
            UPDATE search_tracking
            SET
                improved_name = v_improved_name,
                improvement_score = v_score,
                last_improved_at = NOW()
            WHERE search_term = v_record.search_term
              AND search_type = v_record.search_type
              AND user_id = v_record.user_id
              AND improved_name IS NULL;
        END IF;
    END LOOP;
END $$;

-- 5. رسالة نجاح
-- Success message
SELECT '✅ تم تفعيل التحسين التلقائي للأسماء عند البحث!' as status;

