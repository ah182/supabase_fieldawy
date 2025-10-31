-- ===================================================================
-- تشخيص شامل لمشكلة عدم زيادة المشاهدات في قاعدة البيانات
-- ===================================================================

-- ===================================================================
-- 1. فحص الدوال الموجودة
-- ===================================================================

SELECT 'CHECKING EXISTING FUNCTIONS' as step;

SELECT 
    routine_name,
    specific_name,
    routine_type,
    data_type as return_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('increment_job_views', 'increment_vet_supply_views')
ORDER BY routine_name, specific_name;

-- ===================================================================
-- 2. اختبار مباشر للدوال مع IDs حقيقية
-- ===================================================================

SELECT 'TESTING FUNCTIONS WITH REAL IDs' as step;

-- اختبار دالة الوظائف
DO $$
DECLARE
    test_job_id TEXT;
    views_before INTEGER;
    views_after INTEGER;
BEGIN
    -- الحصول على أول وظيفة
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_job_id, views_before 
    FROM job_offers 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        RAISE NOTICE '=== TESTING JOB VIEWS ===';
        RAISE NOTICE 'Job ID: %', test_job_id;
        RAISE NOTICE 'Views before: %', views_before;
        
        -- استدعاء الدالة
        BEGIN
            PERFORM increment_job_views(test_job_id);
            RAISE NOTICE 'Function call successful';
        EXCEPTION 
            WHEN OTHERS THEN
                RAISE NOTICE 'Function call failed: %', SQLERRM;
        END;
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO views_after 
        FROM job_offers 
        WHERE id::TEXT = test_job_id;
        
        RAISE NOTICE 'Views after: %', views_after;
        
        IF views_after > views_before THEN
            RAISE NOTICE '✅ SUCCESS: Job views increased!';
        ELSE
            RAISE NOTICE '❌ FAILED: Job views did not increase';
        END IF;
    ELSE
        RAISE NOTICE 'No job offers found';
    END IF;
END $$;

-- اختبار دالة المستلزمات
DO $$
DECLARE
    test_supply_id TEXT;
    views_before INTEGER;
    views_after INTEGER;
BEGIN
    -- الحصول على أول مستلزم
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_supply_id, views_before 
    FROM vet_supplies 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        RAISE NOTICE '=== TESTING SUPPLY VIEWS ===';
        RAISE NOTICE 'Supply ID: %', test_supply_id;
        RAISE NOTICE 'Views before: %', views_before;
        
        -- استدعاء الدالة
        BEGIN
            PERFORM increment_vet_supply_views(test_supply_id);
            RAISE NOTICE 'Function call successful';
        EXCEPTION 
            WHEN OTHERS THEN
                RAISE NOTICE 'Function call failed: %', SQLERRM;
        END;
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO views_after 
        FROM vet_supplies 
        WHERE id::TEXT = test_supply_id;
        
        RAISE NOTICE 'Views after: %', views_after;
        
        IF views_after > views_before THEN
            RAISE NOTICE '✅ SUCCESS: Supply views increased!';
        ELSE
            RAISE NOTICE '❌ FAILED: Supply views did not increase';
        END IF;
    ELSE
        RAISE NOTICE 'No vet supplies found';
    END IF;
END $$;

-- ===================================================================
-- 3. فحص البيانات الحالية
-- ===================================================================

SELECT 'CURRENT DATA SAMPLE' as step;

-- آخر الوظائف
SELECT 
    'job_offers - latest records' as table_info,
    id,
    title,
    views_count,
    updated_at
FROM job_offers 
ORDER BY updated_at DESC 
LIMIT 5;

-- آخر المستلزمات
SELECT 
    'vet_supplies - latest records' as table_info,
    id,
    name,
    views_count,
    updated_at
FROM vet_supplies 
ORDER BY updated_at DESC 
LIMIT 5;

-- ===================================================================
-- 4. محاولة تحديث مباشر للتأكد من الصلاحيات
-- ===================================================================

SELECT 'TESTING DIRECT UPDATE' as step;

-- محاولة تحديث مباشر لوظيفة
DO $$
DECLARE
    test_job_id UUID;
    old_count INTEGER;
    new_count INTEGER;
BEGIN
    -- الحصول على ID
    SELECT id, COALESCE(views_count, 0) 
    INTO test_job_id, old_count 
    FROM job_offers 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        RAISE NOTICE 'Testing direct UPDATE on job ID: %', test_job_id;
        RAISE NOTICE 'Current views_count: %', old_count;
        
        -- تحديث مباشر
        UPDATE job_offers 
        SET views_count = COALESCE(views_count, 0) + 1,
            updated_at = NOW()
        WHERE id = test_job_id;
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO new_count 
        FROM job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'Views after direct UPDATE: %', new_count;
        
        IF new_count > old_count THEN
            RAISE NOTICE '✅ Direct UPDATE works - permissions OK';
        ELSE
            RAISE NOTICE '❌ Direct UPDATE failed - permission issue?';
        END IF;
    END IF;
END $$;

-- ===================================================================
-- 5. فحص RLS policies
-- ===================================================================

SELECT 'CHECKING RLS POLICIES' as step;

SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('job_offers', 'vet_supplies')
ORDER BY tablename, policyname;

-- ===================================================================
-- 6. نتيجة التشخيص
-- ===================================================================

SELECT 
    'DIAGNOSIS COMPLETED' as status,
    'Check the notices above for detailed results' as instruction,
    'Focus on any FAILED messages or permission errors' as focus;