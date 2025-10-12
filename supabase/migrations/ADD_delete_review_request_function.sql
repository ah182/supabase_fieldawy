-- ============================================================================
-- إضافة دالة حذف طلب التقييم (للمستخدم الذي أنشأه فقط)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_my_review_request(p_request_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_request_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'يجب تسجيل الدخول أولاً'
    );
  END IF;
  
  -- التحقق من ملكية طلب التقييم
  SELECT requested_by INTO v_request_user_id
  FROM public.review_requests
  WHERE id = p_request_id;
  
  IF v_request_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'request_not_found',
      'message', 'طلب التقييم غير موجود'
    );
  END IF;
  
  IF v_request_user_id != v_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'not_owner',
      'message', 'لا يمكنك حذف طلب تقييم شخص آخر'
    );
  END IF;
  
  -- حذف طلب التقييم (سيتم حذف جميع التقييمات المرتبطة تلقائياً بسبب ON DELETE CASCADE)
  DELETE FROM public.review_requests WHERE id = p_request_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم حذف طلب التقييم بنجاح'
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

COMMENT ON FUNCTION public.delete_my_review_request IS 'حذف طلب التقييم (فقط بواسطة المستخدم الذي أنشأه)';

-- ============================================================================
-- نهاية
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ تم إنشاء دالة delete_my_review_request بنجاح!';
  RAISE NOTICE '🗑️ يمكن للمستخدم حذف طلب التقييم الخاص به فقط';
  RAISE NOTICE '⚠️ تحذير: حذف الطلب سيحذف جميع التقييمات المرتبطة به';
END $$;
