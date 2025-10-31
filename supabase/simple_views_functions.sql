-- ===================================================================
-- دوال المشاهدات المبسطة للاختبار
-- ===================================================================

-- ===================================================================
-- 1. إضافة أعمدة views_count إذا لم تكن موجودة
-- ===================================================================

-- إضافة عمود views_count لجدول job_offers
ALTER TABLE job_offers 
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

-- إضافة عمود views_count لجدول vet_supplies
ALTER TABLE vet_supplies 
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

-- ===================================================================
-- 2. دالة بسيطة لزيادة مشاهدات الوظائف
-- ===================================================================

CREATE OR REPLACE FUNCTION increment_job_views(p_job_id TEXT)
RETURNS VOID AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- محاولة التحديث مع تحويل نوع البيانات
    UPDATE job_offers 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id::TEXT = p_job_id;
    
    -- الحصول على عدد الصفوف المتأثرة
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- رسالة تأكيد
    RAISE NOTICE 'Updated % rows for job ID: %', rows_affected, p_job_id;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Error updating job views: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 3. دالة بسيطة لزيادة مشاهدات المستلزمات
-- ===================================================================

CREATE OR REPLACE FUNCTION increment_vet_supply_views(p_supply_id TEXT)
RETURNS VOID AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- محاولة التحديث مع تحويل نوع البيانات
    UPDATE vet_supplies 
    SET 
        views_count = COALESCE(views_count, 0) + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id::TEXT = p_supply_id;
    
    -- الحصول على عدد الصفوف المتأثرة
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- رسالة تأكيد
    RAISE NOTICE 'Updated % rows for supply ID: %', rows_affected, p_supply_id;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Error updating supply views: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 4. اختبار الدوال مع بيانات حقيقية
-- ===================================================================

-- اختبار دالة الوظائف
DO $$
DECLARE
    test_job_id TEXT;
    old_views INTEGER;
    new_views INTEGER;
BEGIN
    -- الحصول على أول وظيفة
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_job_id, old_views 
    FROM job_offers 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with job ID: %, current views: %', test_job_id, old_views;
        
        -- استدعاء الدالة
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
    -- الحصول على أول مستلزم
    SELECT id::TEXT, COALESCE(views_count, 0) 
    INTO test_supply_id, old_views 
    FROM vet_supplies 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with supply ID: %, current views: %', test_supply_id, old_views;
        
        -- استدعاء الدالة
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
-- 5. تقرير نهائي
-- ===================================================================

SELECT 
    'Simple views functions setup completed!' as status,
    'Check the notices above for test results' as note,
    'If successful, the views counters should work in your app' as next_step;