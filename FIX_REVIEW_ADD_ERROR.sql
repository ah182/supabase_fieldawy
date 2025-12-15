-- ============================================================================
-- FIX: RE-CREATE add_product_review FUNCTION
-- This script ensures the function exists and has the correct signature.
-- ============================================================================

-- Drop all variations to ensure clean slate
DROP FUNCTION IF EXISTS public.add_product_review(uuid, int, text);
DROP FUNCTION IF EXISTS public.add_product_review(uuid, smallint, text);
DROP FUNCTION IF EXISTS public.add_product_review(uuid, int);
DROP FUNCTION IF EXISTS public.add_product_review CASCADE;

-- Re-create the function
CREATE OR REPLACE FUNCTION public.add_product_review(
  p_request_id uuid,
  p_rating int,
  p_comment text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_product_id uuid;
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
  
  -- Check if review_requests table exists
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'review_requests') THEN
     RETURN jsonb_build_object(
      'success', false,
      'error', 'table_missing',
      'message', 'جدول طلبات التقييم غير موجود'
    );
  END IF;

  -- Get request details
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
  
  -- Prevent owner from reviewing their own request
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
  
  -- Validate rating
  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_rating',
      'message', 'التقييم يجب أن يكون بين 1 و 5'
    );
  END IF;
  
  -- Check for existing review
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
  
  -- Check comments limit
  IF p_comment IS NOT NULL AND trim(p_comment) != '' THEN
    IF v_comments_count >= 5 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'comments_limit_reached',
        'message', 'تم الوصول للحد الأقصى من التعليقات (5)'
      );
    END IF;
  END IF;
  
  -- Insert Review
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

COMMENT ON FUNCTION public.add_product_review IS 'إضافة تقييم (إصلاح)';
