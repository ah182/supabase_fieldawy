-- ===================================================================
-- إنشاء دوال المشاهدات باستخدام UUID مباشرة
-- ===================================================================
-- المشكلة قد تكون في تحويل TEXT إلى UUID
-- هذا النهج يستخدم UUID مباشرة بدون تحويل

-- ===================================================================
-- 1. حذف الدوال القديمة
-- ===================================================================

DROP FUNCTION IF EXISTS increment_job_views CASCADE;
DROP FUNCTION IF EXISTS increment_vet_supply_views CASCADE;

-- ===================================================================
-- 2. إنشاء دوال جديدة تستخدم UUID مباشرة
-- ===================================================================

-- دالة زيادة مشاهدات الوظائف - UUID
CREATE OR REPLACE FUNCTION increment_job_views_uuid(job_uuid UUID)
RETURNS VOID AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    RAISE NOTICE 'Attempting to increment views for job UUID: %', job_uuid;
    
    -- التحديث مباشرة باستخدام UUID
    UPDATE job_offers 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = NOW()
    WHERE id = job_uuid;
    
    -- الحصول على عدد الصفوف المتأثرة
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    RAISE NOTICE 'Job views update: % rows affected', rows_affected;
    
    IF rows_affected = 0 THEN
        RAISE NOTICE 'WARNING: No job found with UUID: %', job_uuid;
    ELSE
        RAISE NOTICE 'SUCCESS: Job views incremented for UUID: %', job_uuid;
    END IF;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in increment_job_views_uuid: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- دالة زيادة مشاهدات المستلزمات - UUID
CREATE OR REPLACE FUNCTION increment_vet_supply_views_uuid(supply_uuid UUID)
RETURNS VOID AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    RAISE NOTICE 'Attempting to increment views for supply UUID: %', supply_uuid;
    
    -- التحديث مباشرة باستخدام UUID
    UPDATE vet_supplies 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = NOW()
    WHERE id = supply_uuid;
    
    -- الحصول على عدد الصفوف المتأثرة
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    RAISE NOTICE 'Supply views update: % rows affected', rows_affected;
    
    IF rows_affected = 0 THEN
        RAISE NOTICE 'WARNING: No supply found with UUID: %', supply_uuid;
    ELSE
        RAISE NOTICE 'SUCCESS: Supply views incremented for UUID: %', supply_uuid;
    END IF;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in increment_vet_supply_views_uuid: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 3. إنشاء دوال wrapper تقبل TEXT وتحول إلى UUID
-- ===================================================================

-- Wrapper للوظائف
CREATE OR REPLACE FUNCTION increment_job_views(job_id_text TEXT)
RETURNS VOID AS $$
DECLARE
    job_uuid UUID;
BEGIN
    -- تحويل TEXT إلى UUID
    BEGIN
        job_uuid := job_id_text::UUID;
        RAISE NOTICE 'Converted text % to UUID %', job_id_text, job_uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE NOTICE 'ERROR: Invalid UUID format: %', job_id_text;
            RETURN;
    END;
    
    -- استدعاء الدالة الأساسية
    PERFORM increment_job_views_uuid(job_uuid);
END;
$$ LANGUAGE plpgsql;

-- Wrapper للمستلزمات
CREATE OR REPLACE FUNCTION increment_vet_supply_views(supply_id_text TEXT)
RETURNS VOID AS $$
DECLARE
    supply_uuid UUID;
BEGIN
    -- تحويل TEXT إلى UUID
    BEGIN
        supply_uuid := supply_id_text::UUID;
        RAISE NOTICE 'Converted text % to UUID %', supply_id_text, supply_uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE NOTICE 'ERROR: Invalid UUID format: %', supply_id_text;
            RETURN;
    END;
    
    -- استدعاء الدالة الأساسية
    PERFORM increment_vet_supply_views_uuid(supply_uuid);
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 4. اختبار الدوال الجديدة
-- ===================================================================

-- اختبار دالة الوظائف
DO $$
DECLARE
    test_job_id UUID;
    test_job_text TEXT;
    old_views INTEGER;
    new_views INTEGER;
BEGIN
    RAISE NOTICE '=== TESTING NEW JOB VIEWS FUNCTIONS ===';
    
    -- الحصول على أول وظيفة
    SELECT id, COALESCE(views_count, 0) 
    INTO test_job_id, old_views 
    FROM job_offers 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        test_job_text := test_job_id::TEXT;
        
        RAISE NOTICE 'Testing with job UUID: %', test_job_id;
        RAISE NOTICE 'Job text representation: %', test_job_text;
        RAISE NOTICE 'Current views: %', old_views;
        
        -- اختبار الدالة الأساسية
        PERFORM increment_job_views_uuid(test_job_id);
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'Views after UUID function: %', new_views;
        
        -- اختبار دالة wrapper
        PERFORM increment_job_views(test_job_text);
        
        -- فحص النتيجة النهائية
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'Views after TEXT wrapper: %', new_views;
        
        IF new_views > old_views THEN
            RAISE NOTICE '✅ SUCCESS: Both functions work correctly!';
        ELSE
            RAISE NOTICE '❌ FAILED: Functions did not increase views';
        END IF;
    ELSE
        RAISE NOTICE 'No job offers found for testing';
    END IF;
END $$;

-- اختبار دالة المستلزمات
DO $$
DECLARE
    test_supply_id UUID;
    test_supply_text TEXT;
    old_views INTEGER;
    new_views INTEGER;
BEGIN
    RAISE NOTICE '=== TESTING NEW SUPPLY VIEWS FUNCTIONS ===';
    
    -- الحصول على أول مستلزم
    SELECT id, COALESCE(views_count, 0) 
    INTO test_supply_id, old_views 
    FROM vet_supplies 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        test_supply_text := test_supply_id::TEXT;
        
        RAISE NOTICE 'Testing with supply UUID: %', test_supply_id;
        RAISE NOTICE 'Supply text representation: %', test_supply_text;
        RAISE NOTICE 'Current views: %', old_views;
        
        -- اختبار الدالة الأساسية
        PERFORM increment_vet_supply_views_uuid(test_supply_id);
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM vet_supplies 
        WHERE id = test_supply_id;
        
        RAISE NOTICE 'Views after UUID function: %', new_views;
        
        -- اختبار دالة wrapper
        PERFORM increment_vet_supply_views(test_supply_text);
        
        -- فحص النتيجة النهائية
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM vet_supplies 
        WHERE id = test_supply_id;
        
        RAISE NOTICE 'Views after TEXT wrapper: %', new_views;
        
        IF new_views > old_views THEN
            RAISE NOTICE '✅ SUCCESS: Both functions work correctly!';
        ELSE
            RAISE NOTICE '❌ FAILED: Functions did not increase views';
        END IF;
    ELSE
        RAISE NOTICE 'No vet supplies found for testing';
    END IF;
END $$;

-- ===================================================================
-- 5. تقرير نهائي
-- ===================================================================

SELECT 
    'UUID-based functions created successfully!' as status,
    'Check notices above for test results' as instruction,
    'Functions available: increment_job_views(TEXT), increment_vet_supply_views(TEXT)' as available_functions;