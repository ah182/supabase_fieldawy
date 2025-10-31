-- ===================================================================
-- فحص حالة دوال المشاهدات بعد التطبيق
-- ===================================================================

-- ===================================================================
-- 1. فحص وجود الدوال
-- ===================================================================

SELECT 
    'Checking functions status' as step;

SELECT 
    routine_name as function_name,
    'EXISTS' as status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('increment_job_views', 'increment_vet_supply_views');

-- ===================================================================
-- 2. فحص أعمدة views_count
-- ===================================================================

SELECT 
    'Checking views_count columns' as step;

-- فحص job_offers
SELECT 
    'job_offers' as table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'job_offers' AND column_name = 'views_count'
        ) THEN 'views_count EXISTS'
        ELSE 'views_count MISSING'
    END as column_status;

-- فحص vet_supplies
SELECT 
    'vet_supplies' as table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'vet_supplies' AND column_name = 'views_count'
        ) THEN 'views_count EXISTS'
        ELSE 'views_count MISSING'
    END as column_status;

-- ===================================================================
-- 3. اختبار سريع للدوال
-- ===================================================================

SELECT 
    'Testing functions manually' as step;

-- اختبار دالة الوظائف مع ID وهمي
DO $$
BEGIN
    -- اختبار بسيط
    RAISE NOTICE 'Testing increment_job_views function...';
    
    -- لن نستدعي الدالة على ID حقيقي، فقط نتحقق من وجودها
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'increment_job_views'
    ) THEN
        RAISE NOTICE 'increment_job_views function EXISTS and ready to use';
    ELSE
        RAISE NOTICE 'increment_job_views function NOT FOUND';
    END IF;
END $$;

-- اختبار دالة المستلزمات
DO $$
BEGIN
    RAISE NOTICE 'Testing increment_vet_supply_views function...';
    
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'increment_vet_supply_views'
    ) THEN
        RAISE NOTICE 'increment_vet_supply_views function EXISTS and ready to use';
    ELSE
        RAISE NOTICE 'increment_vet_supply_views function NOT FOUND';
    END IF;
END $$;

-- ===================================================================
-- 4. عرض عينة من البيانات
-- ===================================================================

SELECT 
    'Sample data from tables' as step;

-- عينة من job_offers
SELECT 
    'job_offers sample:' as info,
    id,
    title,
    views_count
FROM job_offers 
ORDER BY created_at DESC 
LIMIT 3;

-- عينة من vet_supplies
SELECT 
    'vet_supplies sample:' as info,
    id,
    name,
    views_count
FROM vet_supplies 
ORDER BY created_at DESC 
LIMIT 3;

-- ===================================================================
-- 5. تقرير الحالة النهائية
-- ===================================================================

SELECT 
    'Functions setup status completed!' as final_status,
    'Both functions should be working now' as conclusion,
    'Test from your Flutter app to confirm' as next_action;