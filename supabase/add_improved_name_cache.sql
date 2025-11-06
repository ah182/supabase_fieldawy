-- إضافة نظام Cache للأسماء المحسّنة في جدول search_tracking
-- Add improved name cache system to search_tracking table

-- 1. إضافة عمود improved_name لحفظ الأسماء المحسّنة
-- Add improved_name column to store cached improved names
ALTER TABLE search_tracking 
ADD COLUMN IF NOT EXISTS improved_name TEXT;

-- 2. إضافة عمود improvement_score لحفظ درجة التطابق
-- Add improvement_score column to store match score
ALTER TABLE search_tracking 
ADD COLUMN IF NOT EXISTS improvement_score INTEGER DEFAULT 0;

-- 3. إضافة عمود last_improved_at لتتبع آخر تحديث
-- Add last_improved_at column to track last improvement update
ALTER TABLE search_tracking 
ADD COLUMN IF NOT EXISTS last_improved_at TIMESTAMP WITH TIME ZONE;

-- 4. إنشاء فهرس للبحث السريع بالأسماء المحسّنة
-- Create index for fast search by improved names
CREATE INDEX IF NOT EXISTS idx_search_tracking_improved_name 
ON search_tracking(improved_name) 
WHERE improved_name IS NOT NULL;

-- 5. إنشاء فهرس مركب للبحث بالمصطلح الأصلي والاسم المحسّن
-- Create composite index for search by original term and improved name
CREATE INDEX IF NOT EXISTS idx_search_tracking_term_improved 
ON search_tracking(search_term, improved_name);

-- 6. دالة لتحديث الاسم المحسّن
-- Function to update improved name
CREATE OR REPLACE FUNCTION update_improved_search_name(
    p_search_term TEXT,
    p_improved_name TEXT,
    p_improvement_score INTEGER DEFAULT 0
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- تحديث جميع السجلات التي تحتوي على نفس المصطلح
    UPDATE search_tracking 
    SET 
        improved_name = p_improved_name,
        improvement_score = p_improvement_score,
        last_improved_at = NOW()
    WHERE LOWER(TRIM(search_term)) = LOWER(TRIM(p_search_term))
      AND (improved_name IS NULL OR improvement_score < p_improvement_score);
    
    RETURN FOUND;
END;
$$;

-- 7. دالة للحصول على الاسم المحسّن من الـ Cache
-- Function to get improved name from cache
CREATE OR REPLACE FUNCTION get_cached_improved_name(
    p_search_term TEXT
)
RETURNS TABLE (
    improved_name TEXT,
    improvement_score INTEGER,
    usage_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        st.improved_name,
        st.improvement_score,
        COUNT(*) as usage_count
    FROM search_tracking st
    WHERE LOWER(TRIM(st.search_term)) = LOWER(TRIM(p_search_term))
      AND st.improved_name IS NOT NULL
    GROUP BY st.improved_name, st.improvement_score
    ORDER BY st.improvement_score DESC, COUNT(*) DESC
    LIMIT 1;
END;
$$;

-- 8. دالة محسّنة للحصول على أفضل مصطلحات البحث مع الأسماء المحسّنة
-- Optimized function to get top search terms with improved names
CREATE OR REPLACE FUNCTION get_top_search_terms_cached(
    p_limit INTEGER DEFAULT 10,
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE (
    search_term TEXT,
    improved_name TEXT,
    search_count BIGINT,
    unique_users BIGINT,
    avg_result_count NUMERIC,
    improvement_score INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    start_date TIMESTAMP WITH TIME ZONE;
BEGIN
    start_date := NOW() - (p_days || ' days')::INTERVAL;
    
    RETURN QUERY
    SELECT 
        st.search_term,
        COALESCE(st.improved_name, st.search_term) as improved_name,
        COUNT(*) as search_count,
        COUNT(DISTINCT st.user_id) as unique_users,
        AVG(st.result_count) as avg_result_count,
        MAX(st.improvement_score) as improvement_score
    FROM search_tracking st
    WHERE st.created_at >= start_date
    GROUP BY st.search_term, st.improved_name
    ORDER BY search_count DESC
    LIMIT p_limit;
END;
$$;

-- 9. إعطاء صلاحيات للدوال الجديدة
-- Grant permissions for new functions
GRANT EXECUTE ON FUNCTION update_improved_search_name TO authenticated;
GRANT EXECUTE ON FUNCTION get_cached_improved_name TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_search_terms_cached TO authenticated;

-- 10. رسالة نجاح
-- Success message
SELECT '✅ تم إضافة نظام Cache للأسماء المحسّنة بنجاح!' as status;

-- 11. عرض إحصائيات الجدول المحدث
-- Show updated table statistics
SELECT 
    'search_tracking table updated' as info,
    COUNT(*) as total_records,
    COUNT(improved_name) as records_with_improved_names,
    COUNT(DISTINCT search_term) as unique_search_terms
FROM search_tracking;

