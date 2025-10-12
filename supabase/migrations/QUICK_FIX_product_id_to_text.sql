-- ============================================================================
-- QUICK FIX: product_id to TEXT (حل سريع)
-- ============================================================================

-- حذف Views
DROP VIEW IF EXISTS public.review_requests_with_details CASCADE;
DROP VIEW IF EXISTS public.product_reviews_with_details CASCADE;
DROP VIEW IF EXISTS public.products_with_review_stats CASCADE;
DROP VIEW IF EXISTS public.user_review_activity CASCADE;

-- تغيير نوع Columns
ALTER TABLE public.review_requests 
ALTER COLUMN product_id TYPE text 
USING product_id::text;

ALTER TABLE public.product_reviews 
ALTER COLUMN product_id TYPE text 
USING product_id::text;

-- إعادة إنشاء Indexes
DROP INDEX IF EXISTS public.idx_review_requests_product;
CREATE INDEX idx_review_requests_product ON public.review_requests(product_id, product_type);

DROP INDEX IF EXISTS public.idx_product_reviews_product;
CREATE INDEX idx_product_reviews_product ON public.product_reviews(product_id);

-- إعادة إنشاء Views الأساسية
CREATE VIEW public.review_requests_with_details 
WITH (security_invoker = true) AS
SELECT 
  rr.id, rr.product_id, rr.product_type, rr.product_name,
  rr.requested_by, rr.requester_name, u.photo_url as requester_photo,
  rr.status, rr.comments_count, rr.total_reviews_count, rr.avg_rating,
  rr.total_rating_sum, rr.requested_at, rr.closed_at, rr.closed_reason,
  rr.created_at, rr.updated_at,
  CASE WHEN rr.comments_count >= 5 THEN true ELSE false END as is_comments_full,
  CASE WHEN rr.status = 'active' THEN true ELSE false END as can_add_comment,
  EXTRACT(DAY FROM now() - rr.requested_at)::int as days_since_request
FROM public.review_requests rr
LEFT JOIN public.users u ON u.id = rr.requested_by;

CREATE VIEW public.product_reviews_with_details 
WITH (security_invoker = true) AS
SELECT 
  pr.id, pr.review_request_id, pr.product_id, pr.product_type,
  pr.user_id, pr.user_name, u.photo_url as user_photo,
  pr.rating, pr.comment, pr.has_comment, pr.is_verified_purchase,
  pr.helpful_count, pr.created_at, pr.updated_at,
  rr.product_name, rr.avg_rating as request_avg_rating,
  EXTRACT(DAY FROM now() - pr.created_at)::int as days_since_review,
  EXISTS(
    SELECT 1 FROM public.review_helpful_votes rhv
    WHERE rhv.review_id = pr.id AND rhv.user_id = auth.uid() AND rhv.is_helpful = true
  ) as current_user_voted_helpful
FROM public.product_reviews pr
LEFT JOIN public.users u ON u.id = pr.user_id
LEFT JOIN public.review_requests rr ON rr.id = pr.review_request_id;

CREATE VIEW public.active_review_requests 
WITH (security_invoker = true) AS
SELECT * FROM public.review_requests_with_details
WHERE status = 'active'
ORDER BY requested_at DESC;

CREATE VIEW public.my_product_reviews 
WITH (security_invoker = true) AS
SELECT * FROM public.product_reviews_with_details
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- رسالة نجاح
DO $$
BEGIN
  RAISE NOTICE '✅ Done! product_id is now text (supports integer & UUID)';
END $$;
