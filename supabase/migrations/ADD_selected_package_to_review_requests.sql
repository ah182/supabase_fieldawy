-- ============================================================================
-- إضافة حقل selected_package إلى جدول review_requests وتحديث الدالة
-- ============================================================================

-- 1. إضافة العمود إلى جدول review_requests
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'review_requests' 
      AND column_name = 'selected_package'
  ) THEN
    ALTER TABLE public.review_requests 
    ADD COLUMN selected_package text;
    
    RAISE NOTICE '✅ تم إضافة عمود selected_package إلى جدول review_requests';
  ELSE
    RAISE NOTICE '⚠️ عمود selected_package موجود بالفعل في جدول review_requests';
  END IF;
END $$;

-- 2. تحديث دالة create_review_request لقبول selected_package
DROP FUNCTION IF EXISTS public.create_review_request(text, product_type_enum);

CREATE OR REPLACE FUNCTION public.create_review_request(
  p_product_id text,
  p_product_type product_type_enum DEFAULT 'product',
  p_selected_package text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_product_uuid uuid;
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
    selected_package,
    requested_by,
    requester_name,
    status
  ) VALUES (
    v_product_uuid,
    p_product_type,
    v_product_name,
    p_selected_package,
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
      'selected_package', rr.selected_package,
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

COMMENT ON FUNCTION public.create_review_request IS 'إنشاء طلب تقييم مع التحقق من جميع القيود ودعم selected_package';

-- 3. تحديث الـ view لاستخدام selected_package من الجدول بدلاً من الجداول الخارجية
DROP VIEW IF EXISTS public.review_requests_with_details CASCADE;

CREATE VIEW public.review_requests_with_details AS
SELECT 
  rr.id,
  rr.product_id,
  rr.product_type,
  rr.product_name,
  
  -- معلومات المنتج (صورة وباكدج)
  CASE 
    WHEN rr.product_type = 'product' THEN p.image_url
    WHEN rr.product_type = 'ocr_product' THEN op.image_url
    ELSE NULL
  END as product_image,
  
  -- استخدام selected_package المحفوظ في الجدول أولاً، ثم fallback للباكدج من جداول المنتجات
  COALESCE(
    rr.selected_package,
    CASE 
      WHEN rr.product_type = 'product' THEN COALESCE(p.selected_package, p.package)
      WHEN rr.product_type = 'ocr_product' THEN op.package
      ELSE NULL
    END
  ) as product_package,
  
  -- معلومات طالب التقييم
  rr.requested_by,
  rr.requester_name,
  u.photo_url as requester_photo,
  u.role as requester_role,
  
  -- حالة الطلب
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
  
  -- معلومات محسوبة
  (rr.comments_count >= 5) as is_comments_full,
  (rr.status = 'active' AND rr.comments_count < 5) as can_add_comment,
  EXTRACT(DAY FROM now() - rr.requested_at)::int as days_since_request
  
FROM public.review_requests rr
LEFT JOIN public.users u ON u.id = rr.requested_by
LEFT JOIN public.products p ON p.id::text = rr.product_id::text AND rr.product_type = 'product'
LEFT JOIN public.ocr_products op ON op.id::text = rr.product_id::text AND rr.product_type = 'ocr_product';

COMMENT ON VIEW public.review_requests_with_details IS 'عرض طلبات التقييم مع معلومات المنتج (صورة، باكدج محدد) ومعلومات طالب التقييم';

-- إعادة إنشاء الـ views المعتمدة
DROP VIEW IF EXISTS public.active_review_requests CASCADE;
CREATE VIEW public.active_review_requests AS
SELECT * 
FROM public.review_requests_with_details
WHERE status = 'active'
ORDER BY requested_at DESC;

DROP VIEW IF EXISTS public.my_review_requests CASCADE;
CREATE VIEW public.my_review_requests AS
SELECT * 
FROM public.review_requests_with_details
WHERE requested_by = auth.uid()
ORDER BY created_at DESC;

-- ============================================================================
-- نهاية
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ تم تحديث نظام التقييمات بنجاح!';
  RAISE NOTICE '📦 تمت إضافة: selected_package إلى review_requests';
  RAISE NOTICE '🔧 تم تحديث: create_review_request function';
  RAISE NOTICE '👁️ تم تحديث: review_requests_with_details view';
END $$;
