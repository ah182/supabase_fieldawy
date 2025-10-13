-- ============================================================================
-- اختبار سريع: تحديث review يدوياً لـ 10 dislikes
-- ============================================================================

-- اختر review معين وحدث unhelpful_count لـ 10 يدوياً
DO $$
DECLARE
  v_test_review_id uuid;
  v_exists boolean;
BEGIN
  -- أخذ أول review
  SELECT id INTO v_test_review_id 
  FROM public.product_reviews 
  LIMIT 1;
  
  IF v_test_review_id IS NULL THEN
    RAISE NOTICE 'لا توجد تقييمات';
    RETURN;
  END IF;
  
  RAISE NOTICE '🧪 اختبار يدوي للحذف التلقائي';
  RAISE NOTICE '   Review ID: %', v_test_review_id;
  
  -- تحديث إلى 9 أولاً
  UPDATE public.product_reviews
  SET unhelpful_count = 9
  WHERE id = v_test_review_id;
  
  RAISE NOTICE '   ✓ تم التحديث إلى 9 - التعليق لازال موجود';
  
  -- الآن تحديث إلى 10 (هنا الـ trigger يشتغل)
  UPDATE public.product_reviews
  SET unhelpful_count = 10
  WHERE id = v_test_review_id;
  
  RAISE NOTICE '   ✓ تم التحديث إلى 10 - الـ trigger يشتغل الآن...';
  
  -- التحقق
  SELECT EXISTS(
    SELECT 1 FROM public.product_reviews WHERE id = v_test_review_id
  ) INTO v_exists;
  
  IF v_exists THEN
    RAISE NOTICE '   ❌ التعليق لازال موجود - الـ trigger مش شغال!';
  ELSE
    RAISE NOTICE '   ✅ التعليق تم حذفه - الـ trigger شغال تمام!';
  END IF;
END $$;
