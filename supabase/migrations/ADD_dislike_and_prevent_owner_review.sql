-- ============================================================================
-- إضافة زر Dislike + منع صاحب الطلب من التقييم
-- ============================================================================

-- ============================================================================
-- PART 1: إضافة عمود unhelpful_count
-- ============================================================================

ALTER TABLE public.product_reviews 
ADD COLUMN IF NOT EXISTS unhelpful_count int DEFAULT 0;

-- إنشاء index للأداء
CREATE INDEX IF NOT EXISTS idx_product_reviews_unhelpful 
ON public.product_reviews(unhelpful_count) 
WHERE unhelpful_count >= 10;

-- ============================================================================
-- PART 2: تحديث view لعرض unhelpful_count
-- ============================================================================

DROP VIEW IF EXISTS public.product_reviews_with_details CASCADE;

CREATE VIEW public.product_reviews_with_details 
WITH (security_invoker = true) AS
SELECT 
  pr.id, pr.review_request_id, pr.product_id, pr.product_type,
  pr.user_id, pr.user_name, u.photo_url as user_photo,
  pr.rating, pr.comment, pr.has_comment, pr.is_verified_purchase,
  pr.helpful_count, 
  pr.unhelpful_count,
  pr.created_at, pr.updated_at,
  rr.product_name, rr.avg_rating as request_avg_rating,
  EXTRACT(DAY FROM now() - pr.created_at)::int as days_since_review,
  EXISTS(
    SELECT 1 FROM public.review_helpful_votes rhv
    WHERE rhv.review_id = pr.id AND rhv.user_id = auth.uid() AND rhv.is_helpful = true
  ) as current_user_voted_helpful,
  EXISTS(
    SELECT 1 FROM public.review_helpful_votes rhv
    WHERE rhv.review_id = pr.id AND rhv.user_id = auth.uid() AND rhv.is_helpful = false
  ) as current_user_voted_unhelpful
FROM public.product_reviews pr
LEFT JOIN public.users u ON u.id = pr.user_id
LEFT JOIN public.review_requests rr ON rr.id = pr.review_request_id;

COMMENT ON VIEW public.product_reviews_with_details IS 'عرض التقييمات مع helpful و unhelpful counts';

-- إعادة إنشاء my_product_reviews view
DROP VIEW IF EXISTS public.my_product_reviews CASCADE;
CREATE VIEW public.my_product_reviews 
WITH (security_invoker = true) AS
SELECT * FROM public.product_reviews_with_details
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- ============================================================================
-- PART 3: تحديث دالة vote_review_helpful لدعم dislike
-- ============================================================================

DROP FUNCTION IF EXISTS public.vote_review_helpful(uuid, boolean);

