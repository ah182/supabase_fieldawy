-- ============================================================================
-- إنشاء دالة get_product_reviews لاسترجاع تقييمات المنتج
-- ============================================================================

-- حذف جميع نسخ الدالة القديمة
DROP FUNCTION IF EXISTS public.get_product_reviews(text, product_type_enum, text, int, int);
DROP FUNCTION IF EXISTS public.get_product_reviews(uuid, product_type_enum, text, int, int);
DROP FUNCTION IF EXISTS public.get_product_reviews;

CREATE OR REPLACE FUNCTION public.get_product_reviews(
  p_product_id text,
  p_product_type product_type_enum DEFAULT 'product',
  p_sort_by text DEFAULT 'recent',
  p_limit int DEFAULT 20,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
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
  current_user_voted_helpful boolean,
  created_at timestamptz,
  updated_at timestamptz,
  product_name text
) AS $$
DECLARE
  v_current_user_id uuid;
BEGIN
  -- الحصول على معرف المستخدم الحالي
  v_current_user_id := auth.uid();
  
  -- استرجاع التقييمات بناءً على نوع الترتيب
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
    pr.helpful_count,
    EXISTS(
      SELECT 1 FROM public.review_helpful_votes rhv
      WHERE rhv.review_id = pr.id
        AND rhv.user_id = v_current_user_id
        AND rhv.is_helpful = true
    ) as current_user_voted_helpful,
    pr.created_at,
    pr.updated_at,
    rr.product_name
  FROM public.product_reviews pr
  LEFT JOIN public.review_requests rr ON pr.review_request_id = rr.id
  LEFT JOIN public.users u ON pr.user_id = u.id
  WHERE pr.product_id = p_product_id
    AND pr.product_type = p_product_type
  ORDER BY
    CASE 
      WHEN p_sort_by = 'recent' THEN pr.created_at
      ELSE pr.created_at
    END DESC,
    CASE 
      WHEN p_sort_by = 'helpful' THEN pr.helpful_count
      ELSE 0
    END DESC,
    CASE 
      WHEN p_sort_by = 'rating_high' THEN pr.rating
      ELSE 0
    END DESC,
    CASE 
      WHEN p_sort_by = 'rating_low' THEN pr.rating
      ELSE 5
    END ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_product_reviews IS 'استرجاع تقييمات منتج مع إمكانية الترتيب والترقيم';

-- ============================================================================
-- إنشاء view بسيط للتقييمات مع التفاصيل (إذا لم يكن موجوداً)
-- ============================================================================

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
  pr.created_at,
  pr.updated_at,
  rr.product_name
FROM public.product_reviews pr
LEFT JOIN public.review_requests rr ON pr.review_request_id = rr.id
LEFT JOIN public.users u ON pr.user_id = u.id;

COMMENT ON VIEW public.product_reviews_with_details IS 'عرض التقييمات مع التفاصيل الكاملة';

-- ============================================================================
-- إنشاء view لطلبات التقييم مع التفاصيل (إذا لم يكن موجوداً)
-- ============================================================================

DROP VIEW IF EXISTS public.review_requests_with_details CASCADE;

CREATE VIEW public.review_requests_with_details AS
SELECT 
  rr.id,
  rr.product_id,
  rr.product_type,
  rr.product_name,
  rr.requested_by,
  rr.requester_name,
  u.photo_url as requester_photo,
  rr.status,
  rr.comments_count,
  rr.total_reviews_count,
  rr.avg_rating,
  rr.requested_at,
  rr.closed_at,
  rr.closed_reason,
  rr.created_at,
  rr.updated_at,
  (rr.comments_count >= 5) as is_comments_full,
  (rr.status = 'active' AND rr.comments_count < 5) as can_add_comment
FROM public.review_requests rr
LEFT JOIN public.users u ON rr.requested_by = u.id;

COMMENT ON VIEW public.review_requests_with_details IS 'عرض طلبات التقييم مع التفاصيل الكاملة';

-- ============================================================================
-- إنشاء view لطلبات التقييم الخاصة بالمستخدم
-- ============================================================================

DROP VIEW IF EXISTS public.my_review_requests CASCADE;

CREATE VIEW public.my_review_requests AS
SELECT 
  rr.*,
  u.photo_url as requester_photo,
  (rr.comments_count >= 5) as is_comments_full,
  (rr.status = 'active' AND rr.comments_count < 5) as can_add_comment
FROM public.review_requests rr
LEFT JOIN public.users u ON rr.requested_by = u.id
WHERE rr.requested_by = auth.uid();

COMMENT ON VIEW public.my_review_requests IS 'عرض طلبات التقييم الخاصة بالمستخدم الحالي';

-- ============================================================================
-- نهاية
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ تم إنشاء دالة get_product_reviews والـ views بنجاح!';
  RAISE NOTICE '📊 يمكنك الآن استرجاع التقييمات مع التعليقات';
  RAISE NOTICE '';
  RAISE NOTICE 'مثال على الاستخدام:';
  RAISE NOTICE '  SELECT * FROM get_product_reviews(''product-id'', ''product'', ''recent'', 20, 0);';
END $$;
