-- Fix UUID error in search tracking system
-- The issue is that log_search_activity function returns UUID but id column is BIGSERIAL

-- Drop the existing function first
DROP FUNCTION IF EXISTS log_search_activity(UUID, TEXT, VARCHAR(50), TEXT, INTEGER, TEXT);

-- Recreate the function with correct return type (BIGINT instead of UUID)
CREATE OR REPLACE FUNCTION log_search_activity(
    p_user_id UUID,
    p_search_term TEXT,
    p_search_type VARCHAR(50) DEFAULT 'general',
    p_search_location TEXT DEFAULT NULL,
    p_result_count INTEGER DEFAULT 0,
    p_session_id TEXT DEFAULT NULL
)
RETURNS BIGINT  -- Changed from UUID to BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    search_id BIGINT;  -- Changed from UUID to BIGINT
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

-- Also fix the update_search_click function to use BIGINT for search_id
DROP FUNCTION IF EXISTS update_search_click(UUID, UUID);

CREATE OR REPLACE FUNCTION update_search_click(
    p_search_id BIGINT,  -- Changed from UUID to BIGINT
    p_clicked_result_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE search_tracking 
    SET 
        clicked_result_id = p_clicked_result_id,
        updated_at = NOW()
    WHERE id = p_search_id;
    
    RETURN FOUND;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION log_search_activity TO authenticated;
GRANT EXECUTE ON FUNCTION update_search_click TO authenticated;

-- Test the fix
SELECT 'تم إصلاح خطأ UUID في نظام تتبع البحث بنجاح!' as status;