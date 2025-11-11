-- ============================================================================
-- تحديث دالة الترتيب لتكون متسلسلة: 1, 2, 3, 4, 5...
-- ============================================================================
-- بدون تكرار في الأرقام حتى لو تساوت النقاط

CREATE OR REPLACE FUNCTION public.update_leaderboard_ranks()
RETURNS void AS $$
BEGIN
  WITH ranked_users AS (
    SELECT
      id,
      -- ROW_NUMBER بدلاً من RANK لترتيب متسلسل بدون تكرار
      ROW_NUMBER() OVER (
        ORDER BY 
          points DESC,        -- ترتيب حسب النقاط (الأعلى أولاً)
          created_at ASC      -- إذا تساوت النقاط، الأقدم يأخذ الترتيب الأفضل
      ) as new_rank
    FROM public.users
  )
  UPDATE public.users
  SET rank = ranked_users.new_rank
  FROM ranked_users
  WHERE public.users.id = ranked_users.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- تحديث الترتيب الآن
SELECT public.update_leaderboard_ranks();

-- رسالة نجاح
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم تحديث دالة الترتيب';
    RAISE NOTICE '✅ الترتيب الآن متسلسل: 1, 2, 3, 4, 5...';
    RAISE NOTICE '✅ بدون تكرار حتى لو تساوت النقاط';
    RAISE NOTICE '';
    RAISE NOTICE '📊 الفرق:';
    RAISE NOTICE '   - RANK(): 1, 2, 3, 3, 5 ❌';
    RAISE NOTICE '   - ROW_NUMBER(): 1, 2, 3, 4, 5 ✅';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 للتحقق:';
    RAISE NOTICE '   SELECT display_name, points, rank';
    RAISE NOTICE '   FROM users ORDER BY rank LIMIT 20;';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
