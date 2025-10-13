-- ============================================================================
-- إصلاح نهائي: فصل الـ votes لكل review على حدة
-- ============================================================================

-- 1. التحقق من البيانات الموجودة
DO $$
DECLARE
  v_votes_count int;
  v_reviews_count int;
BEGIN
  SELECT COUNT(*) INTO v_votes_count FROM public.review_helpful_votes;
  SELECT COUNT(*) INTO v_reviews_count FROM public.product_reviews;
  
  RAISE NOTICE '📊 حالة البيانات الحالية:';
  RAISE NOTICE '   عدد الـ votes: %', v_votes_count;
  RAISE NOTICE '   عدد الـ reviews: %', v_reviews_count;
END $$;

-- 2. إعادة حساب الـ counts بشكل دقيق لكل review
UPDATE public.product_reviews pr
SET 
  helpful_count = (
    SELECT COUNT(*) 
    FROM public.review_helpful_votes rhv 
    WHERE rhv.review_id = pr.id AND rhv.is_helpful = true
  ),
  unhelpful_count = (
    SELECT COUNT(*) 
    FROM public.review_helpful_votes rhv 
    WHERE rhv.review_id = pr.id AND rhv.is_helpful = false
  );

-- 3. تحديث القيم NULL إلى 0
UPDATE public.product_reviews 
SET helpful_count = 0 
WHERE helpful_count IS NULL;

UPDATE public.product_reviews 
SET unhelpful_count = 0 
WHERE unhelpful_count IS NULL;

-- 4. إعادة كتابة دالة vote_review_helpful بشكل أفضل
DROP FUNCTION IF EXISTS public.vote_review_helpful(uuid, boolean);

CREATE OR REPLACE FUNCTION public.vote_review_helpful(
  p_review_id uuid,
  p_is_helpful boolean
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_existing_vote_id uuid;
  v_existing_is_helpful boolean;
  v_new_helpful_count int;
  v_new_unhelpful_count int;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- التحقق من وجود تصويت سابق لهذا الـ review بالتحديد
  SELECT id, is_helpful INTO v_existing_vote_id, v_existing_is_helpful
  FROM public.review_helpful_votes
  WHERE review_id = p_review_id AND user_id = v_user_id;
  
  IF v_existing_vote_id IS NOT NULL THEN
    -- يوجد تصويت سابق
    IF v_existing_is_helpful = p_is_helpful THEN
      -- نفس التصويت - حذفه (toggle off)
      DELETE FROM public.review_helpful_votes
      WHERE id = v_existing_vote_id;
    ELSE
      -- تصويت مختلف - تحديثه (من like إلى dislike أو العكس)
      UPDATE public.review_helpful_votes
      SET is_helpful = p_is_helpful, created_at = now()
      WHERE id = v_existing_vote_id;
    END IF;
  ELSE
    -- تصويت جديد - إضافته
    INSERT INTO public.review_helpful_votes (review_id, user_id, is_helpful)
    VALUES (p_review_id, v_user_id, p_is_helpful);
  END IF;
  
  -- إعادة حساب الـ counts من الصفر لهذا الـ review فقط
  SELECT 
    COUNT(*) FILTER (WHERE is_helpful = true),
    COUNT(*) FILTER (WHERE is_helpful = false)
  INTO v_new_helpful_count, v_new_unhelpful_count
  FROM public.review_helpful_votes
  WHERE review_id = p_review_id;
  
  -- تحديث الـ counts في جدول product_reviews
  UPDATE public.product_reviews
  SET 
    helpful_count = v_new_helpful_count,
    unhelpful_count = v_new_unhelpful_count
  WHERE id = p_review_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'helpful_count', v_new_helpful_count,
    'unhelpful_count', v_new_unhelpful_count
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'internal_error',
      'message', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.vote_review_helpful IS 'تصويت على التقييم (مع إعادة حساب دقيقة لكل review)';

-- 5. عرض النتائج النهائية
DO $$
DECLARE
  v_sample record;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ تم إصلاح النظام بنجاح!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 عينة من التقييمات بعد الإصلاح:';
  
  FOR v_sample IN 
    SELECT 
      pr.id,
      pr.helpful_count,
      pr.unhelpful_count,
      (SELECT COUNT(*) FROM review_helpful_votes WHERE review_id = pr.id AND is_helpful = true) as actual_helpful,
      (SELECT COUNT(*) FROM review_helpful_votes WHERE review_id = pr.id AND is_helpful = false) as actual_unhelpful
    FROM public.product_reviews pr
    LIMIT 5
  LOOP
    RAISE NOTICE '   Review %:', v_sample.id;
    RAISE NOTICE '      Stored: helpful=%, unhelpful=%', v_sample.helpful_count, v_sample.unhelpful_count;
    RAISE NOTICE '      Actual: helpful=%, unhelpful=%', v_sample.actual_helpful, v_sample.actual_unhelpful;
  END LOOP;
  
  RAISE NOTICE '';
END $$;
