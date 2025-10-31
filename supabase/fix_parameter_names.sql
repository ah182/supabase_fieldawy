-- ===================================================================
-- إصلاح أسماء معاملات الدوال لتتطابق مع Flutter Repository
-- ===================================================================

-- ===================================================================
-- 1. حذف الدوال الحالية
-- ===================================================================

DROP FUNCTION IF EXISTS increment_job_views CASCADE;
DROP FUNCTION IF EXISTS increment_vet_supply_views CASCADE;
DROP FUNCTION IF EXISTS increment_job_views_uuid CASCADE;
DROP FUNCTION IF EXISTS increment_vet_supply_views_uuid CASCADE;

-- ===================================================================
-- 2. إنشاء دوال بأسماء المعاملات الصحيحة التي يتوقعها Flutter
-- ===================================================================

-- دالة زيادة مشاهدات الوظائف - مع اسم المعامل الصحيح
CREATE OR REPLACE FUNCTION increment_job_views(p_job_id TEXT)
RETURNS VOID AS $$
DECLARE
    job_uuid UUID;
    rows_affected INTEGER;
BEGIN
    RAISE NOTICE 'increment_job_views called with: %', p_job_id;
    
    -- تحويل TEXT إلى UUID
    BEGIN
        job_uuid := p_job_id::UUID;
        RAISE NOTICE 'Converted to UUID: %', job_uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE NOTICE 'ERROR: Invalid UUID format: %', p_job_id;
            RETURN;
    END;
    
    -- التحديث
    UPDATE job_offers 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = NOW()
    WHERE id = job_uuid;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    RAISE NOTICE 'Job views updated: % rows affected', rows_affected;
    
    IF rows_affected = 0 THEN
        RAISE NOTICE 'WARNING: No job found with ID: %', p_job_id;
    ELSE
        RAISE NOTICE 'SUCCESS: Job views incremented for ID: %', p_job_id;
    END IF;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in increment_job_views: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- دالة زيادة مشاهدات المستلزمات - مع اسم المعامل الصحيح
CREATE OR REPLACE FUNCTION increment_vet_supply_views(p_supply_id TEXT)
RETURNS VOID AS $$
DECLARE
    supply_uuid UUID;
    rows_affected INTEGER;
BEGIN
    RAISE NOTICE 'increment_vet_supply_views called with: %', p_supply_id;
    
    -- تحويل TEXT إلى UUID
    BEGIN
        supply_uuid := p_supply_id::UUID;
        RAISE NOTICE 'Converted to UUID: %', supply_uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE NOTICE 'ERROR: Invalid UUID format: %', p_supply_id;
            RETURN;
    END;
    
    -- التحديث
    UPDATE vet_supplies 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = NOW()
    WHERE id = supply_uuid;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    RAISE NOTICE 'Supply views updated: % rows affected', rows_affected;
    
    IF rows_affected = 0 THEN
        RAISE NOTICE 'WARNING: No supply found with ID: %', p_supply_id;
    ELSE
        RAISE NOTICE 'SUCCESS: Supply views incremented for ID: %', p_supply_id;
    END IF;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in increment_vet_supply_views: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 3. اختبار الدوال بالأسماء الصحيحة
-- ===================================================================

-- اختبار دالة الوظائف
DO $$
DECLARE
    test_job_id TEXT;
    old_views INTEGER;
    new_views INTEGER;
BEGIN
    RAISE NOTICE '=== TESTING increment_job_views(p_job_id) ===';
    
    -- الحصول على أول وظيفة
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_job_id, old_views 
    FROM job_offers 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with job ID: %, current views: %', test_job_id, old_views;
        
        -- استدعاء الدالة بنفس الطريقة التي يستدعيها Flutter
        PERFORM increment_job_views(test_job_id);
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM job_offers 
        WHERE id::TEXT = test_job_id;
        
        RAISE NOTICE 'Views after increment: %', new_views;
        
        IF new_views > old_views THEN
            RAISE NOTICE '✅ SUCCESS: increment_job_views(p_job_id) works correctly!';
        ELSE
            RAISE NOTICE '❌ FAILED: Job views did not increase';
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
    RAISE NOTICE '=== TESTING increment_vet_supply_views(p_supply_id) ===';
    
    -- الحصول على أول مستلزم
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_supply_id, old_views 
    FROM vet_supplies 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with supply ID: %, current views: %', test_supply_id, old_views;
        
        -- استدعاء الدالة بنفس الطريقة التي يستدعيها Flutter
        PERFORM increment_vet_supply_views(test_supply_id);
        
        -- فحص النتيجة
        SELECT COALESCE(views_count, 0) 
        INTO new_views 
        FROM vet_supplies 
        WHERE id::TEXT = test_supply_id;
        
        RAISE NOTICE 'Views after increment: %', new_views;
        
        IF new_views > old_views THEN
            RAISE NOTICE '✅ SUCCESS: increment_vet_supply_views(p_supply_id) works correctly!';
        ELSE
            RAISE NOTICE '❌ FAILED: Supply views did not increase';
        END IF;
    ELSE
        RAISE NOTICE 'No vet supplies found for testing';
    END IF;
END $$;

-- ===================================================================
-- 4. التحقق من الدوال المتاحة
-- ===================================================================

SELECT 'Available functions after fix:' as info;

SELECT 
    routine_name,
    routine_type,
    data_type as return_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('increment_job_views', 'increment_vet_supply_views')
ORDER BY routine_name;

-- ===================================================================
-- 5. تقرير نهائي
-- ===================================================================

SELECT 
    'Functions recreated with correct parameter names!' as status,
    'increment_job_views(p_job_id TEXT)' as job_function,
    'increment_vet_supply_views(p_supply_id TEXT)' as supply_function,
    'These match what Flutter Repository expects' as note;