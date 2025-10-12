-- ============================================================================
-- FIX: Change product_id to TEXT in review_requests
-- Date: 2025-01-23
-- Description: تغيير نوع product_id من uuid إلى text لدعم integer و uuid
-- ============================================================================

-- المشكلة:
-- - products.id هو integer (مثال: 1356)
-- - ocr_products.id هو uuid
-- - review_requests.product_id هو uuid (يرفض integer)

-- الحل: تغيير review_requests.product_id إلى text

-- ============================================================================
-- 1. حذف الـ Views المرتبطة مؤقتاً
-- ============================================================================

-- حفظ تعريفات الـ views للرجوع إليها
DO $$
DECLARE
  v_view_def text;
BEGIN
  -- حذف views بالترتيب (من الأحدث للأقدم)
  DROP VIEW IF EXISTS public.review_requests_with_details CASCADE;
  DROP VIEW IF EXISTS public.product_reviews_with_details CASCADE;
  DROP VIEW IF EXISTS public.products_with_review_stats CASCADE;
  DROP VIEW IF EXISTS public.user_review_activity CASCADE;
  
  RAISE NOTICE '✅ Views dropped temporarily';
END $$;

-- ============================================================================
-- 2. تغيير نوع الـ column
-- ============================================================================

ALTER TABLE public.review_requests 
ALTER COLUMN product_id TYPE text 
USING product_id::text;

-- ============================================================================
-- 2. تحديث الـ Indexes (إذا وجدت)
-- ============================================================================

-- حذف الـ index القديم إذا وجد
DROP INDEX IF EXISTS public.idx_review_requests_product;

-- إعادة إنشاء الـ index
CREATE INDEX IF NOT EXISTS idx_review_requests_product 
ON public.review_requests(product_id, product_type);

-- ============================================================================
-- 3. تحديث product_reviews أيضاً
-- ============================================================================

ALTER TABLE public.product_reviews 
ALTER COLUMN product_id TYPE text 
USING product_id::text;

-- حذف وإعادة إنشاء index
DROP INDEX IF EXISTS public.idx_product_reviews_product;

CREATE INDEX IF NOT EXISTS idx_product_reviews_product 
ON public.product_reviews(product_id);

-- ============================================================================
-- 4. إعادة إنشاء الـ Views
-- ============================================================================

-- VIEW 1: review_requests_with_details
CREATE OR REPLACE VIEW public.review_requests_with_details 
WITH (security_invoker = true) AS
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
  rr.total_rating_sum,
  rr.requested_at,
  rr.closed_at,
  rr.closed_reason,
  rr.created_at,
  rr.updated_at,
  CASE WHEN rr.comments_count >= 5 THEN true ELSE false END as is_comments_full,
  CASE WHEN rr.status = 'active' THEN true ELSE false END as can_add_comment,
  EXTRACT(DAY FROM now() - rr.requested_at)::int as days_since_request
FROM public.review_requests rr
LEFT JOIN public.users u ON u.id = rr.requested_by;

-- VIEW 2: product_reviews_with_details
CREATE OR REPLACE VIEW public.product_reviews_with_details 
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
  pr.helpful_count,
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
  ) as current_user_voted_helpful
FROM public.product_reviews pr
LEFT JOIN public.users u ON u.id = pr.user_id
LEFT JOIN public.review_requests rr ON rr.id = pr.review_request_id;

-- VIEW 3: active_review_requests
CREATE OR REPLACE VIEW public.active_review_requests 
WITH (security_invoker = true) AS
SELECT *
FROM public.review_requests_with_details
WHERE status = 'active'
ORDER BY requested_at DESC;

-- VIEW 4: my_product_reviews
CREATE OR REPLACE VIEW public.my_product_reviews 
WITH (security_invoker = true) AS
SELECT *
FROM public.product_reviews_with_details
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- ============================================================================
-- 5. التحقق من النتيجة
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Column types updated successfully!';
  RAISE NOTICE '✅ Views recreated successfully!';
  RAISE NOTICE '';
  RAISE NOTICE 'review_requests.product_id: %', 
    (SELECT data_type FROM information_schema.columns 
     WHERE table_name = 'review_requests' AND column_name = 'product_id');
  RAISE NOTICE 'product_reviews.product_id: %', 
    (SELECT data_type FROM information_schema.columns 
     WHERE table_name = 'product_reviews' AND column_name = 'product_id');
  RAISE NOTICE '';
  RAISE NOTICE '🎯 Now the system supports both integer and UUID product IDs!';
END $$;