CREATE OR REPLACE FUNCTION public.vote_review_helpful(
  p_review_id uuid,
  p_is_helpful boolean
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_existing_vote boolean;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- التحقق من وجود تصويت سابق
  SELECT is_helpful INTO v_existing_vote
  FROM public.review_helpful_votes
  WHERE review_id = p_review_id AND user_id = v_user_id;
  
  IF v_existing_vote IS NOT NULL THEN
    -- إذا كان نفس التصويت، حذفه (toggle)
    IF v_existing_vote = p_is_helpful THEN
      DELETE FROM public.review_helpful_votes
      WHERE review_id = p_review_id AND user_id = v_user_id;
      
      -- تحديث العداد
      IF p_is_helpful THEN
        UPDATE public.product_reviews
        SET helpful_count = GREATEST(0, helpful_count - 1)
        WHERE id = p_review_id;
      ELSE
        UPDATE public.product_reviews
        SET unhelpful_count = GREATEST(0, unhelpful_count - 1)
        WHERE id = p_review_id;
      END IF;
      
      RETURN jsonb_build_object('success', true, 'action', 'removed');
    ELSE
      -- تغيير التصويت من helpful إلى unhelpful أو العكس
      UPDATE public.review_helpful_votes
      SET is_helpful = p_is_helpful, created_at = now()
      WHERE review_id = p_review_id AND user_id = v_user_id;
      
      -- تحديث العدادات
      IF p_is_helpful THEN
        UPDATE public.product_reviews
        SET helpful_count = helpful_count + 1,
            unhelpful_count = GREATEST(0, unhelpful_count - 1)
        WHERE id = p_review_id;
      ELSE
        UPDATE public.product_reviews
        SET helpful_count = GREATEST(0, helpful_count - 1),
            unhelpful_count = unhelpful_count + 1
        WHERE id = p_review_id;
      END IF;
      
      RETURN jsonb_build_object('success', true, 'action', 'changed');
    END IF;
  ELSE
    -- إضافة تصويت جديد
    INSERT INTO public.review_helpful_votes (review_id, user_id, is_helpful)
    VALUES (p_review_id, v_user_id, p_is_helpful);
    
    -- تحديث العداد
    IF p_is_helpful THEN
      UPDATE public.product_reviews
      SET helpful_count = helpful_count + 1
      WHERE id = p_review_id;
    ELSE
      UPDATE public.product_reviews
      SET unhelpful_count = unhelpful_count + 1
      WHERE id = p_review_id;
    END IF;
    
    RETURN jsonb_build_object('success', true, 'action', 'added');
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'internal_error',
      'message', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.vote_review_helpful IS 'تصويت على التقييم (مفيد أو غير مفيد)';

-- ============================================================================
-- PART 4: Trigger لحذف التقييم عند 10 dislikes
-- ============================================================================

CREATE OR REPLACE FUNCTION public.auto_delete_unpopular_review()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.unhelpful_count >= 10 THEN
    -- حذف التقييم
    DELETE FROM public.product_reviews WHERE id = NEW.id;
    
    RAISE NOTICE 'تم حذف التقييم % تلقائياً بسبب وصول عدد "غير مفيد" إلى %', NEW.id, NEW.unhelpful_count;
    
    RETURN NULL; -- منع UPDATE لأن الصف تم حذفه
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_delete_unpopular_review ON public.product_reviews;

CREATE TRIGGER trigger_auto_delete_unpopular_review
AFTER UPDATE OF unhelpful_count ON public.product_reviews
FOR EACH ROW
WHEN (NEW.unhelpful_count >= 10)
EXECUTE FUNCTION public.auto_delete_unpopular_review();

COMMENT ON FUNCTION public.auto_delete_unpopular_review IS 'حذف التقييم تلقائياً عند وصول unhelpful_count إلى 10';

-- ============================================================================
-- PART 5: تعديل add_product_review لمنع صاحب الطلب من التقييم
-- ============================================================================

-- حذف جميع النسخ المحتملة من الدالة
DROP FUNCTION IF EXISTS public.add_product_review(uuid, int, text);
DROP FUNCTION IF EXISTS public.add_product_review(uuid, int);
DROP FUNCTION IF EXISTS public.add_product_review CASCADE;

CREATE OR REPLACE FUNCTION public.add_product_review(
  p_request_id uuid,
  p_rating int,
  p_comment text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_product_id text;
  v_product_type product_type_enum;
  v_existing_review_id uuid;
  v_comments_count int;
  v_request_status text;
  v_requested_by uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- جلب معلومات الطلب
  SELECT product_id, product_type, comments_count, status, requested_by
  INTO v_product_id, v_product_type, v_comments_count, v_request_status, v_requested_by
  FROM public.review_requests
  WHERE id = p_request_id;
  
  IF v_product_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'request_not_found',
      'message', 'طلب التقييم غير موجود'
    );
  END IF;
  
  -- ✅ منع صاحب الطلب من التقييم
  IF v_requested_by = v_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'owner_cannot_review',
      'message', 'لا يمكنك تقييم طلبك الخاص'
    );
  END IF;
  
  IF v_request_status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'request_closed',
      'message', 'طلب التقييم مغلق'
    );
  END IF;
  
  -- التحقق من التقييم
  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_rating',
      'message', 'التقييم يجب أن يكون بين 1 و 5'
    );
  END IF;
  
  -- التحقق من عدم وجود تقييم سابق
  SELECT id INTO v_existing_review_id
  FROM public.product_reviews
  WHERE review_request_id = p_request_id AND user_id = v_user_id;
  
  IF v_existing_review_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_reviewed',
      'message', 'لقد قمت بتقييم هذا المنتج مسبقاً'
    );
  END IF;
  
  -- التحقق من عدد التعليقات (إذا كان هناك تعليق)
  IF p_comment IS NOT NULL AND trim(p_comment) != '' THEN
    IF v_comments_count >= 5 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'comments_limit_reached',
        'message', 'تم الوصول للحد الأقصى من التعليقات (5)'
      );
    END IF;
  END IF;
  
  -- إضافة التقييم
  INSERT INTO public.product_reviews (
    review_request_id,
    product_id,
    product_type,
    user_id,
    rating,
    comment
  ) VALUES (
    p_request_id,
    v_product_id,
    v_product_type,
    v_user_id,
    p_rating,
    CASE 
      WHEN p_comment IS NOT NULL AND trim(p_comment) != '' 
      THEN trim(p_comment) 
      ELSE NULL 
    END
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم إضافة التقييم بنجاح'
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

COMMENT ON FUNCTION public.add_product_review IS 'إضافة تقييم (مع منع صاحب الطلب من التقييم)';

-- ============================================================================
-- نهاية
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ تم تطبيق التحديثات بنجاح!';
  RAISE NOTICE '👍 إضافة زر Dislike مع unhelpful_count';
  RAISE NOTICE '🗑️ حذف تلقائي للتقييم عند 10 dislikes';
  RAISE NOTICE '🚫 منع صاحب الطلب من التقييم';
END $$;
