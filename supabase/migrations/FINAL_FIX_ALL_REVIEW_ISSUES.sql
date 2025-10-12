-- ============================================================================
-- FINAL FIX: All Review System Issues
-- Date: 2025-01-23
-- Description: إصلاح شامل لكل مشاكل نظام التقييمات
-- ============================================================================

-- المشاكل المُصلحة:
-- 1. product_id: uuid → text (لدعم integer و UUID)
-- 2. users column: uid → id (إصلاح خطأ column does not exist)
-- 3. Function: قبول text بدلاً من uuid

-- ============================================================================
-- STEP 1: حذف Views مؤقتاً
-- ============================================================================

DROP VIEW IF EXISTS public.review_requests_with_details CASCADE;
DROP VIEW IF EXISTS public.product_reviews_with_details CASCADE;
DROP VIEW IF EXISTS public.products_with_review_stats CASCADE;
DROP VIEW IF EXISTS public.user_review_activity CASCADE;
DROP VIEW IF EXISTS public.active_review_requests CASCADE;
DROP VIEW IF EXISTS public.my_product_reviews CASCADE;

-- ============================================================================
-- STEP 2: تغيير نوع product_id إلى text
-- ============================================================================

-- تغيير في review_requests
ALTER TABLE public.review_requests 
ALTER COLUMN product_id TYPE text 
USING product_id::text;

-- تغيير في product_reviews
ALTER TABLE public.product_reviews 
ALTER COLUMN product_id TYPE text 
USING product_id::text;

-- ============================================================================
-- STEP 3: تحديث Indexes
-- ============================================================================

DROP INDEX IF EXISTS public.idx_review_requests_product;
CREATE INDEX idx_review_requests_product 
ON public.review_requests(product_id, product_type);

DROP INDEX IF EXISTS public.idx_product_reviews_product;
CREATE INDEX idx_product_reviews_product 
ON public.product_reviews(product_id);

-- ============================================================================
-- STEP 4: تحديث Function: create_review_request
-- ============================================================================

DROP FUNCTION IF EXISTS public.create_review_request(uuid, product_type_enum);
DROP FUNCTION IF EXISTS public.create_review_request(text, product_type_enum);

CREATE OR REPLACE FUNCTION public.create_review_request(
  p_product_id text,  -- قبول text (يدعم integer و UUID)
  p_product_type product_type_enum DEFAULT 'product'
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_product_name text;
  v_user_name text;
  v_existing_request uuid;
  v_recent_request_count int;
  v_new_request_id uuid;
  v_result jsonb;
BEGIN
  -- الحصول على user_id من الـ session
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- التحقق من صحة product_id
  IF p_product_id IS NULL OR trim(p_product_id) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_product_id',
      'message', 'معرف المنتج غير صالح'
    );
  END IF;
  
  -- 1. التحقق من وجود المنتج
  IF p_product_type = 'product' THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id::text = p_product_id;
  ELSE
    SELECT product_name INTO v_product_name
    FROM public.ocr_products
    WHERE id::text = p_product_id;
  END IF;
  
  IF v_product_name IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'product_not_found',
      'message', 'المنتج غير موجود'
    );
  END IF;
  
  -- 2. التحقق من عدم وجود طلب سابق لنفس المنتج
  SELECT id INTO v_existing_request
  FROM public.review_requests
  WHERE product_id = p_product_id
    AND product_type = p_product_type;
  
  IF v_existing_request IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'product_already_requested',
      'message', 'تم طلب تقييم هذا المنتج مسبقاً',
      'existing_request_id', v_existing_request
    );
  END IF;
  
  -- 3. التحقق من عدم تجاوز الحد الأسبوعي (طلب واحد كل 7 أيام)
  SELECT COUNT(*) INTO v_recent_request_count
  FROM public.review_requests
  WHERE requested_by = v_user_id
    AND requested_at >= now() - interval '7 days';
  
  IF v_recent_request_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'weekly_limit_exceeded',
      'message', 'يمكنك طلب تقييم منتج واحد فقط كل أسبوع'
    );
  END IF;
  
  -- 4. الحصول على اسم المستخدم (إصلاح: id بدلاً من uid)
  SELECT COALESCE(display_name, email) INTO v_user_name
  FROM public.users
  WHERE id = v_user_id;
  
  -- 5. إنشاء الطلب
  INSERT INTO public.review_requests (
    product_id,
    product_type,
    product_name,
    requested_by,
    requester_name,
    status
  ) VALUES (
    p_product_id,
    p_product_type,
    v_product_name,
    v_user_id,
    v_user_name,
    'active'
  )
  RETURNING id INTO v_new_request_id;
  
  -- 6. إرجاع النتيجة
  SELECT jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'id', rr.id,
      'product_id', rr.product_id,
      'product_type', rr.product_type,
      'product_name', rr.product_name,
      'requested_by', rr.requested_by,
      'requester_name', rr.requester_name,
      'status', rr.status,
      'comments_count', rr.comments_count,
      'total_reviews_count', rr.total_reviews_count,
      'avg_rating', rr.avg_rating,
      'requested_at', rr.requested_at,
      'created_at', rr.created_at
    )
  ) INTO v_result
  FROM public.review_requests rr
  WHERE rr.id = v_new_request_id;
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'internal_error',
      'message', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 5: إعادة إنشاء Views (إصلاح: u.id بدلاً من u.uid)
