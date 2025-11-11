-- ============================================================================
-- بديل لـ Edge Function: تحديث الترتيب بدون استهلاك invocations
-- ============================================================================
-- المشكلة: استدعاء Edge Function كل دقيقة يستهلك 43,200 invocation/شهر
-- الحل: استخدام SQL Function + pg_cron مباشرة = 0 invocations

-- ============================================================================
-- الحل 1: استخدام SQL Function موجودة مع pg_cron
-- ============================================================================
-- الدالة موجودة بالفعل في: 20251030_create_update_ranks_function.sql

-- تأكد من وجود الدالة
CREATE OR REPLACE FUNCTION public.update_leaderboard_ranks()
RETURNS void AS $$
BEGIN
  WITH ranked_users AS (
    SELECT
      id,
      RANK() OVER (ORDER BY points DESC) as new_rank
    FROM public.users
  )
  UPDATE public.users
  SET rank = ranked_users.new_rank
  FROM ranked_users
  WHERE users.id = ranked_users.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- الآن نستبدل استدعاء Edge Function بـ SQL Function مباشرة
-- ============================================================================

-- 1. حذف الـ cron job القديم (الذي يستدعي Edge Function)
SELECT cron.unschedule('update-leaderboard-ranks-job');

-- 2. إنشاء cron job جديد يستدعي SQL Function مباشرة
SELECT cron.schedule(
  'update-leaderboard-ranks-sql',   -- اسم جديد
  '*/5 * * * *',                     -- كل 5 دقائق (بدلاً من كل دقيقة)
  $$
  SELECT public.update_leaderboard_ranks();
  $$
);

-- ============================================================================
-- رسالة نجاح
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم استبدال Edge Function بـ SQL Function';
    RAISE NOTICE '✅ 0 invocations استهلاك = لا يوجد';
    RAISE NOTICE '✅ التحديث كل 5 دقائق بدلاً من كل دقيقة';
    RAISE NOTICE '';
    RAISE NOTICE '📊 الفرق:';
    RAISE NOTICE '   - القديم: 43,200 invocation/شهر';
    RAISE NOTICE '   - الجديد: 0 invocation/شهر ✅';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 للتحقق من الـ cron jobs:';
    RAISE NOTICE '   SELECT * FROM cron.job;';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
