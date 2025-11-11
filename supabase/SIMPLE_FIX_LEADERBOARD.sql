-- ============================================================================
-- إصلاح بسيط: حذف Trigger وإعادة Cron
-- ============================================================================

-- الخطوة 1: حذف trigger المسبب للمشكلة
-- ============================================================================
DROP TRIGGER IF EXISTS on_points_change_update_ranks ON public.users;
DROP FUNCTION IF EXISTS public.trigger_update_ranks_throttled();
DROP FUNCTION IF EXISTS public.trigger_update_ranks();
DROP TABLE IF EXISTS public.rank_update_tracker;

-- الخطوة 2: التأكد من وجود الدالة الأساسية
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_leaderboard_ranks()
RETURNS void AS $$
BEGIN
  WITH ranked_users AS (
    SELECT
      id,
      ROW_NUMBER() OVER (ORDER BY points DESC, created_at ASC) as new_rank
    FROM public.users
  )
  UPDATE public.users
  SET rank = ranked_users.new_rank
  FROM ranked_users
  WHERE public.users.id = ranked_users.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- الخطوة 3: فحص الـ cron jobs الموجودة
-- ============================================================================
SELECT 
  jobid,
  jobname,
  schedule,
  active
FROM cron.job
WHERE jobname LIKE '%rank%' OR jobname LIKE '%leaderboard%';

-- الخطوة 4: حذف cron jobs القديمة (إن وُجدت)
-- ============================================================================
-- قم بنسخ jobid من النتيجة أعلاه واستبدله هنا إذا لزم الأمر
-- SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'اسم-الـjob-القديم';

-- أو استخدم هذا للحذف حسب الاسم:
DO $$
DECLARE
  job_record RECORD;
BEGIN
  FOR job_record IN 
    SELECT jobid, jobname 
    FROM cron.job 
    WHERE jobname IN ('update-leaderboard-ranks-job', 'update-leaderboard-ranks-sql', 'leaderboard-ranks-updater')
  LOOP
    PERFORM cron.unschedule(job_record.jobid);
    RAISE NOTICE 'Deleted job: % (id: %)', job_record.jobname, job_record.jobid;
  END LOOP;
END $$;

-- الخطوة 5: إنشاء cron job جديد (كل دقيقة)
-- ============================================================================
SELECT cron.schedule(
  'leaderboard-ranks-updater',
  '* * * * *',  -- كل دقيقة
  $$
  SELECT public.update_leaderboard_ranks();
  $$
);

-- الخطوة 6: تحديث الترتيب الآن مباشرة
-- ============================================================================
SELECT public.update_leaderboard_ranks();

-- الخطوة 7: التحقق من النتيجة
-- ============================================================================
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  command
FROM cron.job
WHERE jobname = 'leaderboard-ranks-updater';

-- رسالة نجاح
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم إصلاح النظام';
    RAISE NOTICE '✅ تم حذف trigger المسبب للمشكلة';
    RAISE NOTICE '✅ تم إعادة cron job (كل دقيقة)';
    RAISE NOTICE '✅ تم تحديث الترتيب الآن';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 فحص الـ cron job الجديد:';
    RAISE NOTICE '   SELECT * FROM cron.job WHERE jobname = ''leaderboard-ranks-updater'';';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 فحص النقاط:';
    RAISE NOTICE '   SELECT display_name, points, rank FROM users WHERE points > 0 ORDER BY rank;';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
