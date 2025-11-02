-- إصلاح مشكلة UUID في نظام تتبع البحث
-- Fix UUID issue in search tracking system

-- 1. تغيير نوع العمود clicked_result_id من UUID إلى TEXT
ALTER TABLE search_tracking ALTER COLUMN clicked_result_id TYPE TEXT;

-- 2. حذف وإعادة إنشاء دالة log_search_activity لترجع BIGINT بدلاً من UUID
DROP FUNCTION IF EXISTS log_search_activity(UUID, TEXT, VARCHAR, TEXT, INTEGER, TEXT);

CREATE OR REPLACE FUNCTION log_search_activity(
    p_user_id UUID,
    p_search_term TEXT,
    p_search_type VARCHAR(50) DEFAULT 'general',
    p_search_location TEXT DEFAULT NULL,
    p_result_count INTEGER DEFAULT 0,
    p_session_id TEXT DEFAULT NULL
)
RETURNS BIGINT  -- تغيير من UUID إلى BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    search_id BIGINT;  -- تغيير من UUID إلى BIGINT
BEGIN
    -- تسجيل عملية البحث
    INSERT INTO search_tracking (
        user_id, 
        search_term, 
        search_type,
        search_location,
        result_count,
        session_id
    )
    VALUES (
        p_user_id, 
        LOWER(TRIM(p_search_term)), 
        p_search_type,
        p_search_location,
        p_result_count,
        p_session_id
    )
    RETURNING id INTO search_id;
    
    RETURN search_id;
END;
$$;

-- 2. حذف الدالة القديمة وإنشاء دالة جديدة بمعاملات مختلفة
DROP FUNCTION IF EXISTS update_search_click(UUID, UUID);
DROP FUNCTION IF EXISTS update_search_click(UUID, TEXT);
DROP FUNCTION IF EXISTS update_search_click(BIGINT, UUID);

-- إنشاء الدالة المحدثة
CREATE OR REPLACE FUNCTION update_search_click(
    p_search_id BIGINT,  -- تغيير من UUID إلى BIGINT
    p_clicked_result_id TEXT  -- TEXT لدعم أنواع مختلفة من المعرفات
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE search_tracking 
    SET 
        clicked_result_id = p_clicked_result_id,  -- حفظ مباشر كـ TEXT
        updated_at = NOW()
    WHERE id = p_search_id;
    
    RETURN FOUND;
END;
$$;

-- 3. إعطاء صلاحيات للدوال المحدثة
GRANT EXECUTE ON FUNCTION log_search_activity TO authenticated;
GRANT EXECUTE ON FUNCTION update_search_click TO authenticated;

-- إظهار رسالة نجاح
SELECT 'تم إصلاح مشكلة UUID في نظام تتبع البحث بنجاح!' as status;

-- التحقق من الدوال المحدثة
SELECT 
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND p.proname IN ('log_search_activity', 'update_search_click')
ORDER BY p.proname;