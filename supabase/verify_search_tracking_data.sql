-- التحقق من بيانات search_tracking والتوزيع الجغرافي

-- 1. عدد إجمالي السجلات
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT search_term) as unique_search_terms
FROM search_tracking;

-- 2. التوزيع الجغرافي (search_location)
SELECT 
    search_location,
    COUNT(*) as search_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT search_term) as unique_terms
FROM search_tracking
WHERE search_location IS NOT NULL 
  AND search_location != ''
GROUP BY search_location
ORDER BY search_count DESC
LIMIT 10;

-- 3. أحدث 10 عمليات بحث مع المواقع
SELECT 
    search_term,
    search_location,
    search_type,
    result_count,
    created_at
FROM search_tracking
WHERE search_location IS NOT NULL 
  AND search_location != ''
ORDER BY created_at DESC
LIMIT 10;

-- 4. أكثر الكلمات بحثاً مع التوزيع الجغرافي
SELECT 
    search_term,
    COUNT(*) as total_searches,
    COUNT(DISTINCT search_location) as locations_count,
    STRING_AGG(DISTINCT search_location, ', ') as locations
FROM search_tracking
WHERE search_location IS NOT NULL 
  AND search_location != ''
GROUP BY search_term
ORDER BY total_searches DESC
LIMIT 10;

-- 5. التحقق من RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'search_tracking';

-- 6. إحصائيات البيانات الأخيرة (آخر 7 أيام)
SELECT 
    DATE(created_at) as search_date,
    COUNT(*) as searches_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT search_location) as unique_locations
FROM search_tracking
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY search_date DESC;
