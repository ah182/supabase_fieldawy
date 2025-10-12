-- ============================================================================
-- حل بسيط: عرض package العادي فقط بدون تعقيدات
-- ============================================================================

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
  
  CASE 
    WHEN rr.product_type = 'product' THEN p.package
    WHEN rr.product_type = 'ocr_product' THEN op.package
    ELSE NULL
  END as product_package,
  
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

COMMENT ON VIEW public.review_requests_with_details IS 'عرض طلبات التقييم مع معلومات المنتج (package عادي) والمستخدم';

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
  RAISE NOTICE '✅ تم تحديث الـ view بنجاح!';
  RAISE NOTICE '📦 يتم عرض package العادي الآن';
END $$;
