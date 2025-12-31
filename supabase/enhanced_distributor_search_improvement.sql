-- تحسين البحث من جداول الموزعين لجميع الموزعين
-- Enhanced Search Improvement from ALL distributors' tables

-- 1. دالة محسّنة للبحث في جداول جميع الموزعين
-- Enhanced function to search across ALL distributors' tables
CREATE OR REPLACE FUNCTION auto_improve_search_term_from_distributors(
    p_search_term TEXT,
    p_search_type VARCHAR(50) DEFAULT 'products',
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    improved_name TEXT,
    improvement_score INTEGER,
    source_table TEXT,
    distributor_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_improved_name TEXT;
    v_score INTEGER;
    v_clean_term TEXT;
    v_source_table TEXT;
    v_distributor_count INTEGER;
BEGIN
    -- تنظيف المصطلح
    v_clean_term := LOWER(TRIM(p_search_term));
    v_improved_name := p_search_term;
    v_score := 0;
    v_source_table := '';
    v_distributor_count := 0;

    -- 1. البحث في جدول distributor_products (أعلى أولوية)
    -- Search in distributor_products (highest priority)
    IF p_search_type IN ('products', 'general') THEN
        SELECT 
            p.name, 
            100,
            'distributor_products',
            COUNT(DISTINCT dp.distributor_id)::INTEGER
        INTO v_improved_name, v_score, v_source_table, v_distributor_count
        FROM distributor_products dp
        JOIN products p ON dp.product_id = p.id
        WHERE LOWER(p.name) LIKE '%' || v_clean_term || '%'
        GROUP BY p.name
        ORDER BY
            COUNT(DISTINCT dp.distributor_id) DESC, -- أكثر الأسماء انتشاراً بين الموزعين
            CASE
                WHEN LOWER(p.name) = v_clean_term THEN 1
                WHEN LOWER(p.name) LIKE v_clean_term || '%' THEN 2
                WHEN LOWER(p.name) LIKE '%' || v_clean_term || '%' THEN 3
                ELSE 4
            END,
            LENGTH(p.name) ASC
        LIMIT 1;

        IF v_score > 0 THEN
            RETURN QUERY SELECT v_improved_name, v_score, v_source_table, v_distributor_count;
            RETURN;
        END IF;
    END IF;

    -- 2. البحث في جدول distributor_ocr_products
    -- Search in distributor_ocr_products
    SELECT 
        op.product_name, 
        95,
        'distributor_ocr_products',
        COUNT(DISTINCT dop.distributor_id)::INTEGER
    INTO v_improved_name, v_score, v_source_table, v_distributor_count
    FROM distributor_ocr_products dop
    JOIN ocr_products op ON dop.ocr_product_id = op.id
    WHERE LOWER(op.product_name) LIKE '%' || v_clean_term || '%'
    GROUP BY op.product_name
    ORDER BY
        COUNT(DISTINCT dop.distributor_id) DESC,
        CASE
            WHEN LOWER(op.product_name) = v_clean_term THEN 1
            WHEN LOWER(op.product_name) LIKE v_clean_term || '%' THEN 2
            WHEN LOWER(op.product_name) LIKE '%' || v_clean_term || '%' THEN 3
            ELSE 4
        END,
        LENGTH(op.product_name) ASC
    LIMIT 1;

    IF v_score > 0 THEN
        RETURN QUERY SELECT v_improved_name, v_score, v_source_table, v_distributor_count;
        RETURN;
    END IF;

    -- 3. البحث في جدول distributor_surgical_tools
    -- Search in distributor_surgical_tools
    SELECT 
        st.tool_name, 
        93,
        'distributor_surgical_tools',
        COUNT(DISTINCT dst.distributor_id)::INTEGER
    INTO v_improved_name, v_score, v_source_table, v_distributor_count
    FROM distributor_surgical_tools dst
    JOIN surgical_tools st ON dst.surgical_tool_id = st.id
    WHERE LOWER(st.tool_name) LIKE '%' || v_clean_term || '%'
    GROUP BY st.tool_name
    ORDER BY
        COUNT(DISTINCT dst.distributor_id) DESC,
        CASE
            WHEN LOWER(st.tool_name) = v_clean_term THEN 1
            WHEN LOWER(st.tool_name) LIKE v_clean_term || '%' THEN 2
            WHEN LOWER(st.tool_name) LIKE '%' || v_clean_term || '%' THEN 3
            ELSE 4
        END,
        LENGTH(st.tool_name) ASC
    LIMIT 1;

    IF v_score > 0 THEN
        RETURN QUERY SELECT v_improved_name, v_score, v_source_table, v_distributor_count;
        RETURN;
    END IF;

    -- 4. البحث في جدول vet_supplies (للأدوية البيطرية)
    -- Search in vet_supplies
    IF p_search_type IN ('vet_supplies', 'general') THEN
        SELECT 
            vs.name, 
            90,
            'vet_supplies',
            COUNT(DISTINCT vs.user_id)::INTEGER
        INTO v_improved_name, v_score, v_source_table, v_distributor_count
        FROM vet_supplies vs
        WHERE LOWER(vs.name) LIKE '%' || v_clean_term || '%'
        GROUP BY vs.name
        ORDER BY
            COUNT(DISTINCT vs.user_id) DESC,
            CASE
                WHEN LOWER(vs.name) = v_clean_term THEN 1
                WHEN LOWER(vs.name) LIKE v_clean_term || '%' THEN 2
                WHEN LOWER(vs.name) LIKE '%' || v_clean_term || '%' THEN 3
                ELSE 4
            END,
            LENGTH(vs.name) ASC
        LIMIT 1;

        IF v_score > 0 THEN
            RETURN QUERY SELECT v_improved_name, v_score, v_source_table, v_distributor_count;
            RETURN;
        END IF;
    END IF;

    -- إذا لم نجد شيء، نرجع الاسم الأصلي
    RETURN QUERY SELECT p_search_term, 0, 'none'::TEXT, 0;
END;
$$;

-- 2. دالة محسّنة لتسجيل البحث مع البيانات الإضافية
-- Enhanced function to log search with additional data
CREATE OR REPLACE FUNCTION log_search_activity_enhanced(
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
    v_source_table TEXT;
    v_distributor_count INTEGER;
BEGIN
    -- تحسين اسم المصطلح تلقائياً من جداول الموزعين
    SELECT improved_name, improvement_score, source_table, distributor_count
    INTO v_improved_name, v_improvement_score, v_source_table, v_distributor_count
    FROM auto_improve_search_term_from_distributors(p_search_term, p_search_type, p_user_id);

    -- تسجيل عملية البحث مع البيانات المحسّنة
    INSERT INTO search_tracking (
        user_id,
        search_term,
        search_type,
        search_location,
        result_count,
        session_id,
        improved_name,
        improvement_score,
        last_improved_at,
        source_table,
        distributor_count
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
        NOW(),
        v_source_table,
        v_distributor_count
    )
    RETURNING id INTO search_id;

    RETURN search_id;
END;
$$;

-- 3. إضافة الأعمدة الجديدة لجدول search_tracking إذا لم تكن موجودة
-- Add new columns to search_tracking if they don't exist
DO $$
BEGIN
    -- إضافة عمود source_table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'search_tracking' AND column_name = 'source_table'
    ) THEN
        ALTER TABLE search_tracking ADD COLUMN source_table TEXT;
    END IF;

    -- إضافة عمود distributor_count
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'search_tracking' AND column_name = 'distributor_count'
    ) THEN
        ALTER TABLE search_tracking ADD COLUMN distributor_count INTEGER DEFAULT 0;
    END IF;

    RAISE NOTICE 'تم إضافة الأعمدة الجديدة بنجاح';
