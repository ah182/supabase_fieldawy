-- ============================================================================
-- Business Logic Functions: Review System
-- Date: 2025-01-23
-- Description: الدوال الخاصة بمنطق العمل لنظام التقييمات
-- ============================================================================

-- ============================================================================
-- 1. FUNCTION: إنشاء طلب تقييم (مع التحققات)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_review_request(
  p_product_id text,  -- Changed from uuid to text
  p_product_type product_type_enum DEFAULT 'product'
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_product_uuid uuid;  -- For conversion
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
  
  -- Convert text to uuid
  BEGIN
    v_product_uuid := p_product_id::uuid;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'invalid_product_id',
        'message', 'معرف المنتج غير صالح'
      );
  END;
  
  -- 1. التحقق من وجود المنتج
  IF p_product_type = 'product' THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = v_product_uuid;
  ELSE
    SELECT product_name INTO v_product_name
    FROM public.ocr_products
    WHERE id = v_product_uuid;
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
  WHERE product_id = v_product_uuid
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
  
  -- 4. الحصول على اسم المستخدم
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
    v_product_uuid,
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

COMMENT ON FUNCTION public.create_review_request IS 'إنشاء طلب تقييم مع التحقق من جميع القيود (منتج واحد، حد أسبوعي)';

-- ============================================================================
-- 2. FUNCTION: إضافة تقييم/تعليق
-- ============================================================================

CREATE OR REPLACE FUNCTION public.add_product_review(
  p_request_id uuid,
  p_rating smallint,
  p_comment text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user_name text;
  v_product_id uuid;
  v_product_type product_type_enum;
  v_request_status review_request_status;
  v_current_comments_count int;
  v_existing_review uuid;
  v_new_review_id uuid;
  v_result jsonb;
BEGIN
  -- الحصول على user_id
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- التحقق من rating
  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_rating',
      'message', 'التقييم يجب أن يكون بين 1 و 5'
    );
  END IF;
  
  -- 1. التحقق من وجود الطلب
  SELECT 
    product_id, 
    product_type, 
    status, 
    comments_count
  INTO 
    v_product_id, 
    v_product_type, 
    v_request_status, 
    v_current_comments_count
  FROM public.review_requests
  WHERE id = p_request_id;
  
  IF v_product_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'request_not_found',
      'message', 'طلب التقييم غير موجود'
    );
  END IF;
  
  -- 2. التحقق من عدم وجود تقييم سابق من نفس المستخدم
  SELECT id INTO v_existing_review
  FROM public.product_reviews
  WHERE review_request_id = p_request_id
    AND user_id = v_user_id;
  
  IF v_existing_review IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_reviewed',
      'message', 'لقد قمت بتقييم هذا المنتج مسبقاً',
      'existing_review_id', v_existing_review
    );
  END IF;
  
  -- 3. التحقق من حد التعليقات (إذا كان يريد إضافة تعليق)
  IF p_comment IS NOT NULL AND length(trim(p_comment)) > 0 THEN
    IF v_current_comments_count >= 5 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'comment_limit_reached',
        'message', 'تم الوصول للحد الأقصى من التعليقات (5). يمكنك إضافة تقييم بالنجوم فقط'
      );
    END IF;
  END IF;
  
  -- 4. الحصول على اسم المستخدم
  SELECT COALESCE(display_name, email) INTO v_user_name
  FROM public.users
  WHERE id = v_user_id;
  
  -- 5. إضافة التقييم
  INSERT INTO public.product_reviews (
    review_request_id,
    product_id,
    product_type,
    user_id,
    user_name,
    rating,
    comment
  ) VALUES (
    p_request_id,
    v_product_id,
    v_product_type,
    v_user_id,
    v_user_name,
    p_rating,
    NULLIF(trim(p_comment), '')
  )
  RETURNING id INTO v_new_review_id;
  
  -- 6. تحديث الإحصائيات سيتم تلقائياً عبر الـ Trigger
  
  -- 7. إرجاع النتيجة
  SELECT jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'id', pr.id,
      'review_request_id', pr.review_request_id,
      'product_id', pr.product_id,
      'product_type', pr.product_type,
      'user_id', pr.user_id,
      'user_name', pr.user_name,
      'rating', pr.rating,
      'comment', pr.comment,
      'has_comment', pr.has_comment,
      'helpful_count', pr.helpful_count,
      'created_at', pr.created_at
    )
  ) INTO v_result
  FROM public.product_reviews pr
  WHERE pr.id = v_new_review_id;
  
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

COMMENT ON FUNCTION public.add_product_review IS 'إضافة تقييم مع التحقق من جميع القيود (تقييم واحد لكل مستخدم، حد التعليقات)';

-- ============================================================================
-- 3. FUNCTION: التصويت على فائدة التقييم
-- ============================================================================

CREATE OR REPLACE FUNCTION public.vote_review_helpful(
  p_review_id uuid,
  p_is_helpful boolean
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_existing_vote uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- التحقق من وجود التقييم
  IF NOT EXISTS (SELECT 1 FROM public.product_reviews WHERE id = p_review_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'review_not_found',
      'message', 'التقييم غير موجود'
    );
  END IF;
  
  -- التحقق من عدم التصويت على تقييمك الخاص
  IF EXISTS (SELECT 1 FROM public.product_reviews WHERE id = p_review_id AND user_id = v_user_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'cannot_vote_own_review',
      'message', 'لا يمكنك التصويت على تقييمك الخاص'
    );
  END IF;
  
  -- التحقق من وجود تصويت سابق
  SELECT id INTO v_existing_vote
  FROM public.review_helpful_votes
  WHERE review_id = p_review_id AND user_id = v_user_id;
  
  IF v_existing_vote IS NOT NULL THEN
    -- تحديث التصويت
    UPDATE public.review_helpful_votes
    SET is_helpful = p_is_helpful
    WHERE id = v_existing_vote;
    
    RETURN jsonb_build_object(
      'success', true,
      'message', 'تم تحديث تصويتك'
    );
  ELSE
    -- إضافة تصويت جديد
    INSERT INTO public.review_helpful_votes (review_id, user_id, is_helpful)
    VALUES (p_review_id, v_user_id, p_is_helpful);
    
    RETURN jsonb_build_object(
      'success', true,
      'message', 'تم تسجيل تصويتك'
    );
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

-- ============================================================================
-- 4. FUNCTION: حذف تقييم (بواسطة صاحبه فقط)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_my_review(p_review_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_review_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- التحقق من ملكية التقييم
  SELECT user_id INTO v_review_user_id
  FROM public.product_reviews
  WHERE id = p_review_id;
  
  IF v_review_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'review_not_found',
      'message', 'التقييم غير موجود'
    );
  END IF;
  
  IF v_review_user_id != v_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'not_owner',
      'message', 'لا يمكنك حذف تقييم شخص آخر'
    );
  END IF;
  
  -- حذف التقييم (سيتم تحديث الإحصائيات تلقائياً)
  DELETE FROM public.product_reviews WHERE id = p_review_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم حذف التقييم بنجاح'
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

-- ============================================================================
-- نهاية Business Logic Functions
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Business Logic Functions created successfully!';
  RAISE NOTICE '📦 Functions: create_review_request, add_product_review, vote_review_helpful, delete_my_review';
END $$;