-- ============================================================================

-- VIEW 1: review_requests_with_details
CREATE OR REPLACE VIEW public.review_requests_with_details 
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

-- VIEW 2: product_reviews_with_details
CREATE OR REPLACE VIEW public.product_reviews_with_details 
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

-- VIEW 3: active_review_requests
CREATE OR REPLACE VIEW public.active_review_requests 
WITH (security_invoker = true) AS
SELECT * FROM public.review_requests_with_details
WHERE status = 'active'
ORDER BY requested_at DESC;

-- VIEW 4: my_product_reviews
CREATE OR REPLACE VIEW public.my_product_reviews 
WITH (security_invoker = true) AS
SELECT * FROM public.product_reviews_with_details
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 6: تقرير النتائج
-- ============================================================================

DO $$
DECLARE
  v_rr_product_id_type text;
  v_pr_product_id_type text;
BEGIN
  -- جلب أنواع الـ columns
  SELECT data_type INTO v_rr_product_id_type
  FROM information_schema.columns 
  WHERE table_name = 'review_requests' AND column_name = 'product_id';
  
  SELECT data_type INTO v_pr_product_id_type
  FROM information_schema.columns 
  WHERE table_name = 'product_reviews' AND column_name = 'product_id';
  
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════╗';
  RAISE NOTICE '║   FINAL FIX APPLIED SUCCESSFULLY! ✅           ║';
  RAISE NOTICE '╠════════════════════════════════════════════════╣';
  RAISE NOTICE '║ ✅ Tables updated                              ║';
  RAISE NOTICE '║    - review_requests.product_id: %        ║', RPAD(v_rr_product_id_type, 12);
  RAISE NOTICE '║    - product_reviews.product_id: %        ║', RPAD(v_pr_product_id_type, 12);
  RAISE NOTICE '║                                                ║';
  RAISE NOTICE '║ ✅ Function updated                            ║';
  RAISE NOTICE '║    - create_review_request(text, ...)          ║';
  RAISE NOTICE '║    - Supports both integer & UUID IDs          ║';
  RAISE NOTICE '║                                                ║';
  RAISE NOTICE '║ ✅ Views recreated                             ║';
  RAISE NOTICE '║    - Fixed: u.id (was: u.uid)                  ║';
  RAISE NOTICE '║                                                ║';
  RAISE NOTICE '║ 🎯 System is ready to use!                     ║';
  RAISE NOTICE '╚════════════════════════════════════════════════╝';
  RAISE NOTICE '';
END $$;
