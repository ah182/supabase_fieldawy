-- ===================================================================
-- اختبار نهائي لدوال المشاهدات
-- ===================================================================

-- ===================================================================
-- 1. عرض الدوال المتاحة
-- ===================================================================

SELECT 'Available Functions:' as info;

SELECT 
    routine_name as function_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%increment%'
ORDER BY routine_name;

-- ===================================================================
-- 2. اختبار سريع مع بيانات حقيقية
-- ===================================================================

-- اختبار الوظائف
DO $$
DECLARE
    job_id TEXT;
    before_count INTEGER;
    after_count INTEGER;
BEGIN
    -- الحصول على أول وظيفة
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO job_id, before_count 
    FROM job_offers 
    LIMIT 1;
    
    IF job_id IS NOT NULL THEN
        RAISE NOTICE 'Testing job ID: %, current views: %', job_id, before_count;
        
        -- استدعاء الدالة
        PERFORM increment_job_views(job_id);
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO after_count 
        FROM job_offers 
        WHERE id::TEXT = job_id;
        
        RAISE NOTICE 'Views after increment: %', after_count;
        
        IF after_count > before_count THEN
            RAISE NOTICE '✅ JOB VIEWS FUNCTION WORKS!';
        ELSE
            RAISE NOTICE '❌ Job views function failed';
        END IF;
    END IF;
END $$;

-- اختبار المستلزمات
DO $$
DECLARE
    supply_id TEXT;
    before_count INTEGER;
    after_count INTEGER;
BEGIN
    -- الحصول على أول مستلزم
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO supply_id, before_count 
    FROM vet_supplies 
    LIMIT 1;
    
    IF supply_id IS NOT NULL THEN
        RAISE NOTICE 'Testing supply ID: %, current views: %', supply_id, before_count;
        
        -- استدعاء الدالة
        PERFORM increment_vet_supply_views(supply_id);
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO after_count 
        FROM vet_supplies 
        WHERE id::TEXT = supply_id;
        
        RAISE NOTICE 'Views after increment: %', after_count;
        
        IF after_count > before_count THEN
            RAISE NOTICE '✅ SUPPLY VIEWS FUNCTION WORKS!';
        ELSE
            RAISE NOTICE '❌ Supply views function failed';
        END IF;
    END IF;
END $$;

-- ===================================================================
-- 3. عرض البيانات الحديثة
-- ===================================================================

SELECT 'Recent Job Offers:' as info;
SELECT id, title, views_count, updated_at 
FROM job_offers 
ORDER BY updated_at DESC 
LIMIT 3;

SELECT 'Recent Vet Supplies:' as info;
SELECT id, name, views_count, updated_at 
FROM vet_supplies 
ORDER BY updated_at DESC 
LIMIT 3;

-- ===================================================================
-- 4. تقرير نهائي
-- ===================================================================

SELECT 
    'Functions are ready for Flutter testing!' as final_status,
    'Test from your app now - views should increment' as next_step;