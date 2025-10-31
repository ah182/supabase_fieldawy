-- اختبار دالة زيادة المشاهدات للوظائف
-- نفذ هذا في Supabase SQL Editor

-- 1. التحقق من وجود الدالة
SELECT routine_name, routine_type, data_type
FROM information_schema.routines 
WHERE routine_name = 'increment_job_views'
AND routine_schema = 'public';

-- 2. عرض بعض الوظائف الموجودة
SELECT id, title, views_count, status, created_at
FROM job_offers 
WHERE status = 'active'
ORDER BY created_at DESC
LIMIT 5;

-- 3. اختبار الدالة مع أول وظيفة
DO $$
DECLARE
    test_job_id UUID;
    old_views INTEGER;
    new_views INTEGER;
BEGIN
    -- الحصول على أول وظيفة نشطة
    SELECT id, views_count INTO test_job_id, old_views
    FROM job_offers 
    WHERE status = 'active'
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF test_job_id IS NULL THEN
        RAISE NOTICE '❌ No active jobs found';
        RETURN;
    END IF;
    
    RAISE NOTICE '📝 Testing with job ID: %', test_job_id;
    RAISE NOTICE '📊 Current views: %', old_views;
    
    -- استدعاء دالة زيادة المشاهدات
    PERFORM increment_job_views(test_job_id);
    
    -- التحقق من النتيجة
    SELECT views_count INTO new_views
    FROM job_offers 
    WHERE id = test_job_id;
    
    RAISE NOTICE '📊 New views: %', new_views;
    
    IF new_views > old_views THEN
        RAISE NOTICE '🎉 SUCCESS: Views increased from % to %', old_views, new_views;
    ELSE
        RAISE NOTICE '❌ FAILED: Views did not increase';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error: %', SQLERRM;
END $$;

-- 4. عرض النتيجة النهائية
SELECT id, title, views_count, status
FROM job_offers 
WHERE status = 'active'
ORDER BY created_at DESC
LIMIT 3;