END $$;

-- 4. دالة لجلب الترندات من البيانات الحقيقية
-- Function to get trends from real data
CREATE OR REPLACE FUNCTION get_real_search_trends(
    p_limit INTEGER DEFAULT 10,
    p_days_back INTEGER DEFAULT 7
)
RETURNS TABLE (
    keyword TEXT,
    original_term TEXT,
    search_count BIGINT,
    improvement_score INTEGER,
    source_table TEXT,
    distributor_count INTEGER,
    improved BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(st.improved_name, st.search_term) as keyword,
        st.search_term as original_term,
        COUNT(*) as search_count,
        MAX(st.improvement_score) as improvement_score,
        MAX(st.source_table) as source_table,
        MAX(st.distributor_count) as distributor_count,
        (MAX(st.improvement_score) > 0) as improved
    FROM search_tracking st
    WHERE st.created_at >= NOW() - INTERVAL '1 day' * p_days_back
    GROUP BY 
        COALESCE(st.improved_name, st.search_term),
        st.search_term
    ORDER BY search_count DESC
    LIMIT p_limit;
END;
$$;

-- 5. إعطاء صلاحيات للدوال الجديدة
-- Grant permissions for new functions
GRANT EXECUTE ON FUNCTION auto_improve_search_term_from_distributors TO authenticated;
GRANT EXECUTE ON FUNCTION log_search_activity_enhanced TO authenticated;
GRANT EXECUTE ON FUNCTION get_real_search_trends TO authenticated;

-- 6. رسالة نجاح
SELECT '✅ تم تفعيل النظام المحسّن لتحسين البحث من جداول الموزعين!' as status,
       '🔍 يمكنك الآن استخدام get_real_search_trends() لجلب البيانات الحقيقية' as instruction;