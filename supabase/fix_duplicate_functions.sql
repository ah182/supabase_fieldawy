-- ===================================================================
-- إصلاح مشكلة الدوال المتضاربة
-- ===================================================================

-- ===================================================================
-- 1. حذف جميع الدوال المتضاربة
-- ===================================================================

-- حذف جميع نسخ increment_job_views
DROP FUNCTION IF EXISTS increment_job_views(TEXT);
DROP FUNCTION IF EXISTS increment_job_views(UUID);
DROP FUNCTION IF EXISTS increment_job_views(p_job_id TEXT);
DROP FUNCTION IF EXISTS increment_job_views(p_job_id UUID);

-- حذف جميع نسخ increment_vet_supply_views
DROP FUNCTION IF EXISTS increment_vet_supply_views(TEXT);
DROP FUNCTION IF EXISTS increment_vet_supply_views(UUID);
DROP FUNCTION IF EXISTS increment_vet_supply_views(p_supply_id TEXT);
DROP FUNCTION IF EXISTS increment_vet_supply_views(p_supply_id UUID);

-- ===================================================================
-- 2. إنشاء دوال جديدة بأسماء واضحة
-- ===================================================================

-- دالة زيادة مشاهدات الوظائف
CREATE OR REPLACE FUNCTION increment_job_views(job_id_param TEXT)
RETURNS VOID AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- التحديث مع تحويل نوع البيانات
    UPDATE job_offers 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id::TEXT = job_id_param;
    
    -- الحصول على عدد الصفوف المتأثرة
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- رسالة تأكيد للتشخيص
    RAISE NOTICE 'Job views updated: % rows affected for ID: %', rows_affected, job_id_param;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in increment_job_views: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- دالة زيادة مشاهدات المستلزمات البيطرية
CREATE OR REPLACE FUNCTION increment_vet_supply_views(supply_id_param TEXT)
RETURNS VOID AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- التحديث مع تحويل نوع البيانات
    UPDATE vet_supplies 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id::TEXT = supply_id_param;
    
    -- الحصول على عدد الصفوف المتأثرة
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- رسالة تأكيد للتشخيص
    RAISE NOTICE 'Supply views updated: % rows affected for ID: %', rows_affected, supply_id_param;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in increment_vet_supply_views: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 3. اختبار الدوال الجديدة
-- ===================================================================

-- اختبار دالة الوظائف
DO $$
DECLARE
    test_job_id TEXT;
    old_views INTEGER;
    new_views INTEGER;
BEGIN
    -- الحصول على أول وظيفة للاختبار
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_job_id, old_views 
    FROM job_offers 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        RAISE NOTICE 'Testing increment_job_views with ID: %, current views: %', test_job_id, old_views;
        
        -- استدعاء الدالة الجديدة
        PERFORM increment_job_views(test_job_id);
        
        -- التحقق من النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM job_offers 
        WHERE id::TEXT = test_job_id;
        
        RAISE NOTICE 'Views after increment: %', new_views;
        
        IF new_views > old_views THEN
            RAISE NOTICE 'SUCCESS: Job views function works correctly!';
        ELSE
            RAISE NOTICE 'FAILED: Job views did not increase';
        END IF;
    ELSE
        RAISE NOTICE 'No job offers found for testing';
    END IF;
END $$;

-- اختبار دالة المستلزمات
DO $$
DECLARE
    test_supply_id TEXT;
    old_views INTEGER;
    new_views INTEGER;
BEGIN
    -- الحصول على أول مستلزم للاختبار
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_supply_id, old_views 
    FROM vet_supplies 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        RAISE NOTICE 'Testing increment_vet_supply_views with ID: %, current views: %', test_supply_id, old_views;
        
        -- استدعاء الدالة الجديدة
        PERFORM increment_vet_supply_views(test_supply_id);
        
        -- التحقق من النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM vet_supplies 
        WHERE id::TEXT = test_supply_id;
        
        RAISE NOTICE 'Views after increment: %', new_views;
        
        IF new_views > old_views THEN
            RAISE NOTICE 'SUCCESS: Supply views function works correctly!';
        ELSE
            RAISE NOTICE 'FAILED: Supply views did not increase';
        END IF;
    ELSE
        RAISE NOTICE 'No vet supplies found for testing';
    END IF;
END $$;

-- ===================================================================
-- 4. التحقق من عدم وجود دوال متضاربة
-- ===================================================================

SELECT 
    'Checking for duplicate functions...' as step;

SELECT 
    routine_name,
    routine_type,
    data_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('increment_job_views', 'increment_vet_supply_views')
ORDER BY routine_name;

-- ===================================================================
-- 5. تقرير نهائي
-- ===================================================================

SELECT 
    'Duplicate functions issue resolved!' as status,
    'Functions recreated with unique parameter names' as solution,
    'Test from Flutter app - should work now' as next_step;