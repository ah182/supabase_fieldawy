-- ============================================================================
-- إصلاح عاجل: حذف Trigger واستعادة النظام
-- ============================================================================

-- الخطوة 1: حذف trigger المسبب للمشكلة
-- ============================================================================
DROP TRIGGER IF EXISTS on_points_change_update_ranks ON public.users;

-- الخطوة 2: حذف الدوال المرتبطة (اختياري - للتنظيف)
-- ============================================================================
DROP FUNCTION IF EXISTS public.trigger_update_ranks_throttled();
DROP FUNCTION IF EXISTS public.trigger_update_ranks();

-- الخطوة 3: حذف جدول التتبع (اختياري)
-- ============================================================================
DROP TABLE IF EXISTS public.rank_update_tracker;

-- الخطوة 4: التأكد من وجود الدالة الأساسية
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

-- الخطوة 5: إعادة تشغيل cron job (بدون Edge Function)
-- ============================================================================
-- حذف أي cron jobs قديمة (مع تجاهل الأخطاء)
DO $$
BEGIN
  PERFORM cron.unschedule('update-leaderboard-ranks-job');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Job update-leaderboard-ranks-job not found, skipping...';
END $$;

DO $$
BEGIN
  PERFORM cron.unschedule('update-leaderboard-ranks-sql');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Job update-leaderboard-ranks-sql not found, skipping...';
END $$;

DO $$
BEGIN
  PERFORM cron.unschedule('leaderboard-ranks-updater');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Job leaderboard-ranks-updater not found, skipping...';
END $$;

-- إنشاء cron job جديد بسيط (كل دقيقة)
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

-- رسالة نجاح
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم إصلاح النظام';
    RAISE NOTICE '✅ تم حذف trigger المسبب للمشكلة';
    RAISE NOTICE '✅ تم إعادة cron job بسيط (كل دقيقة)';
    RAISE NOTICE '✅ تم تحديث الترتيب الآن';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 للتحقق من النقاط:';
    RAISE NOTICE '   SELECT id, display_name, points, rank';
    RAISE NOTICE '   FROM users WHERE points > 0';
    RAISE NOTICE '   ORDER BY rank;';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 للتحقق من cron jobs:';
    RAISE NOTICE '   SELECT * FROM cron.job;';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
