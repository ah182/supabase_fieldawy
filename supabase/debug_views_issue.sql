-- ===================================================================
-- تشخيص مشكلة دوال المشاهدات
-- ===================================================================

-- ===================================================================
-- 1. فحص هيكل جدول job_offers
-- ===================================================================

SELECT 
    'job_offers table structure' as info;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'job_offers' 
ORDER BY ordinal_position;

-- ===================================================================
-- 2. فحص هيكل جدول vet_supplies
-- ===================================================================

SELECT 
    'vet_supplies table structure' as info;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vet_supplies' 
ORDER BY ordinal_position;

-- ===================================================================
-- 3. فحص وجود الجداول
-- ===================================================================

SELECT 
    'Available tables' as info;

SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('job_offers', 'vet_supplies')
ORDER BY table_name;

-- ===================================================================
-- 4. فحص بيانات عينة من الجداول
-- ===================================================================

-- عينة من job_offers
SELECT 
    'Sample job_offers data' as info;

SELECT 
    id,
    title,
    CASE 
        WHEN column_name = 'views_count' THEN 'views_count exists'
        ELSE 'views_count missing'
    END as views_column_status
FROM job_offers 
CROSS JOIN information_schema.columns 
WHERE table_name = 'job_offers' AND column_name = 'views_count'
LIMIT 1

UNION ALL

SELECT 
    id,
    title,
    'views_count missing' as views_column_status
FROM job_offers 
WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'job_offers' AND column_name = 'views_count'
)
LIMIT 1;

-- عينة من vet_supplies
SELECT 
    'Sample vet_supplies data' as info;

SELECT 
    id,
    name,
    CASE 
        WHEN column_name = 'views_count' THEN 'views_count exists'
        ELSE 'views_count missing'
    END as views_column_status
FROM vet_supplies 
CROSS JOIN information_schema.columns 
WHERE table_name = 'vet_supplies' AND column_name = 'views_count'
LIMIT 1

UNION ALL

SELECT 
    id,
    name,
    'views_count missing' as views_column_status
FROM vet_supplies 
WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vet_supplies' AND column_name = 'views_count'
)
LIMIT 1;

-- ===================================================================
-- 5. فحص الدوال الموجودة
-- ===================================================================

SELECT 
    'Existing functions' as info;

SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('increment_job_views', 'increment_vet_supply_views')
ORDER BY routine_name;

-- ===================================================================
-- 6. محاولة إنشاء دالة بسيطة للاختبار
-- ===================================================================

CREATE OR REPLACE FUNCTION test_simple_increment(test_id TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'Function works with ID: ' || test_id;
END;
$$ LANGUAGE plpgsql;

-- اختبار الدالة البسيطة
SELECT test_simple_increment('test-123') as simple_function_test;

-- ===================================================================
-- النتيجة
-- ===================================================================

SELECT 
    'Diagnosis completed' as status,
    'Check the results above to identify the issue' as next_step;