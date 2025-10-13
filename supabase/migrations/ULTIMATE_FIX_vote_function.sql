-- ============================================================================
-- الحل النهائي: إصلاح دالة التصويت بشكل كامل
-- ============================================================================

-- 1. التحقق من وجود العمود وإضافته إذا لزم الأمر
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'product_reviews' AND column_name = 'unhelpful_count'
  ) THEN
    ALTER TABLE public.product_reviews ADD COLUMN unhelpful_count int DEFAULT 0 NOT NULL;
    RAISE NOTICE '✅ تم إضافة عمود unhelpful_count';
  ELSE
    -- تحديث القيم NULL إلى 0
    UPDATE public.product_reviews SET unhelpful_count = 0 WHERE unhelpful_count IS NULL;
    -- تأكيد أن العمود NOT NULL
    ALTER TABLE public.product_reviews ALTER COLUMN unhelpful_count SET DEFAULT 0;
    ALTER TABLE public.product_reviews ALTER COLUMN unhelpful_count SET NOT NULL;
    RAISE NOTICE '✅ عمود unhelpful_count موجود ومُحدث';
  END IF;
  
  -- التأكد من helpful_count أيضاً
  UPDATE public.product_reviews SET helpful_count = 0 WHERE helpful_count IS NULL;
  ALTER TABLE public.product_reviews ALTER COLUMN helpful_count SET DEFAULT 0;
  ALTER TABLE public.product_reviews ALTER COLUMN helpful_count SET NOT NULL;
END $$;

-- 2. حذف وإعادة إنشاء دالة vote_review_helpful بشكل مبسط وواضح
DROP FUNCTION IF EXISTS public.vote_review_helpful(uuid, boolean) CASCADE;

CREATE OR REPLACE FUNCTION public.vote_review_helpful(
  p_review_id uuid,
  p_is_helpful boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_existing_vote_id uuid;
  v_existing_is_helpful boolean;
  v_new_helpful_count int;
  v_new_unhelpful_count int;
BEGIN
  -- الحصول على user_id
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- البحث عن تصويت سابق
  SELECT id, is_helpful 
  INTO v_existing_vote_id, v_existing_is_helpful
  FROM public.review_helpful_votes
  WHERE review_id = p_review_id AND user_id = v_user_id;
  
  -- معالجة التصويت
  IF v_existing_vote_id IS NOT NULL THEN
    -- يوجد تصويت سابق
    IF v_existing_is_helpful = p_is_helpful THEN
      -- نفس النوع - حذفه
      DELETE FROM public.review_helpful_votes WHERE id = v_existing_vote_id;
      RAISE NOTICE 'Deleted existing vote %', v_existing_vote_id;
    ELSE
      -- نوع مختلف - تحديثه
      UPDATE public.review_helpful_votes
      SET is_helpful = p_is_helpful, created_at = now()
      WHERE id = v_existing_vote_id;
      RAISE NOTICE 'Changed vote % from % to %', v_existing_vote_id, v_existing_is_helpful, p_is_helpful;
    END IF;
  ELSE
    -- تصويت جديد
    INSERT INTO public.review_helpful_votes (review_id, user_id, is_helpful)
    VALUES (p_review_id, v_user_id, p_is_helpful);
    RAISE NOTICE 'Added new vote for review %', p_review_id;
  END IF;
  
  -- إعادة حساب الأعداد من جدول الـ votes
  SELECT 
    COUNT(*) FILTER (WHERE is_helpful = true),
    COUNT(*) FILTER (WHERE is_helpful = false)
  INTO v_new_helpful_count, v_new_unhelpful_count
  FROM public.review_helpful_votes
  WHERE review_id = p_review_id;
  
  RAISE NOTICE 'Recalculated counts: helpful=%, unhelpful=%', v_new_helpful_count, v_new_unhelpful_count;
  
  -- تحديث الجدول
  UPDATE public.product_reviews
  SET 
    helpful_count = v_new_helpful_count,
    unhelpful_count = v_new_unhelpful_count
  WHERE id = p_review_id;
  
  -- التحقق من التحديث
  RAISE NOTICE 'Updated review % with counts', p_review_id;
  
  -- إرجاع النتيجة
  RETURN jsonb_build_object(
    'success', true,
    'helpful_count', v_new_helpful_count,
    'unhelpful_count', v_new_unhelpful_count
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'ERROR: %', SQLERRM;
    RETURN jsonb_build_object(
      'success', false,
      'error', 'internal_error',
      'message', SQLERRM
    );
END;
$$;

COMMENT ON FUNCTION public.vote_review_helpful IS 'تصويت على التقييم مع إعادة حساب دقيقة';

-- 3. إعادة إنشاء الـ view
DROP VIEW IF EXISTS public.product_reviews_with_details CASCADE;

CREATE VIEW public.product_reviews_with_details AS
SELECT 
  pr.id, 
  pr.review_request_id, 
  pr.product_id, 
  pr.product_type,
  pr.user_id, 
  pr.user_name, 
  u.photo_url as user_photo,
  pr.rating, 
  pr.comment, 
  pr.has_comment, 
  pr.is_verified_purchase,
  pr.helpful_count, 
  pr.unhelpful_count,
  pr.created_at, 
  pr.updated_at,
  rr.product_name, 
  rr.avg_rating as request_avg_rating,
  EXTRACT(DAY FROM now() - pr.created_at)::int as days_since_review,
  EXISTS(
    SELECT 1 FROM public.review_helpful_votes rhv
    WHERE rhv.review_id = pr.id 
      AND rhv.user_id = auth.uid() 
      AND rhv.is_helpful = true
  ) as current_user_voted_helpful,
  EXISTS(
    SELECT 1 FROM public.review_helpful_votes rhv
    WHERE rhv.review_id = pr.id 
      AND rhv.user_id = auth.uid() 
      AND rhv.is_helpful = false
  ) as current_user_voted_unhelpful
FROM public.product_reviews pr
LEFT JOIN public.users u ON u.id = pr.user_id
LEFT JOIN public.review_requests rr ON rr.id = pr.review_request_id;

-- إعادة إنشاء my_product_reviews
DROP VIEW IF EXISTS public.my_product_reviews CASCADE;
CREATE VIEW public.my_product_reviews AS
SELECT * FROM public.product_reviews_with_details
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- 4. اختبار نهائي
DO $$
DECLARE
  v_test_review_id uuid;
  v_result jsonb;
  v_helpful int;
  v_unhelpful int;
BEGIN
  -- أخذ أول review
  SELECT id INTO v_test_review_id FROM public.product_reviews LIMIT 1;
  
  IF v_test_review_id IS NOT NULL THEN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 اختبار الدالة على review: %', v_test_review_id;
    
    -- قراءة القيم الحالية
    SELECT helpful_count, unhelpful_count 
    INTO v_helpful, v_unhelpful
    FROM public.product_reviews 
    WHERE id = v_test_review_id;
    
    RAISE NOTICE '📊 القيم الحالية: helpful=%, unhelpful=%', v_helpful, v_unhelpful;
    RAISE NOTICE '';
  END IF;
END $$;

-- 5. رسالة نهائية
DO $$
BEGIN
  RAISE NOTICE '✅ تم تطبيق الإصلاح النهائي!';
  RAISE NOTICE '👍 دالة vote_review_helpful محدثة مع RAISE NOTICE للـ debugging';
  RAISE NOTICE '📊 الأعمدة helpful_count و unhelpful_count الآن NOT NULL';
  RAISE NOTICE '👁️ الـ view محدث';
END $$;
