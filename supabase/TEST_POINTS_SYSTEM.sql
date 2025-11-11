-- ============================================================================
-- اختبار نظام النقاط
-- ============================================================================

-- 1. فحص جدول users
-- ============================================================================
SELECT 
  'Users table check' as test,
  COUNT(*) as total_users,
  COUNT(points) as users_with_points,
  SUM(points) as total_points
FROM users;

-- 2. فحص المستخدمين ذوي النقاط
-- ============================================================================
SELECT 
  id,
  display_name,
  role,
  points,
  rank,
  referral_code
FROM users 
WHERE points > 0
ORDER BY points DESC
LIMIT 20;

-- 3. فحص الـ triggers الموجودة
-- ============================================================================
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as enabled,
  pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgrelid = 'users'::regclass
  AND tgisinternal = false;

-- 4. فحص الـ cron jobs
-- ============================================================================
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname LIKE '%rank%' OR jobname LIKE '%leaderboard%';

-- 5. فحص دالة increment_user_points
-- ============================================================================
SELECT 
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'increment_user_points';

-- 6. اختبار إضافة نقاط (اختياري - احذف التعليق للاختبار)
-- ============================================================================
/*
-- اختر مستخدم للاختبار
DO $$
DECLARE
  test_user_id UUID;
BEGIN
  -- جلب أول مستخدم
  SELECT id INTO test_user_id FROM users LIMIT 1;
  
  RAISE NOTICE 'Testing with user: %', test_user_id;
  
  -- محاولة إضافة نقطة
  PERFORM increment_user_points(test_user_id, 1);
  
  -- فحص النتيجة
  RAISE NOTICE 'Points after increment: %', (SELECT points FROM users WHERE id = test_user_id);
END $$;
*/

-- 7. فحص الدوال المتعلقة بالنقاط
-- ============================================================================
SELECT 
  proname as function_name,
  pronargs as num_args,
  prorettype::regtype as return_type
FROM pg_proc
WHERE proname LIKE '%point%' OR proname LIKE '%rank%'
ORDER BY proname;
