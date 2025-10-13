-- ============================================================================
-- التحقق من وجود العمود وإصلاح أي مشاكل
-- ============================================================================

-- 1. التحقق من وجود العمود unhelpful_count
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'product_reviews' 
      AND column_name = 'unhelpful_count'
  ) THEN
    ALTER TABLE public.product_reviews ADD COLUMN unhelpful_count int DEFAULT 0;
    RAISE NOTICE '✅ تم إضافة عمود unhelpful_count';
  ELSE
    RAISE NOTICE '✓ عمود unhelpful_count موجود بالفعل';
  END IF;
END $$;

-- 2. تحديث القيم الـ NULL إلى 0
UPDATE public.product_reviews 
SET unhelpful_count = 0 
WHERE unhelpful_count IS NULL;

-- 3. التحقق من أن القيم موجودة بشكل صحيح
DO $$
DECLARE
  v_sample_count int;
BEGIN
  SELECT COUNT(*) INTO v_sample_count
  FROM public.product_reviews
  WHERE helpful_count IS NOT NULL AND unhelpful_count IS NOT NULL;
  
  RAISE NOTICE '✅ عدد التقييمات التي لها قيم صحيحة: %', v_sample_count;
END $$;

-- 4. إعادة إنشاء الـ view بشكل صحيح
DROP VIEW IF EXISTS public.product_reviews_with_details CASCADE;

CREATE VIEW public.product_reviews_with_details 
WITH (security_invoker = true) AS
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
  COALESCE(pr.helpful_count, 0) as helpful_count, 
  COALESCE(pr.unhelpful_count, 0) as unhelpful_count,
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

COMMENT ON VIEW public.product_reviews_with_details IS 'عرض التقييمات مع helpful و unhelpful counts (مع COALESCE)';

-- 5. إعادة إنشاء my_product_reviews view
DROP VIEW IF EXISTS public.my_product_reviews CASCADE;
CREATE VIEW public.my_product_reviews 
WITH (security_invoker = true) AS
SELECT * FROM public.product_reviews_with_details
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- 6. عرض بيانات عينة للتأكد
DO $$
DECLARE
  v_sample record;
BEGIN
  SELECT 
    id, 
    helpful_count, 
    unhelpful_count 
  INTO v_sample
  FROM public.product_reviews
  LIMIT 1;
  
  IF v_sample IS NOT NULL THEN
    RAISE NOTICE '📊 عينة من البيانات:';
    RAISE NOTICE '   Review ID: %', v_sample.id;
    RAISE NOTICE '   Helpful Count: %', v_sample.helpful_count;
    RAISE NOTICE '   Unhelpful Count: %', v_sample.unhelpful_count;
  END IF;
END $$;

-- ============================================================================
-- نهاية
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ تم التحقق والإصلاح بنجاح!';
  RAISE NOTICE '👍 العمود unhelpful_count جاهز';
  RAISE NOTICE '👁️ الـ views محدثة مع COALESCE';
  RAISE NOTICE '';
END $$;
