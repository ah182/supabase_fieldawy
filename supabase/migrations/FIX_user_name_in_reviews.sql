-- ============================================================================
-- إصلاح user_name في التقييمات
-- ============================================================================

-- 1. التحقق من أسماء الأعمدة في جدول users
DO $$
DECLARE
  v_column_name text;
BEGIN
  RAISE NOTICE '📋 الأعمدة الموجودة في جدول users:';
  FOR v_column_name IN 
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_name = 'users' 
      AND table_schema = 'public'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '   - %', v_column_name;
  END LOOP;
END $$;

-- 2. إعادة إنشاء دالة get_product_reviews مع إصلاح user_name
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
    -- جلب الاسم من جدول users (display_name أو email)
    COALESCE(u.display_name, u.email, pr.user_name, 'مستخدم')::text as user_name,
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

-- 3. تحديث الـ view أيضاً
DROP VIEW IF EXISTS public.product_reviews_with_details CASCADE;

CREATE VIEW public.product_reviews_with_details AS
SELECT 
  pr.id, 
  pr.review_request_id, 
  pr.product_id, 
  pr.product_type,
  pr.user_id, 
  COALESCE(u.display_name, u.email, pr.user_name, 'مستخدم')::text as user_name,
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

-- 4. اختبار
DO $$
DECLARE
  v_test record;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🧪 اختبار جلب الأسماء:';
  
  FOR v_test IN 
    SELECT 
      pr.id,
      pr.user_id,
      u.display_name,
      u.email,
      COALESCE(u.display_name, u.email, 'مستخدم') as final_name
    FROM public.product_reviews pr
    LEFT JOIN public.users u ON u.id = pr.user_id
    LIMIT 3
  LOOP
    RAISE NOTICE '   Review %:', v_test.id;
    RAISE NOTICE '      display_name: %', v_test.display_name;
    RAISE NOTICE '      email: %', v_test.email;
    RAISE NOTICE '      final_name: %', v_test.final_name;
  END LOOP;
  
  RAISE NOTICE '';
END $$;

-- 5. رسالة نهائية
DO $$
BEGIN
  RAISE NOTICE '✅ تم إصلاح user_name في التقييمات!';
  RAISE NOTICE '👤 الآن يستخدم: display_name أو email أو "مستخدم"';
END $$;
