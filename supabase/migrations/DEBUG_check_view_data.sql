-- ============================================================================
-- فحص البيانات في الـ view والجدول
-- ============================================================================

-- 1. فحص البيانات في الجدول مباشرة
DO $$
DECLARE
  v_sample record;
BEGIN
  RAISE NOTICE '📊 البيانات في جدول product_reviews:';
  FOR v_sample IN 
    SELECT id, helpful_count, unhelpful_count 
    FROM public.product_reviews 
    LIMIT 3
  LOOP
    RAISE NOTICE '   Review %: helpful=%, unhelpful=%', 
      v_sample.id, v_sample.helpful_count, v_sample.unhelpful_count;
  END LOOP;
END $$;

-- 2. فحص البيانات في الـ view
DO $$
DECLARE
  v_sample record;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '👁️ البيانات في product_reviews_with_details:';
  FOR v_sample IN 
    SELECT id, helpful_count, unhelpful_count 
    FROM public.product_reviews_with_details 
    LIMIT 3
  LOOP
    RAISE NOTICE '   Review %: helpful=%, unhelpful=%', 
      v_sample.id, v_sample.helpful_count, v_sample.unhelpful_count;
  END LOOP;
END $$;

-- 3. إعادة إنشاء الـ view بشكل صحيح مع تأكيد استخدام COALESCE
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
  COALESCE(pr.helpful_count, 0)::int as helpful_count, 
  COALESCE(pr.unhelpful_count, 0)::int as unhelpful_count,
  pr.created_at, 
  pr.updated_at,
  rr.product_name, 
  rr.avg_rating as request_avg_rating,
  EXTRACT(DAY FROM now() - pr.created_at)::int as days_since_review,
  COALESCE(
    (SELECT true FROM public.review_helpful_votes rhv
     WHERE rhv.review_id = pr.id 
       AND rhv.user_id = auth.uid() 
       AND rhv.is_helpful = true
     LIMIT 1),
    false
  ) as current_user_voted_helpful,
  COALESCE(
    (SELECT true FROM public.review_helpful_votes rhv
     WHERE rhv.review_id = pr.id 
       AND rhv.user_id = auth.uid() 
       AND rhv.is_helpful = false
     LIMIT 1),
    false
  ) as current_user_voted_unhelpful
FROM public.product_reviews pr
LEFT JOIN public.users u ON u.id = pr.user_id
LEFT JOIN public.review_requests rr ON rr.id = pr.review_request_id;

COMMENT ON VIEW public.product_reviews_with_details IS 'عرض التقييمات مع helpful و unhelpful counts (محدث)';

-- إعادة إنشاء my_product_reviews view
DROP VIEW IF EXISTS public.my_product_reviews CASCADE;
CREATE VIEW public.my_product_reviews AS
SELECT * FROM public.product_reviews_with_details
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- 4. اختبار البيانات بعد التحديث
DO $$
DECLARE
  v_sample record;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ البيانات بعد التحديث:';
  FOR v_sample IN 
    SELECT id, helpful_count, unhelpful_count 
    FROM public.product_reviews_with_details 
    LIMIT 3
  LOOP
    RAISE NOTICE '   Review %: helpful=%, unhelpful=%', 
      v_sample.id, v_sample.helpful_count, v_sample.unhelpful_count;
  END LOOP;
END $$;
