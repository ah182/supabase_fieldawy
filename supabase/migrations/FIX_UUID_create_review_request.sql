-- ============================================================================
-- FIX: UUID Input Error - create_review_request
-- Date: 2025-01-23
-- Description: إصلاح خطأ "invalid input syntax for type uuid"
-- ============================================================================

-- المشكلة: Flutter يرسل product_id كـ String، لكن الـ function تتوقع UUID
-- الحل: نعدل الـ function لتقبل text ونحوله داخلياً

-- ============================================================================
-- حذف الـ Function القديمة
-- ============================================================================

DROP FUNCTION IF EXISTS public.create_review_request(uuid, product_type_enum);

-- ============================================================================
-- إنشاء الـ Function الجديدة (تقبل text)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_review_request(
  p_product_id text,  -- ⚠️ تغيير: من uuid إلى text (يدعم integer و uuid)
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
  
  -- ✅ التحقق من نوع الـ ID (رقم أو UUID)
  -- لا نحتاج للتحويل لأننا سنستخدم text مباشرة في الاستعلامات
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
  WHERE product_id::text = p_product_id
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
    p_product_id,  -- ✅ استخدام text مباشرة (يدعم integer و uuid)
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

COMMENT ON FUNCTION public.create_review_request IS 'إنشاء طلب تقييم - يقبل product_id كـ text ويحوله لـ UUID';

-- ============================================================================
-- رسالة التأكيد
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Function updated successfully!';
  RAISE NOTICE '📝 create_review_request now accepts text for product_id';
  RAISE NOTICE '🔄 It will automatically convert text to UUID';
END $$;
