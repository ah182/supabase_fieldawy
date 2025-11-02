-- تشخيص وإصلاح مشكلة عدم جلب البيانات الحقيقية من search_tracking
-- Debug and fix real data not being fetched from search_tracking

-- 1. التحقق من وجود الجدول والدالة
-- Check if table and function exist
SELECT 
    'search_tracking table exists' as status,
    COUNT(*) as total_records
FROM search_tracking;

SELECT 
    'get_top_search_terms function exists' as status,
    COUNT(*) as function_count
FROM information_schema.routines 
WHERE routine_name = 'get_top_search_terms';

-- 2. فحص محتوى جدول search_tracking
-- Examine search_tracking table content
SELECT 
    'Recent search data' as section,
    COUNT(*) as total_searches,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT search_term) as unique_terms
FROM search_tracking
WHERE created_at >= NOW() - INTERVAL '7 days';

-- عرض آخر 10 عمليات بحث
-- Show last 10 searches
SELECT 
    id,
    user_id,
    search_term,
    search_type,
    result_count,
    created_at
FROM search_tracking 
ORDER BY created_at DESC 
LIMIT 10;

-- 3. اختبار دالة get_top_search_terms
-- Test get_top_search_terms function
SELECT 'Testing get_top_search_terms function' as test_status;

-- اختبار الدالة مع معاملات مختلفة
SELECT * FROM get_top_search_terms(10, 30, 'products');
SELECT * FROM get_top_search_terms(5, 7, NULL);

-- 4. إدراج بيانات تجريبية إذا كان الجدول فارغ
-- Insert test data if table is empty
DO $$
DECLARE
    current_user_id UUID;
    search_count INTEGER;
BEGIN
    -- التحقق من عدد السجلات الحالية
    SELECT COUNT(*) INTO search_count FROM search_tracking;
    
    IF search_count < 5 THEN
        -- الحصول على أول مستخدم متاح
        SELECT id INTO current_user_id 
        FROM auth.users 
        LIMIT 1;
        
        IF current_user_id IS NOT NULL THEN
            -- إدراج بيانات تجريبية
            INSERT INTO search_tracking (user_id, search_term, search_type, search_location, result_count, session_id)
            VALUES 
            (current_user_id, 'مضاد حيوي', 'products', 'القاهرة', 15, 'test_session_1'),
            (current_user_id, 'فيتامينات', 'products', 'القاهرة', 23, 'test_session_2'),
            (current_user_id, 'أدوية قطط', 'products', 'الجيزة', 8, 'test_session_3'),
            (current_user_id, 'حقن بيطرية', 'products', 'الإسكندرية', 12, 'test_session_4'),
            (current_user_id, 'علاج التهابات', 'products', 'القاهرة', 19, 'test_session_5'),
            (current_user_id, 'مسكنات ألم', 'products', 'الدقهلية', 7, 'test_session_6'),
            (current_user_id, 'أدوية كلاب', 'products', 'الشرقية', 14, 'test_session_7'),
            (current_user_id, 'مطهرات جروح', 'products', 'القاهرة', 11, 'test_session_8'),
            (current_user_id, 'أموكسيسيلين', 'products', 'الغربية', 25, 'test_session_9'),
            (current_user_id, 'إنروفلوكساسين', 'products', 'المنوفية', 9, 'test_session_10'),
            (current_user_id, 'دوكسيسيكلين', 'products', 'القاهرة', 17, 'test_session_11'),
            (current_user_id, 'سيفالكسين', 'products', 'الجيزة', 13, 'test_session_12');
            
            RAISE NOTICE 'تم إدراج % سجل تجريبي في search_tracking', 12;
        ELSE
            RAISE NOTICE 'لا يوجد مستخدمين في النظام لإدراج بيانات تجريبية';
        END IF;
    ELSE
        RAISE NOTICE 'الجدول يحتوي على % سجل، لا حاجة لإدراج بيانات تجريبية', search_count;
    END IF;
END $$;

-- 5. اختبار الدالة مرة أخرى بعد إدراج البيانات
-- Test function again after inserting data
SELECT 'After inserting test data:' as status;

SELECT 
    search_term,
    search_count,
    unique_users,
    click_rate,
    trend_direction,
    growth_percentage
FROM get_top_search_terms(15, 7, 'products');

-- 6. التحقق من صلاحيات الدالة
-- Check function permissions
SELECT 
    routine_name,
    routine_type,
    security_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'get_top_search_terms';

-- 7. فحص RLS policies
-- Check RLS policies
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'search_tracking';

-- 8. اختبار الاستعلام المباشر
-- Test direct query
SELECT 
    search_term,
    COUNT(*) as search_count,
    COUNT(DISTINCT user_id) as unique_users,
    AVG(result_count) as avg_results
FROM search_tracking 
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND search_type = 'products'
GROUP BY search_term
ORDER BY search_count DESC
LIMIT 10;

-- عرض النتيجة النهائية
SELECT 
    'Search tracking system status' as status,
    CASE 
        WHEN COUNT(*) > 0 THEN 'جاهز ويعمل'
        ELSE 'يحتاج لبيانات'
    END as result
FROM search_tracking;