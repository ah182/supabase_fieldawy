-- ============================================================================
-- الحل الأمثل: Trigger-based rank update (بدون cron)
-- ============================================================================
-- الفكرة: تحديث الترتيب تلقائياً عند تغيير النقاط
-- الميزة: 0 invocations + تحديث فوري بدون انتظار 5 دقائق

-- ============================================================================
-- الخطوة 1: دالة تحديث الترتيب (optimized)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_leaderboard_ranks()
RETURNS void AS $$
BEGIN
  -- استخدام DENSE_RANK للترتيب بدون فجوات
  WITH ranked_users AS (
    SELECT
      id,
      DENSE_RANK() OVER (ORDER BY points DESC) as new_rank
    FROM public.users
    WHERE points > 0  -- فقط المستخدمين الذين لديهم نقاط
  )
  UPDATE public.users
  SET rank = ranked_users.new_rank
  FROM ranked_users
  WHERE users.id = ranked_users.id
    AND users.rank IS DISTINCT FROM ranked_users.new_rank;  -- فقط إذا تغير الترتيب
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- الخطوة 2: دالة trigger بسيطة
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trigger_update_ranks()
RETURNS TRIGGER AS $$
BEGIN
  -- تحديث الترتيب لكل المستخدمين
  PERFORM public.update_leaderboard_ranks();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- الخطوة 3: إنشاء trigger على جدول users
-- ============================================================================
-- حذف trigger القديم إن وُجد
DROP TRIGGER IF EXISTS on_points_change_update_ranks ON public.users;

-- إنشاء trigger جديد
CREATE TRIGGER on_points_change_update_ranks
AFTER UPDATE OF points ON public.users
FOR EACH STATEMENT  -- مهم: FOR EACH STATEMENT وليس FOR EACH ROW
EXECUTE FUNCTION public.trigger_update_ranks();

-- ============================================================================
-- ملاحظة مهمة: Trigger Throttling (اختياري)
-- ============================================================================
-- لتجنب تحديث الترتيب بشكل متكرر جداً، يمكنك استخدام هذا البديل:

-- إنشاء جدول لتتبع آخر تحديث
CREATE TABLE IF NOT EXISTS public.rank_update_tracker (
  id INT PRIMARY KEY DEFAULT 1,
  last_update TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT single_row CHECK (id = 1)
);

-- إدراج صف واحد
INSERT INTO public.rank_update_tracker (id, last_update) 
VALUES (1, NOW())
ON CONFLICT (id) DO NOTHING;

-- دالة trigger محسّنة مع throttling
CREATE OR REPLACE FUNCTION public.trigger_update_ranks_throttled()
RETURNS TRIGGER AS $$
DECLARE
  last_update TIMESTAMP;
  time_diff INTERVAL;
BEGIN
  -- جلب آخر تحديث
  SELECT last_update INTO last_update 
  FROM public.rank_update_tracker 
  WHERE id = 1;
  
  time_diff := NOW() - last_update;
  
  -- تحديث فقط إذا مر أكثر من 1 دقيقة منذ آخر تحديث
  IF time_diff > INTERVAL '1 minute' THEN
    PERFORM public.update_leaderboard_ranks();
    
    -- تحديث وقت آخر تحديث
    UPDATE public.rank_update_tracker 
    SET last_update = NOW() 
    WHERE id = 1;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- استبدال trigger بالنسخة المحسّنة
DROP TRIGGER IF EXISTS on_points_change_update_ranks ON public.users;

CREATE TRIGGER on_points_change_update_ranks
AFTER UPDATE OF points ON public.users
FOR EACH STATEMENT
EXECUTE FUNCTION public.trigger_update_ranks_throttled();

-- ============================================================================
-- رسالة نجاح
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ نظام Trigger-based للترتيب جاهز';
    RAISE NOTICE '✅ تحديث تلقائي عند تغيير النقاط';
    RAISE NOTICE '✅ Throttling: مرة واحدة كل دقيقة فقط';
    RAISE NOTICE '';
    RAISE NOTICE '📊 الميزات:';
    RAISE NOTICE '   - 0 invocations استهلاك';
    RAISE NOTICE '   - تحديث فوري (بدون انتظار cron)';
    RAISE NOTICE '   - أداء محسّن (فقط عند الحاجة)';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 للتحقق:';
    RAISE NOTICE '   SELECT * FROM rank_update_tracker;';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
