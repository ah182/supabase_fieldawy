-- ============================================================================
-- إعادة حساب helpful و unhelpful counts بشكل صحيح
-- ============================================================================

-- 1. إعادة حساب جميع الـ counts من جدول review_helpful_votes
UPDATE public.product_reviews pr
SET 
  helpful_count = COALESCE((
    SELECT COUNT(*) 
    FROM public.review_helpful_votes rhv 
    WHERE rhv.review_id = pr.id AND rhv.is_helpful = true
  ), 0),
  unhelpful_count = COALESCE((
    SELECT COUNT(*) 
    FROM public.review_helpful_votes rhv 
    WHERE rhv.review_id = pr.id AND rhv.is_helpful = false
  ), 0);

-- 2. عرض النتائج
DO $$
DECLARE
  v_total_reviews int;
  v_with_helpful int;
  v_with_unhelpful int;
BEGIN
  SELECT COUNT(*) INTO v_total_reviews FROM public.product_reviews;
  SELECT COUNT(*) INTO v_with_helpful FROM public.product_reviews WHERE helpful_count > 0;
  SELECT COUNT(*) INTO v_with_unhelpful FROM public.product_reviews WHERE unhelpful_count > 0;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ تم إعادة حساب الأرقام بنجاح!';
  RAISE NOTICE '📊 إجمالي التقييمات: %', v_total_reviews;
  RAISE NOTICE '👍 تقييمات بها helpful: %', v_with_helpful;
  RAISE NOTICE '👎 تقييمات بها unhelpful: %', v_with_unhelpful;
  RAISE NOTICE '';
END $$;

-- 3. عرض عينة من البيانات للتحقق
DO $$
DECLARE
  v_sample record;
BEGIN
  RAISE NOTICE '📋 عينة من البيانات:';
  FOR v_sample IN 
    SELECT id, helpful_count, unhelpful_count 
    FROM public.product_reviews 
    WHERE helpful_count > 0 OR unhelpful_count > 0
    LIMIT 5
  LOOP
    RAISE NOTICE '   Review %: helpful=%, unhelpful=%', 
      v_sample.id, v_sample.helpful_count, v_sample.unhelpful_count;
  END LOOP;
END $$;
