-- ============================================================================
-- FIX: إصلاح مشكلة has_comment في دالة add_product_review
-- المشكلة: محاولة إدخال قيمة في عمود محسوب تلقائياً
-- الحل: إزالة has_comment من INSERT statement
-- ============================================================================

DROP FUNCTION IF EXISTS public.add_product_review(uuid, smallint, text);

CREATE OR REPLACE FUNCTION public.add_product_review(
  p_request_id uuid,
  p_rating smallint,
  p_comment text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user_name text;
  v_product_id text;
  v_product_type product_type_enum;
  v_request_status review_request_status;
  v_current_comments_count int;
  v_existing_review uuid;
  v_new_review_id uuid;
  v_result jsonb;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
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
  
  -- 2. التحقق من أن الطلب نشط
  IF v_request_status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'request_closed',
      'message', 'طلب التقييم غير نشط'
    );
  END IF;
  
  -- 3. التحقق من عدم تجاوز حد التعليقات
  IF p_comment IS NOT NULL AND trim(p_comment) != '' THEN
    IF v_current_comments_count >= 5 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'comments_limit_exceeded',
        'message', 'تم الوصول للحد الأقصى من التعليقات (5)'
      );
    END IF;
  END IF;
  
  -- 4. التحقق من عدم وجود تقييم سابق من نفس المستخدم
  SELECT id INTO v_existing_review
  FROM public.product_reviews
  WHERE review_request_id = p_request_id
    AND user_id = v_user_id;
  
  IF v_existing_review IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_reviewed',
      'message', 'لقد قمت بالتقييم مسبقاً'
    );
  END IF;
  
  -- 5. الحصول على اسم المستخدم
  SELECT COALESCE(display_name, email) INTO v_user_name
  FROM public.users
  WHERE id = v_user_id;
  
  -- 6. إضافة التقييم
  -- ✅ تم إزالة has_comment من الأعمدة لأنه محسوب تلقائياً
  INSERT INTO public.product_reviews (
    review_request_id,
    product_id,
    product_type,
    user_id,
    user_name,
    rating,
    comment,
    is_verified_purchase
  ) VALUES (
    p_request_id,
    v_product_id,
    v_product_type,
    v_user_id,
    v_user_name,
    p_rating,
    NULLIF(trim(p_comment), ''),  -- استخدام NULLIF لتحويل النص الفارغ إلى NULL
    false
  )
  RETURNING id INTO v_new_review_id;
  
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
      'has_comment', pr.has_comment,  -- ✅ يمكن قراءته من الاستعلام
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

-- ============================================================================
-- التحقق من تعريف العمود has_comment
-- ============================================================================

DO $$
DECLARE
  v_is_generated boolean;
BEGIN
  SELECT 
    attgenerated != ''
  INTO v_is_generated
  FROM pg_attribute
  WHERE attrelid = 'public.product_reviews'::regclass
    AND attname = 'has_comment';
  
  IF v_is_generated THEN
    RAISE NOTICE '✅ العمود has_comment محسوب تلقائياً بشكل صحيح';
  ELSE
    RAISE WARNING '⚠️ العمود has_comment ليس محسوباً تلقائياً';
  END IF;
END $$;

-- ============================================================================
-- نهاية الإصلاح
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ تم إصلاح دالة add_product_review بنجاح!';
  RAISE NOTICE '   تم إزالة has_comment من INSERT statement';
  RAISE NOTICE '   العمود has_comment سيتم حسابه تلقائياً بناءً على وجود comment';
  RAISE NOTICE '';
  RAISE NOTICE '📝 ملاحظة: العمود has_comment معرف كالتالي:';
  RAISE NOTICE '   has_comment boolean GENERATED ALWAYS AS (comment IS NOT NULL AND length(comment) > 0) STORED';
END $$;
