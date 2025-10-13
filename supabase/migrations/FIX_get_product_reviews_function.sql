-- ============================================================================
-- إصلاح دالة get_product_reviews لإرجاع unhelpful_count
-- ============================================================================

-- حذف وإعادة إنشاء دالة get_product_reviews
DROP FUNCTION IF EXISTS public.get_product_reviews(text, product_type_enum, text, int, int) CASCADE;

CREATE OR REPLACE FUNCTION public.get_product_reviews(
  p_product_id text,
  p_product_type product_type_enum DEFAULT 'product',
  p_sort_by text DEFAULT 'recent',
  p_limit int DEFAULT 20,
  p_offset int DEFAULT 0
)
RETURNS TABLE(
  id uuid,
  review_request_id uuid,
  product_id text,
  product_type product_type_enum,
  user_id uuid,
  user_name text,
  user_photo text,
  rating smallint,
  comment text,
  has_comment boolean,
  is_verified_purchase boolean,
  helpful_count int,
  unhelpful_count int,
  current_user_voted_helpful boolean,
  current_user_voted_unhelpful boolean,
  created_at timestamptz,
  updated_at timestamptz,
  product_name text,
  request_avg_rating numeric,
  days_since_review int
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
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
    ) as current_user_voted_unhelpful,
    pr.created_at,
    pr.updated_at,
    rr.product_name,
    rr.avg_rating as request_avg_rating,
    EXTRACT(DAY FROM now() - pr.created_at)::int as days_since_review
  FROM public.product_reviews pr
  LEFT JOIN public.users u ON u.id = pr.user_id
  LEFT JOIN public.review_requests rr ON rr.id = pr.review_request_id
  WHERE pr.product_id = p_product_id
    AND pr.product_type = p_product_type
  ORDER BY
    CASE 
      WHEN p_sort_by = 'recent' THEN pr.created_at
      ELSE NULL
    END DESC,
    CASE 
      WHEN p_sort_by = 'helpful' THEN pr.helpful_count
      ELSE NULL
    END DESC,
    CASE 
      WHEN p_sort_by = 'rating_high' THEN pr.rating
      ELSE NULL
    END DESC,
    CASE 
      WHEN p_sort_by = 'rating_low' THEN pr.rating
      ELSE NULL
    END ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION public.get_product_reviews IS 'جلب تقييمات المنتج مع unhelpful_count';

-- اختبار الدالة
DO $$
DECLARE
  v_test_result record;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🧪 اختبار دالة get_product_reviews:';
  
  FOR v_test_result IN 
    SELECT * FROM public.get_product_reviews(
      (SELECT product_id::text FROM public.product_reviews LIMIT 1),
      'product'::product_type_enum,
      'recent',
      1,
      0
    )
  LOOP
    RAISE NOTICE '📦 Review: id=%, helpful=%, unhelpful=%', 
      v_test_result.id, 
      v_test_result.helpful_count, 
      v_test_result.unhelpful_count;
  END LOOP;
  
  RAISE NOTICE '';
END $$;

-- رسالة نهائية
DO $$
BEGIN
  RAISE NOTICE '✅ تم إصلاح دالة get_product_reviews!';
  RAISE NOTICE '📊 الدالة الآن ترجع unhelpful_count بشكل صحيح';
END $$;
